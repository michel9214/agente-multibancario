import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { ReconciliationService } from './reconciliation.service';

@ApiTags('Reconciliation')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('shifts/:shiftId/reconciliation')
export class ReconciliationController {
  constructor(private reconciliationService: ReconciliationService) {}

  @Get()
  getReconciliation(@Param('shiftId') shiftId: string) {
    return this.reconciliationService.getReconciliation(shiftId);
  }
}
