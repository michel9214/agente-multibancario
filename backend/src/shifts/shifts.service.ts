import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ReconciliationService } from '../reconciliation/reconciliation.service';
import { CloudinaryService } from '../uploads/cloudinary.service';
import { OpenShiftDto } from './dto/open-shift.dto';
import { CloseShiftDto, FinalCloseDto } from './dto/close-shift.dto';
import { BalanceType, ShiftStatus, Role } from '@prisma/client';

@Injectable()
export class ShiftsService {
  constructor(
    private prisma: PrismaService,
    private reconciliation: ReconciliationService,
    private cloudinary: CloudinaryService,
  ) {}

  /**
   * Collect all photo URLs from a shift and its related records
   */
  private async collectShiftPhotoUrls(shiftId: string): Promise<string[]> {
    const urls: string[] = [];

    const shift = await this.prisma.shift.findUnique({ where: { id: shiftId } });
    if (shift?.discrepancyPhotoUrl) urls.push(shift.discrepancyPhotoUrl);

    const balances = await this.prisma.balanceEntry.findMany({
      where: { shiftId },
      select: { receiptPhotoUrl: true },
    });
    balances.forEach((b) => { if (b.receiptPhotoUrl) urls.push(b.receiptPhotoUrl); });

    const movements = await this.prisma.movement.findMany({
      where: { shiftId },
      select: { receiptPhotoUrl: true },
    });
    movements.forEach((m) => { if (m.receiptPhotoUrl) urls.push(m.receiptPhotoUrl); });

    const pendingDeliveries = await this.prisma.pendingDelivery.findMany({
      where: { shiftId },
      select: { receiptPhotoUrl: true },
    });
    pendingDeliveries.forEach((pd) => { if (pd.receiptPhotoUrl) urls.push(pd.receiptPhotoUrl); });

    return urls;
  }

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

    // Collect discrepancy photo URL before clearing
    const photoUrls: string[] = [];
    if (shift.discrepancyPhotoUrl) photoUrls.push(shift.discrepancyPhotoUrl);

    await this.prisma.shift.update({
      where: { id: shiftId },
      data: {
        status: ShiftStatus.PRECLOSED,
        closedAt: null,
        discrepancyNote: null,
        discrepancyPhotoUrl: null,
      },
    });

    // Clean up Cloudinary images in background
    if (photoUrls.length > 0) {
      this.cloudinary.deleteMultipleByUrls(photoUrls).catch(() => {});
    }

    return this.getShiftWithDetails(shiftId);
  }

  async getActiveShift() {
    const shift = await this.prisma.shift.findFirst({
      where: { status: { in: [ShiftStatus.OPEN, ShiftStatus.PRECLOSED] } },
      orderBy: { startedAt: 'desc' },
      include: {
        balanceEntries: { include: { entity: true }, orderBy: { entity: { name: 'asc' } } },
        movements: { include: { reason: true }, orderBy: { createdAt: 'desc' } },
        commissionEntries: { include: { entity: true } },
        pendingDeliveries: { include: { entity: true }, orderBy: { createdAt: 'asc' } },
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

  /**
   * Annul an OPEN shift: delete it and all related data (OWNER only)
   */
  async annulShift(shiftId: string, userRole: Role) {
    if (userRole !== Role.OWNER) {
      throw new ForbiddenException('Solo el administrador puede anular un turno');
    }

    const shift = await this.prisma.shift.findUnique({
      where: { id: shiftId },
    });
    if (!shift) throw new NotFoundException('Turno no encontrado');
    if (shift.status !== ShiftStatus.OPEN) {
      throw new BadRequestException('Solo se puede anular un turno abierto');
    }

    // Collect all photo URLs before deleting
    const photoUrls = await this.collectShiftPhotoUrls(shiftId);

    // Cascade delete handles balance_entries, movements, commission_entries, pending_deliveries
    await this.prisma.shift.delete({ where: { id: shiftId } });

    // Clean up Cloudinary images in background
    if (photoUrls.length > 0) {
      this.cloudinary.deleteMultipleByUrls(photoUrls).catch(() => {});
    }

    return { message: 'Turno anulado correctamente' };
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

  async findAll(page = 1, limit = 20) {
    const where = {};
    const skip = (page - 1) * limit;

    const [shifts, total] = await Promise.all([
      this.prisma.shift.findMany({
        where,
        include: {
          operator: { select: { id: true, fullName: true, email: true } },
          commissionEntries: true,
          pendingDeliveries: true,
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
        pendingDeliveries: { include: { entity: true }, orderBy: { createdAt: 'asc' } },
        operator: { select: { id: true, fullName: true, email: true } },
      },
    });
    if (!shift) throw new NotFoundException('Turno no encontrado');
    return shift;
  }

  async getShiftComparisons(page?: number, limit?: number) {
    const p = Number(page) || 1;
    const l = Number(limit) || 20;
    // Fetch all shifts with balance entries, ordered by startedAt ASC
    // Include OPEN/PRECLOSED so we can compare last closed → current open
    const allShifts = await this.prisma.shift.findMany({
      orderBy: { startedAt: 'asc' },
      include: {
        balanceEntries: { include: { entity: true } },
        operator: { select: { id: true, fullName: true } },
      },
    });

    if (allShifts.length < 2) {
      return { data: [], total: 0, page: p, limit: l };
    }

    // Build comparisons for each consecutive pair
    // Only compare when prev shift is CLOSED (has closing balances)
    const comparisons = [];
    for (let i = 0; i < allShifts.length - 1; i++) {
      const prev = allShifts[i];
      const next = allShifts[i + 1];

      // Skip if prev shift has no closing data
      if (prev.status !== ShiftStatus.CLOSED) continue;

      const prevClosing = prev.balanceEntries.filter(
        (b) => b.type === BalanceType.CLOSING,
      );
      const nextOpening = next.balanceEntries.filter(
        (b) => b.type === BalanceType.OPENING,
      );

      // Build union of all entity IDs
      const entityIds = new Set<string>();
      prevClosing.forEach((b) => entityIds.add(b.entityId));
      nextOpening.forEach((b) => entityIds.add(b.entityId));

      const entityComparisons = [];
      let totalEntityDiff = 0;

      for (const entityId of entityIds) {
        const closingEntry = prevClosing.find((b) => b.entityId === entityId);
        const openingEntry = nextOpening.find((b) => b.entityId === entityId);
        const closingAmount = closingEntry
          ? Number(closingEntry.amount)
          : 0;
        const openingAmount = openingEntry
          ? Number(openingEntry.amount)
          : 0;
        const diff = openingAmount - closingAmount;
        totalEntityDiff += diff;

        const entityName =
          closingEntry?.entity?.name ||
          openingEntry?.entity?.name ||
          'Entidad';

        entityComparisons.push({
          entityId,
          entityName,
          closingAmount,
          openingAmount,
          diff,
        });
      }

      // Sort entity comparisons by name
      entityComparisons.sort((a, b) =>
        a.entityName.localeCompare(b.entityName),
      );

      const cashDiff =
        Number(next.startingCash) - Number(prev.endingCash || 0);
      const totalDiff = totalEntityDiff;

      comparisons.push({
        closingShift: {
          id: prev.id,
          startedAt: prev.startedAt,
          closedAt: prev.closedAt,
          operatorName: prev.operator?.fullName || '-',
          endingCash: Number(prev.endingCash || 0),
        },
        openingShift: {
          id: next.id,
          startedAt: next.startedAt,
          operatorName: next.operator?.fullName || '-',
          startingCash: Number(next.startingCash),
        },
        cashDiff,
        totalDiff,
        entityComparisons,
      });
    }

    // Reverse to show most recent first, then paginate
    comparisons.reverse();
    const total = comparisons.length;
    const skip = (p - 1) * l;
    const data = comparisons.slice(skip, skip + l);

    return { data, total, page: p, limit: l };
  }

  /**
   * Update pending deliveries on a PRECLOSED shift
   */
  async updatePendingDeliveries(
    shiftId: string,
    pendingDeliveries: { entityId: string; amount: number; description?: string; receiptPhotoUrl?: string }[],
  ) {
    const shift = await this.prisma.shift.findUnique({
      where: { id: shiftId },
    });
    if (!shift) throw new NotFoundException('Turno no encontrado');
    if (shift.status !== ShiftStatus.PRECLOSED) {
      throw new BadRequestException('Solo se pueden editar entregas pendientes en pre-cierre');
    }

    return this.prisma.$transaction(async (tx) => {
      await tx.pendingDelivery.deleteMany({ where: { shiftId } });

      const valid = pendingDeliveries.filter((pd) => pd.amount > 0);
      if (valid.length > 0) {
        await tx.pendingDelivery.createMany({
          data: valid.map((pd) => ({
            shiftId,
            entityId: pd.entityId,
            amount: pd.amount,
            description: pd.description || null,
            receiptPhotoUrl: pd.receiptPhotoUrl || null,
          })),
        });
      }

      // Recalculate reconciliation
      const recon = await this.reconciliation.calculate(shiftId, tx);
      await tx.shift.update({
        where: { id: shiftId },
        data: { discrepancy: recon.discrepancy },
      });

      return this.getShiftWithDetails(shiftId, tx);
    });
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
        pendingDeliveries: { include: { entity: true }, orderBy: { createdAt: 'asc' } },
        operator: { select: { id: true, fullName: true, email: true } },
      },
    });
  }
}
