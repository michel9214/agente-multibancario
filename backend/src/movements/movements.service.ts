import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateMovementDto } from './dto/create-movement.dto';
import { ShiftStatus } from '@prisma/client';

@Injectable()
export class MovementsService {
  constructor(private prisma: PrismaService) {}

  async create(shiftId: string, dto: CreateMovementDto) {
    const shift = await this.prisma.shift.findUnique({ where: { id: shiftId } });
    if (!shift) throw new NotFoundException('Turno no encontrado');
    if (shift.status === ShiftStatus.CLOSED) {
      throw new BadRequestException('No puedes agregar movimientos a un turno cerrado');
    }

    return this.prisma.movement.create({
      data: {
        shiftId,
        type: dto.type,
        reasonId: dto.reasonId,
        direction: dto.direction,
        amount: dto.amount,
        description: dto.description,
        receiptPhotoUrl: dto.receiptPhotoUrl,
      },
      include: { reason: true },
    });
  }

  async findByShift(shiftId: string) {
    return this.prisma.movement.findMany({
      where: { shiftId },
      include: { reason: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async remove(id: string) {
    const movement = await this.prisma.movement.findUnique({
      where: { id },
      include: { shift: true },
    });
    if (!movement) throw new NotFoundException('Movimiento no encontrado');
    if (movement.shift.status === ShiftStatus.CLOSED) {
      throw new BadRequestException('No puedes eliminar movimientos de un turno cerrado');
    }
    return this.prisma.movement.delete({ where: { id } });
  }
}
