import { PrismaClient, Role, EntityType, MovementDirection } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  // ===== CLEAN ALL DATA =====
  console.log('Limpiando base de datos...');
  await prisma.movement.deleteMany();
  await prisma.balanceEntry.deleteMany();
  await prisma.shift.deleteMany();
  await prisma.movementReason.deleteMany();
  await prisma.bankingEntity.deleteMany();
  await prisma.user.deleteMany();
  console.log('Base de datos limpia');

  // ===== CREATE ADMIN USER =====
  const passwordHash = await bcrypt.hash('angie123', 10);
  await prisma.user.create({
    data: {
      email: 'luzangiemon@gmail.com',
      passwordHash,
      fullName: 'Angie',
      role: Role.OWNER,
    },
  });
  console.log('Usuario admin creado (luzangiemon@gmail.com / angie123)');

  // ===== CREATE BANKING ENTITIES =====
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
    await prisma.bankingEntity.create({ data: entity });
    console.log(`Entidad creada: ${entity.name}`);
  }

  // ===== CREATE MOVEMENT REASONS =====
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
    await prisma.movementReason.create({ data: reason });
    console.log(`Razón creada: ${reason.name}`);
  }

  console.log('\nSeed completado exitosamente');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
