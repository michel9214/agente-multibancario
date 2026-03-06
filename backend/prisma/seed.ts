import { PrismaClient, Role, EntityType, MovementDirection } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const existingOwner = await prisma.user.findUnique({
    where: { email: 'admin@agente.com' },
  });

  if (!existingOwner) {
    const passwordHash = await bcrypt.hash('admin123', 10);
    await prisma.user.create({
      data: {
        email: 'admin@agente.com',
        passwordHash,
        fullName: 'Administrador',
        role: Role.OWNER,
      },
    });
    console.log('Usuario admin creado (admin@agente.com / admin123)');
  } else {
    console.log('Usuario admin ya existe');
  }

  const entities = [
    { name: 'BCP', type: EntityType.BANK, color: '#003882' },
    { name: 'Interbank', type: EntityType.BANK, color: '#00A94F' },
    { name: 'BBVA', type: EntityType.BANK, color: '#004B87' },
    { name: 'Scotiabank', type: EntityType.BANK, color: '#EC111A' },
    { name: 'BanBif', type: EntityType.BANK, color: '#00529B' },
    { name: 'Kasnet', type: EntityType.INTERMEDIARY, color: '#FF6B00' },
    { name: 'Western Union', type: EntityType.INTERMEDIARY, color: '#FFDD00' },
    { name: 'Yape', type: EntityType.FINTECH, color: '#6B21A8' },
    { name: 'Plin', type: EntityType.FINTECH, color: '#00C4B4' },
    { name: 'Niubiz', type: EntityType.INTERMEDIARY, color: '#E31837' },
  ];

  for (const entity of entities) {
    const existing = await prisma.bankingEntity.findUnique({
      where: { name: entity.name },
    });
    if (!existing) {
      await prisma.bankingEntity.create({ data: entity });
      console.log(`Entidad creada: ${entity.name}`);
    }
  }

  // Seed movement reasons
  const reasons = [
    { name: 'Inyección de efectivo', defaultDirection: MovementDirection.IN },
    { name: 'Inyección de saldo', defaultDirection: MovementDirection.IN },
    { name: 'Retiro ATM', defaultDirection: MovementDirection.OUT },
    { name: 'Pago personal', defaultDirection: MovementDirection.OUT },
    { name: 'Pago de negocio', defaultDirection: MovementDirection.OUT },
    { name: 'Otro', defaultDirection: MovementDirection.IN },
  ];

  for (const reason of reasons) {
    const existing = await prisma.movementReason.findUnique({
      where: { name: reason.name },
    });
    if (!existing) {
      await prisma.movementReason.create({ data: reason });
      console.log(`Razón de movimiento creada: ${reason.name}`);
    }
  }

  console.log('\nSeed completado');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
