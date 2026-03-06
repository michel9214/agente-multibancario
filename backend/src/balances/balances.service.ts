import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BalanceType } from '@prisma/client';

@Injectable()
export class BalancesService {
  constructor(private prisma: PrismaService) {}

  async findByShift(shiftId: string, type?: BalanceType) {
    return this.prisma.balanceEntry.findMany({
      where: { shiftId, ...(type ? { type } : {}) },
      include: { entity: true },
      orderBy: { entity: { name: 'asc' } },
    });
  }

  async upsert(
    shiftId: string,
    entityId: string,
    type: BalanceType,
    amount: number,
    receiptPhotoUrl?: string,
  ) {
    return this.prisma.balanceEntry.upsert({
      where: {
        shiftId_entityId_type: { shiftId, entityId, type },
      },
      update: { amount, receiptPhotoUrl },
      create: { shiftId, entityId, type, amount, receiptPhotoUrl },
      include: { entity: true },
    });
  }

  async remove(id: string) {
    const entry = await this.prisma.balanceEntry.findUnique({ where: { id } });
    if (!entry) throw new NotFoundException('Entrada de saldo no encontrada');
    return this.prisma.balanceEntry.delete({ where: { id } });
  }
}
