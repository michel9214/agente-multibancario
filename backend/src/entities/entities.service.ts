import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateEntityDto } from './dto/create-entity.dto';
import { UpdateEntityDto } from './dto/update-entity.dto';

@Injectable()
export class EntitiesService {
  constructor(private prisma: PrismaService) {}

  async findAll(activeOnly = false) {
    return this.prisma.bankingEntity.findMany({
      where: activeOnly ? { isActive: true } : undefined,
      orderBy: { name: 'asc' },
    });
  }

  async findOne(id: string) {
    const entity = await this.prisma.bankingEntity.findUnique({ where: { id } });
    if (!entity) throw new NotFoundException('Entidad no encontrada');
    return entity;
  }

  async create(dto: CreateEntityDto) {
    const existing = await this.prisma.bankingEntity.findUnique({
      where: { name: dto.name },
    });
    if (existing) throw new ConflictException('Ya existe una entidad con ese nombre');

    return this.prisma.bankingEntity.create({ data: dto });
  }

  async update(id: string, dto: UpdateEntityDto) {
    await this.findOne(id);
    if (dto.name) {
      const existing = await this.prisma.bankingEntity.findFirst({
        where: { name: dto.name, id: { not: id } },
      });
      if (existing) throw new ConflictException('Ya existe una entidad con ese nombre');
    }
    return this.prisma.bankingEntity.update({ where: { id }, data: dto });
  }

  async remove(id: string) {
    await this.findOne(id);
    return this.prisma.bankingEntity.update({
      where: { id },
      data: { isActive: false },
    });
  }
}
