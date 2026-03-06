import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ReconciliationService } from '../reconciliation/reconciliation.service';
import { OpenShiftDto } from './dto/open-shift.dto';
import { CloseShiftDto } from './dto/close-shift.dto';
import { BalanceType, ShiftStatus, Role } from '@prisma/client';

@Injectable()
export class ShiftsService {
  constructor(
    private prisma: PrismaService,
    private reconciliation: ReconciliationService,
  ) {}

  async openShift(operatorId: string, dto: OpenShiftDto) {
    // Check for existing open shift
    const existingOpen = await this.prisma.shift.findFirst({
      where: { operatorId, status: ShiftStatus.OPEN },
    });
    if (existingOpen) {
      throw new BadRequestException('Ya tienes un turno abierto. Ciérralo primero.');
    }

    return this.prisma.$transaction(async (tx) => {
      const shift = await tx.shift.create({
        data: {
          operatorId,
          startingCash: dto.startingCash,
          status: ShiftStatus.OPEN,
        },
      });

      if (dto.openingBalances.length > 0) {
        await tx.balanceEntry.createMany({
          data: dto.openingBalances.map((b) => ({
            shiftId: shift.id,
            entityId: b.entityId,
            type: BalanceType.OPENING,
            amount: b.amount,
            receiptPhotoUrl: b.receiptPhotoUrl,
          })),
        });
      }

      return this.getShiftWithDetails(shift.id, tx);
    });
  }

  async closeShift(
    shiftId: string,
    userId: string,
    userRole: Role,
    dto: CloseShiftDto,
  ) {
    const shift = await this.prisma.shift.findUnique({
      where: { id: shiftId },
    });
    if (!shift) throw new NotFoundException('Turno no encontrado');
    if (shift.status === ShiftStatus.CLOSED) {
      throw new BadRequestException('Este turno ya está cerrado');
    }
    if (shift.operatorId !== userId && userRole !== Role.OWNER) {
      throw new ForbiddenException('No puedes cerrar el turno de otro operador');
    }

    return this.prisma.$transaction(async (tx) => {
      // Create closing balances
      if (dto.closingBalances.length > 0) {
        await tx.balanceEntry.createMany({
          data: dto.closingBalances.map((b) => ({
            shiftId,
            entityId: b.entityId,
            type: BalanceType.CLOSING,
            amount: b.amount,
            receiptPhotoUrl: b.receiptPhotoUrl,
          })),
        });
      }

      // Calculate reconciliation
      const result = await this.reconciliation.calculate(shiftId, tx);

      // Update shift
      await tx.shift.update({
        where: { id: shiftId },
        data: {
          status: ShiftStatus.CLOSED,
          closedAt: new Date(),
          endingCash: dto.endingCash,
          totalOpeningBalance: result.totalOpeningBalance,
          totalClosingBalance: result.totalClosingBalance,
          totalMovements: result.totalMovements,
          discrepancy: result.discrepancy,
        },
      });

      return this.getShiftWithDetails(shiftId, tx);
    });
  }

  async getActiveShift(operatorId: string) {
    const shift = await this.prisma.shift.findFirst({
      where: { operatorId, status: ShiftStatus.OPEN },
      include: {
        balanceEntries: { include: { entity: true } },
        movements: { orderBy: { createdAt: 'desc' } },
        operator: { select: { id: true, fullName: true, email: true } },
      },
    });
    return shift;
  }

  async findAll(userId: string, userRole: Role, page = 1, limit = 20) {
    const where = userRole === Role.OWNER ? {} : { operatorId: userId };
    const skip = (page - 1) * limit;

    const [shifts, total] = await Promise.all([
      this.prisma.shift.findMany({
        where,
        include: {
          operator: { select: { id: true, fullName: true, email: true } },
        },
        orderBy: { startedAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.shift.count({ where }),
    ]);

    return { data: shifts, total, page, limit };
  }

  async findOne(id: string) {
    const shift = await this.prisma.shift.findUnique({
      where: { id },
      include: {
        balanceEntries: {
          include: { entity: true },
          orderBy: { entity: { name: 'asc' } },
        },
        movements: { orderBy: { createdAt: 'asc' } },
        operator: { select: { id: true, fullName: true, email: true } },
      },
    });
    if (!shift) throw new NotFoundException('Turno no encontrado');
    return shift;
  }

  private async getShiftWithDetails(shiftId: string, tx?: any) {
    const db = tx || this.prisma;
    return db.shift.findUnique({
      where: { id: shiftId },
      include: {
        balanceEntries: {
          include: { entity: true },
          orderBy: { entity: { name: 'asc' } },
        },
        movements: { orderBy: { createdAt: 'asc' } },
        operator: { select: { id: true, fullName: true, email: true } },
      },
    });
  }
}
