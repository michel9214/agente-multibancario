import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BalanceType, MovementDirection } from '@prisma/client';
import Decimal from 'decimal.js';

export interface ReconciliationResult {
  totalOpeningBalance: number;
  totalClosingBalance: number;
  totalMovements: number;
  totalCommissions: number;
  totalPendingDeliveries: number;
  startingCash: number;
  endingCash: number;
  discrepancy: number;
  status: 'BALANCED' | 'SURPLUS' | 'DEFICIT';
  discrepancyNote: string | null;
  discrepancyPhotoUrl: string | null;
  details: {
    openingBalances: { entityName: string; amount: number }[];
    closingBalances: { entityName: string; amount: number }[];
    movements: { type: string; direction: string; amount: number; description: string | null }[];
    commissions: { name: string; amount: number }[];
    pendingDeliveries: { entityName: string; amount: number; description: string | null }[];
  };
}

@Injectable()
export class ReconciliationService {
  constructor(private prisma: PrismaService) {}

  async calculate(shiftId: string, tx?: any): Promise<ReconciliationResult> {
    const db = tx || this.prisma;

    const shift = await db.shift.findUnique({ where: { id: shiftId } });
    if (!shift) throw new NotFoundException('Turno no encontrado');

    const balanceEntries = await db.balanceEntry.findMany({
      where: { shiftId },
      include: { entity: true },
    });

    const movements = await db.movement.findMany({
      where: { shiftId },
    });

    const commissionEntries = await db.commissionEntry.findMany({
      where: { shiftId },
      include: { entity: true },
    });

    const pendingDeliveries = await db.pendingDelivery.findMany({
      where: { shiftId },
      include: { entity: true },
    });

    // Calculate totals using Decimal for precision
    const openingBalances = balanceEntries.filter(
      (b: any) => b.type === BalanceType.OPENING,
    );
    const closingBalances = balanceEntries.filter(
      (b: any) => b.type === BalanceType.CLOSING,
    );

    const totalOpeningBalance = openingBalances.reduce(
      (sum: Decimal, b: any) => sum.plus(new Decimal(b.amount.toString())),
      new Decimal(0),
    );

    const totalClosingBalance = closingBalances.reduce(
      (sum: Decimal, b: any) => sum.plus(new Decimal(b.amount.toString())),
      new Decimal(0),
    );

    const totalIn = movements
      .filter((m: any) => m.direction === MovementDirection.IN)
      .reduce(
        (sum: Decimal, m: any) => sum.plus(new Decimal(m.amount.toString())),
        new Decimal(0),
      );

    const totalOut = movements
      .filter((m: any) => m.direction === MovementDirection.OUT)
      .reduce(
        (sum: Decimal, m: any) => sum.plus(new Decimal(m.amount.toString())),
        new Decimal(0),
      );

    const netMovements = totalIn.minus(totalOut);

    const totalCommissions = commissionEntries.reduce(
      (sum: Decimal, c: any) => sum.plus(new Decimal(c.amount.toString())),
      new Decimal(0),
    );

    const totalPendingDeliveries = pendingDeliveries.reduce(
      (sum: Decimal, pd: any) => sum.plus(new Decimal(pd.amount.toString())),
      new Decimal(0),
    );

    const startingCash = new Decimal(shift.startingCash.toString());
    const endingCash = shift.endingCash
      ? new Decimal(shift.endingCash.toString())
      : new Decimal(0);

    // Formula:
    // discrepancy = cierre - (apertura + movimientos) - entregas_pendientes
    // Pending deliveries reduce the discrepancy (explain surpluses)
    const totalClosing = totalClosingBalance.plus(endingCash);
    const totalExpected = totalOpeningBalance.plus(startingCash).plus(netMovements);
    const discrepancy = totalClosing.minus(totalExpected).minus(totalPendingDeliveries);

    let status: 'BALANCED' | 'SURPLUS' | 'DEFICIT';
    if (discrepancy.equals(0)) {
      status = 'BALANCED';
    } else if (discrepancy.greaterThan(0)) {
      status = 'SURPLUS';
    } else {
      status = 'DEFICIT';
    }

    return {
      totalOpeningBalance: totalOpeningBalance.toNumber(),
      totalClosingBalance: totalClosingBalance.toNumber(),
      totalMovements: netMovements.toNumber(),
      totalCommissions: totalCommissions.toNumber(),
      totalPendingDeliveries: totalPendingDeliveries.toNumber(),
      startingCash: startingCash.toNumber(),
      endingCash: endingCash.toNumber(),
      discrepancy: discrepancy.toNumber(),
      status,
      discrepancyNote: shift.discrepancyNote,
      discrepancyPhotoUrl: shift.discrepancyPhotoUrl,
      details: {
        openingBalances: openingBalances.map((b: any) => ({
          entityName: b.entity.name,
          amount: Number(b.amount),
        })),
        closingBalances: closingBalances.map((b: any) => ({
          entityName: b.entity.name,
          amount: Number(b.amount),
        })),
        movements: movements.map((m: any) => ({
          type: m.type,
          direction: m.direction,
          amount: Number(m.amount),
          description: m.description,
        })),
        commissions: commissionEntries.map((c: any) => ({
          name: c.entity ? c.entity.name : c.concept,
          amount: Number(c.amount),
        })),
        pendingDeliveries: pendingDeliveries.map((pd: any) => ({
          entityName: pd.entity.name,
          amount: Number(pd.amount),
          description: pd.description,
        })),
      },
    };
  }

  async getReconciliation(shiftId: string) {
    return this.calculate(shiftId);
  }
}
