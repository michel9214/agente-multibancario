import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiTags, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { BalancesService } from './balances.service';
import { BalanceType } from '@prisma/client';

@ApiTags('Balances')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('shifts/:shiftId/balances')
export class BalancesController {
  constructor(private balancesService: BalancesService) {}

  @Get()
  @ApiQuery({ name: 'type', required: false, enum: BalanceType })
  findByShift(
    @Param('shiftId') shiftId: string,
    @Query('type') type?: BalanceType,
  ) {
    return this.balancesService.findByShift(shiftId, type);
  }
}
