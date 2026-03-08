import {
  Controller, Get, Post, Patch, Delete,
  Param, Body, UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { MovementsService } from './movements.service';
import { CreateMovementDto } from './dto/create-movement.dto';
import { CurrentUser } from '../common';

@ApiTags('Movements')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('shifts/:shiftId/movements')
export class MovementsController {
  constructor(private movementsService: MovementsService) {}

  @Post()
  create(
    @Param('shiftId') shiftId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: CreateMovementDto,
  ) {
    return this.movementsService.create(shiftId, userId, dto);
  }

  @Get()
  findByShift(@Param('shiftId') shiftId: string) {
    return this.movementsService.findByShift(shiftId);
  }

  @Patch(':id')
  update(
    @Param('id') id: string,
    @CurrentUser('id') userId: string,
    @CurrentUser('role') userRole: any,
    @Body() dto: Partial<CreateMovementDto>,
  ) {
    return this.movementsService.update(id, userId, userRole, dto);
  }

  @Delete(':id')
  remove(
    @Param('id') id: string,
    @CurrentUser('id') userId: string,
    @CurrentUser('role') userRole: any,
  ) {
    return this.movementsService.remove(id, userId, userRole);
  }
}
