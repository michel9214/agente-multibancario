import {
  Controller, Get, Post, Patch,
  Param, Body, Query, UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiTags, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { ShiftsService } from './shifts.service';
import { OpenShiftDto } from './dto/open-shift.dto';
import { CloseShiftDto, FinalCloseDto } from './dto/close-shift.dto';
import { CurrentUser } from '../common';

@ApiTags('Shifts')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('shifts')
export class ShiftsController {
  constructor(private shiftsService: ShiftsService) {}

  @Post()
  openShift(
    @CurrentUser('id') userId: string,
    @Body() dto: OpenShiftDto,
  ) {
    return this.shiftsService.openShift(userId, dto);
  }

  @Get('active')
  getActiveShift(
    @CurrentUser('id') userId: string,
    @CurrentUser('role') userRole: any,
  ) {
    return this.shiftsService.getActiveShift(userId, userRole);
  }

  @Get('last-closed')
  getLastClosedShift() {
    return this.shiftsService.getLastClosedShift();
  }

  @Get()
  @ApiQuery({ name: 'page', required: false })
  @ApiQuery({ name: 'limit', required: false })
  findAll(
    @CurrentUser('id') userId: string,
    @CurrentUser('role') userRole: any,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.shiftsService.findAll(userId, userRole, page, limit);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.shiftsService.findOne(id);
  }

  @Patch(':id/preclose')
  preCloseShift(
    @Param('id') id: string,
    @CurrentUser('id') userId: string,
    @CurrentUser('role') userRole: any,
    @Body() dto: CloseShiftDto,
  ) {
    return this.shiftsService.preCloseShift(id, userId, userRole, dto);
  }

  @Patch(':id/close')
  finalCloseShift(
    @Param('id') id: string,
    @CurrentUser('id') userId: string,
    @CurrentUser('role') userRole: any,
    @Body() dto: FinalCloseDto,
  ) {
    return this.shiftsService.finalCloseShift(id, userId, userRole, dto);
  }

  @Patch(':id/commissions')
  updateCommissions(
    @Param('id') id: string,
    @CurrentUser('id') userId: string,
    @CurrentUser('role') userRole: any,
    @Body() body: { commissions: { entityId?: string; concept?: string; amount: number }[] },
  ) {
    return this.shiftsService.updateCommissions(id, userId, userRole, body.commissions);
  }

  @Patch(':id/annul-close')
  annulClose(
    @Param('id') id: string,
    @CurrentUser('role') userRole: any,
  ) {
    return this.shiftsService.annulClose(id, userRole);
  }

  @Patch(':id/reopen')
  reopenShift(
    @Param('id') id: string,
    @CurrentUser('id') userId: string,
    @CurrentUser('role') userRole: any,
  ) {
    return this.shiftsService.reopenShift(id, userId, userRole);
  }
}
