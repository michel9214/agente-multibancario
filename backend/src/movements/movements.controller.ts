import {
  Controller, Get, Post, Delete,
  Param, Body, UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { MovementsService } from './movements.service';
import { CreateMovementDto } from './dto/create-movement.dto';

@ApiTags('Movements')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('shifts/:shiftId/movements')
export class MovementsController {
  constructor(private movementsService: MovementsService) {}

  @Post()
  create(
    @Param('shiftId') shiftId: string,
    @Body() dto: CreateMovementDto,
  ) {
    return this.movementsService.create(shiftId, dto);
  }

  @Get()
  findByShift(@Param('shiftId') shiftId: string) {
    return this.movementsService.findByShift(shiftId);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.movementsService.remove(id);
  }
}
