import { Module } from '@nestjs/common';
import { ShiftsService } from './shifts.service';
import { ShiftsController } from './shifts.controller';
import { ReconciliationModule } from '../reconciliation/reconciliation.module';
import { UploadsModule } from '../uploads/uploads.module';

@Module({
  imports: [ReconciliationModule, UploadsModule],
  controllers: [ShiftsController],
  providers: [ShiftsService],
  exports: [ShiftsService],
})
export class ShiftsModule {}
