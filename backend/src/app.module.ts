import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { EntitiesModule } from './entities/entities.module';
import { ShiftsModule } from './shifts/shifts.module';
import { BalancesModule } from './balances/balances.module';
import { MovementsModule } from './movements/movements.module';
import { ReconciliationModule } from './reconciliation/reconciliation.module';
import { UploadsModule } from './uploads/uploads.module';
import { ReportsModule } from './reports/reports.module';
import { MovementReasonsModule } from './movement-reasons/movement-reasons.module';
import { SeedController } from './seed.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    UsersModule,
    EntitiesModule,
    ShiftsModule,
    BalancesModule,
    MovementsModule,
    MovementReasonsModule,
    ReconciliationModule,
    UploadsModule,
    ReportsModule,
  ],
  controllers: [SeedController],
})
export class AppModule {}
