import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateMovementDto } from './dto/create-movement.dto';
import { ShiftStatus, Role } from '@prisma/client';

@Injectable()
export class MovementsService {
  constructor(private prisma: PrismaService) {}

  async create(shiftId: string, userId: string, dto: CreateMovementDto) {
    const shift = await this.prisma.shift.findUnique({ where: { id: shiftId } });
    if (!shift) throw new NotFoundException('Turno no encontrado');
    if (shift.status === ShiftStatus.CLOSED) {
      throw new BadRequestException('No puedes agregar movimientos a un turno cerrado');
    }

    return this.prisma.movement.create({
      data: {
        shiftId,
        createdById: userId,
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

  async update(id: string, userId: string, userRole: Role, dto: Partial<CreateMovementDto>) {
    const movement = await this.prisma.movement.findUnique({
      where: { id },
      include: { shift: true },
    });
    if (!movement) throw new NotFoundException('Movimiento no encontrado');
    if (movement.shift.status === ShiftStatus.CLOSED) {
      throw new BadRequestException('No puedes modificar movimientos de un turno cerrado');
    }
    if (userRole !== Role.OWNER && movement.createdById !== userId) {
      throw new ForbiddenException('Solo puedes editar tus propios movimientos');
    }

    return this.prisma.movement.update({
      where: { id },
      data: {
        ...(dto.type !== undefined && { type: dto.type }),
        ...(dto.reasonId !== undefined && { reasonId: dto.reasonId }),
        ...(dto.direction !== undefined && { direction: dto.direction }),
        ...(dto.amount !== undefined && { amount: dto.amount }),
        ...(dto.description !== undefined && { description: dto.description }),
        ...(dto.receiptPhotoUrl !== undefined && { receiptPhotoUrl: dto.receiptPhotoUrl }),
      },
      include: { reason: true },
    });
  }

  async remove(id: string, userId: string, userRole: Role) {
    const movement = await this.prisma.movement.findUnique({
      where: { id },
      include: { shift: true },
    });
    if (!movement) throw new NotFoundException('Movimiento no encontrado');
    if (movement.shift.status === ShiftStatus.CLOSED) {
      throw new BadRequestException('No puedes eliminar movimientos de un turno cerrado');
    }
    if (userRole !== Role.OWNER && movement.createdById !== userId) {
      throw new ForbiddenException('Solo puedes eliminar tus propios movimientos');
    }
    return this.prisma.movement.delete({ where: { id } });
  }
}
