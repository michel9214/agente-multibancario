import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateMovementReasonDto } from './dto/create-movement-reason.dto';
import { UpdateMovementReasonDto } from './dto/update-movement-reason.dto';

@Injectable()
export class MovementReasonsService {
  constructor(private prisma: PrismaService) {}

  async findAll(activeOnly = false) {
    return this.prisma.movementReason.findMany({
      where: activeOnly ? { isActive: true } : undefined,
      orderBy: { name: 'asc' },
    });
  }

  async findOne(id: string) {
    const reason = await this.prisma.movementReason.findUnique({ where: { id } });
    if (!reason) throw new NotFoundException('Razón de movimiento no encontrada');
    return reason;
  }

  async create(dto: CreateMovementReasonDto) {
    const existing = await this.prisma.movementReason.findUnique({
      where: { name: dto.name },
    });
    if (existing) throw new ConflictException('Ya existe una razón con ese nombre');

    return this.prisma.movementReason.create({ data: dto });
  }

  async update(id: string, dto: UpdateMovementReasonDto) {
    await this.findOne(id);
    if (dto.name) {
      const existing = await this.prisma.movementReason.findFirst({
        where: { name: dto.name, id: { not: id } },
      });
      if (existing) throw new ConflictException('Ya existe una razón con ese nombre');
    }
    return this.prisma.movementReason.update({ where: { id }, data: dto });
  }
}
