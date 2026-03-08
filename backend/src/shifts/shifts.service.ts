import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ReconciliationService } from '../reconciliation/reconciliation.service';
import { OpenShiftDto } from './dto/open-shift.dto';
import { CloseShiftDto, FinalCloseDto } from './dto/close-shift.dto';
import { BalanceType, ShiftStatus, Role } from '@prisma/client';

@Injectable()
export class ShiftsService {
  constructor(
    private prisma: PrismaService,
    private reconciliation: ReconciliationService,
  ) {}

  async openShift(operatorId: string, dto: OpenShiftDto) {
    // Check for existing open/preclosed shift
    const existingOpen = await this.prisma.shift.findFirst({
      where: { operatorId, status: { in: [ShiftStatus.OPEN, ShiftStatus.PRECLOSED] } },
    });
    if (existingOpen) {
      throw new BadRequestException('Ya tienes un turno abierto. Ciérralo primero.');
    }

    return this.prisma.$transaction(async (tx) => {
      const shift = await tx.shift.create({
        data: {
          operatorId,
          startingCash: dto.startingCash,
          sencillo: dto.sencillo ?? 0,
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

  /**
   * Pre-close: saves closing data but keeps shift editable
   */
  async preCloseShift(
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
      // Delete existing closing balances and commissions (in case of re-preclose)
      await tx.balanceEntry.deleteMany({
        where: { shiftId, type: BalanceType.CLOSING },
      });
      await tx.commissionEntry.deleteMany({
        where: { shiftId },
      });

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

      // Create commission entries
      if (dto.commissions && dto.commissions.length > 0) {
        const validCommissions = dto.commissions.filter((c) => c.amount > 0);
        if (validCommissions.length > 0) {
          await tx.commissionEntry.createMany({
            data: validCommissions.map((c) => ({
              shiftId,
              entityId: c.entityId || null,
              concept: c.concept || null,
              amount: c.amount,
            })),
          });
        }
      }

      // Calculate reconciliation (preview)
      const result = await this.reconciliation.calculate(shiftId, tx);

      // Update shift to PRECLOSED
      await tx.shift.update({
        where: { id: shiftId },
        data: {
          status: ShiftStatus.PRECLOSED,
          endingCash: dto.endingCash,
          totalOpeningBalance: result.totalOpeningBalance,
          totalClosingBalance: result.totalClosingBalance,
          totalMovements: result.totalMovements,
          totalCommissions: result.totalCommissions,
          discrepancy: result.discrepancy,
        },
      });

      return this.getShiftWithDetails(shiftId, tx);
    });
  }

  /**
   * Final close: from PRECLOSED to CLOSED, with optional discrepancy justification
   */
  async finalCloseShift(
    shiftId: string,
    userId: string,
    userRole: Role,
    dto: FinalCloseDto,
  ) {
    const shift = await this.prisma.shift.findUnique({
      where: { id: shiftId },
    });
    if (!shift) throw new NotFoundException('Turno no encontrado');
    if (shift.status !== ShiftStatus.PRECLOSED) {
      throw new BadRequestException('El turno debe estar en pre-cierre para cerrar definitivamente');
    }
    if (shift.operatorId !== userId && userRole !== Role.OWNER) {
      throw new ForbiddenException('No puedes cerrar el turno de otro operador');
    }

    return this.prisma.$transaction(async (tx) => {
      // Recalculate in case movements were modified during preclose
      const result = await this.reconciliation.calculate(shiftId, tx);

      await tx.shift.update({
        where: { id: shiftId },
        data: {
          status: ShiftStatus.CLOSED,
          closedAt: new Date(),
          totalOpeningBalance: result.totalOpeningBalance,
          totalClosingBalance: result.totalClosingBalance,
          totalMovements: result.totalMovements,
          totalCommissions: result.totalCommissions,
          discrepancy: result.discrepancy,
          discrepancyNote: dto.discrepancyNote || null,
          discrepancyPhotoUrl: dto.discrepancyPhotoUrl || null,
        },
      });

      return this.getShiftWithDetails(shiftId, tx);
    });
  }

  /**
   * Reopen from PRECLOSED back to OPEN (cancel preclose)
   */
  async reopenShift(
    shiftId: string,
    userId: string,
    userRole: Role,
  ) {
    const shift = await this.prisma.shift.findUnique({
      where: { id: shiftId },
    });
    if (!shift) throw new NotFoundException('Turno no encontrado');
    if (shift.status !== ShiftStatus.PRECLOSED) {
      throw new BadRequestException('Solo se puede reabrir un turno en pre-cierre');
    }
    if (shift.operatorId !== userId && userRole !== Role.OWNER) {
      throw new ForbiddenException('No puedes modificar el turno de otro operador');
    }

    await this.prisma.shift.update({
      where: { id: shiftId },
      data: { status: ShiftStatus.OPEN },
    });

    return this.getShiftWithDetails(shiftId);
  }

  /**
   * Annul close: revert CLOSED back to PRECLOSED (OWNER only)
   */
  async annulClose(shiftId: string, userRole: Role) {
    if (userRole !== Role.OWNER) {
      throw new ForbiddenException('Solo el administrador puede anular un cierre');
    }

    const shift = await this.prisma.shift.findUnique({
      where: { id: shiftId },
    });
    if (!shift) throw new NotFoundException('Turno no encontrado');
    if (shift.status !== ShiftStatus.CLOSED) {
      throw new BadRequestException('Solo se puede anular un turno cerrado');
    }

    // Check there's no other open/preclosed shift
    const existingActive = await this.prisma.shift.findFirst({
      where: {
        status: { in: [ShiftStatus.OPEN, ShiftStatus.PRECLOSED] },
      },
    });
    if (existingActive) {
      throw new BadRequestException(
        'No se puede anular: ya existe un turno activo o en pre-cierre',
      );
    }

    await this.prisma.shift.update({
      where: { id: shiftId },
      data: {
        status: ShiftStatus.PRECLOSED,
        closedAt: null,
        discrepancyNote: null,
        discrepancyPhotoUrl: null,
      },
    });

    return this.getShiftWithDetails(shiftId);
  }

  async getActiveShift(userId: string, userRole: Role) {
    // OWNER sees any open/preclosed shift, OPERATOR sees only their own
    const where = userRole === Role.OWNER
      ? { status: { in: [ShiftStatus.OPEN, ShiftStatus.PRECLOSED] } }
      : { operatorId: userId, status: { in: [ShiftStatus.OPEN, ShiftStatus.PRECLOSED] } };

    const shift = await this.prisma.shift.findFirst({
      where,
      orderBy: { startedAt: 'desc' },
      include: {
        balanceEntries: { include: { entity: true } },
        movements: { include: { reason: true }, orderBy: { createdAt: 'desc' } },
        commissionEntries: { include: { entity: true } },
        operator: { select: { id: true, fullName: true, email: true } },
      },
    });
    return shift;
  }

  /**
   * Update commissions on a PRECLOSED shift
   */
  async updateCommissions(
    shiftId: string,
    userId: string,
    userRole: Role,
    commissions: { entityId?: string; concept?: string; amount: number }[],
  ) {
    const shift = await this.prisma.shift.findUnique({
      where: { id: shiftId },
    });
    if (!shift) throw new NotFoundException('Turno no encontrado');
    if (shift.status !== ShiftStatus.PRECLOSED) {
      throw new BadRequestException('Solo se pueden editar comisiones en pre-cierre');
    }
    if (shift.operatorId !== userId && userRole !== Role.OWNER) {
      throw new ForbiddenException('No puedes modificar el turno de otro operador');
    }

    return this.prisma.$transaction(async (tx) => {
      await tx.commissionEntry.deleteMany({ where: { shiftId } });

      const validCommissions = commissions.filter((c) => c.amount > 0);
      if (validCommissions.length > 0) {
        await tx.commissionEntry.createMany({
          data: validCommissions.map((c) => ({
            shiftId,
            entityId: c.entityId || null,
            concept: c.concept || null,
            amount: c.amount,
          })),
        });
      }

      // Recalculate totalCommissions
      const totalCommissions = validCommissions.reduce(
        (sum, c) => sum + c.amount, 0,
      );
      await tx.shift.update({
        where: { id: shiftId },
        data: { totalCommissions },
      });

      return this.getShiftWithDetails(shiftId, tx);
    });
  }

  async getLastClosedShift() {
    const shift = await this.prisma.shift.findFirst({
      where: { status: ShiftStatus.CLOSED },
      orderBy: { closedAt: 'desc' },
      include: {
        balanceEntries: {
          where: { type: BalanceType.CLOSING },
          include: { entity: true },
          orderBy: { entity: { name: 'asc' } },
        },
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
          commissionEntries: true,
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
        movements: { include: { reason: true }, orderBy: { createdAt: 'asc' } },
        commissionEntries: { include: { entity: true } },
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
        movements: { include: { reason: true }, orderBy: { createdAt: 'asc' } },
        commissionEntries: { include: { entity: true } },
        operator: { select: { id: true, fullName: true, email: true } },
      },
    });
  }
}
