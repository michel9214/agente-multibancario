import { Controller, Post } from '@nestjs/common';
import { PrismaService } from './prisma/prisma.service';
import { Role, EntityType, MovementDirection } from '@prisma/client';
import * as bcrypt from 'bcrypt';

@Controller('seed')
export class SeedController {
  constructor(private prisma: PrismaService) {}

  @Post('reset')
  async reset() {
    // Clean all data
    await this.prisma.movement.deleteMany();
    await this.prisma.balanceEntry.deleteMany();
    await this.prisma.shift.deleteMany();
    await this.prisma.movementReason.deleteMany();
    await this.prisma.bankingEntity.deleteMany();
    await this.prisma.user.deleteMany();

    // Create admin user
    const passwordHash = await bcrypt.hash('angie123', 10);
    await this.prisma.user.create({
      data: {
        email: 'luzangiemon@gmail.com',
        passwordHash,
        fullName: 'Angie',
        role: Role.OWNER,
      },
    });

    // Create banking entities
    const entities = [
      { name: 'BCP POS', type: EntityType.BANK, color: '#003882' },
      { name: 'BBVA POS', type: EntityType.BANK, color: '#004B87' },
      { name: 'BANCO DE LA NACION POS', type: EntityType.BANK, color: '#B71C1C' },
      { name: 'KASNET', type: EntityType.INTERMEDIARY, color: '#FF6B00' },
      { name: 'IZIPAY', type: EntityType.INTERMEDIARY, color: '#00BFA5' },
      { name: 'CASH APP', type: EntityType.FINTECH, color: '#00C853' },
      { name: 'PAGA YA', type: EntityType.INTERMEDIARY, color: '#FF6D00' },
      { name: 'BCP JOEL', type: EntityType.BANK, color: '#1565C0' },
      { name: 'INTERBANK JOEL', type: EntityType.BANK, color: '#00A94F' },
      { name: 'BBVA JOEL', type: EntityType.BANK, color: '#1A237E' },
      { name: 'BIM JOEL', type: EntityType.FINTECH, color: '#6A1B9A' },
      { name: 'COMPARTAMOS JOEL', type: EntityType.BANK, color: '#2E7D32' },
    ];

    for (const entity of entities) {
      await this.prisma.bankingEntity.create({ data: entity });
    }

    // Create movement reasons
    const reasons = [
      { name: 'INYECCION DE EFECTIVO', defaultDirection: MovementDirection.IN },
      { name: 'INYECCION DE SALDO', defaultDirection: MovementDirection.IN },
      { name: 'OTRO', defaultDirection: MovementDirection.IN },
      { name: 'PAGO SERVICIO DUEÑO', defaultDirection: MovementDirection.OUT },
      { name: 'ENTREGA EN EFECTIVO', defaultDirection: MovementDirection.OUT },
      { name: 'PAGO DIA ANTERIOR', defaultDirection: MovementDirection.OUT },
      { name: 'RETIRO CAJERO', defaultDirection: MovementDirection.OUT },
    ];

    for (const reason of reasons) {
      await this.prisma.movementReason.create({ data: reason });
    }

    return { message: 'Database reset complete', admin: 'luzangiemon@gmail.com' };
  }
}
