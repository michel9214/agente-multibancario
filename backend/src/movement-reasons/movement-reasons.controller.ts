import {
  Controller, Get, Post, Patch,
  Param, Body, Query, UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiTags, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { MovementReasonsService } from './movement-reasons.service';
import { CreateMovementReasonDto } from './dto/create-movement-reason.dto';
import { UpdateMovementReasonDto } from './dto/update-movement-reason.dto';
import { Roles, RolesGuard } from '../common';
import { Role } from '@prisma/client';

@ApiTags('Movement Reasons')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('movement-reasons')
export class MovementReasonsController {
  constructor(private service: MovementReasonsService) {}

  @Get()
  @ApiQuery({ name: 'activeOnly', required: false, type: Boolean })
  findAll(@Query('activeOnly') activeOnly?: string) {
    return this.service.findAll(activeOnly === 'true');
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.service.findOne(id);
  }

  @Post()
  @UseGuards(RolesGuard)
  @Roles(Role.OWNER)
  create(@Body() dto: CreateMovementReasonDto) {
    return this.service.create(dto);
  }

  @Patch(':id')
  @UseGuards(RolesGuard)
  @Roles(Role.OWNER)
  update(@Param('id') id: string, @Body() dto: UpdateMovementReasonDto) {
    return this.service.update(id, dto);
  }
}
