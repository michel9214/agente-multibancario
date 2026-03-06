import { Module } from '@nestjs/common';
import { MovementReasonsService } from './movement-reasons.service';
import { MovementReasonsController } from './movement-reasons.controller';

@Module({
  controllers: [MovementReasonsController],
  providers: [MovementReasonsService],
  exports: [MovementReasonsService],
})
export class MovementReasonsModule {}
