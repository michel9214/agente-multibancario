import {
  Controller, Get, Post, Patch, Delete,
  Param, Body, Query, UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiTags, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { EntitiesService } from './entities.service';
import { CreateEntityDto } from './dto/create-entity.dto';
import { UpdateEntityDto } from './dto/update-entity.dto';
import { Roles, RolesGuard } from '../common';
import { Role } from '@prisma/client';

@ApiTags('Entities')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('entities')
export class EntitiesController {
  constructor(private entitiesService: EntitiesService) {}

  @Get()
  @ApiQuery({ name: 'activeOnly', required: false, type: Boolean })
  findAll(@Query('activeOnly') activeOnly?: string) {
    return this.entitiesService.findAll(activeOnly === 'true');
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.entitiesService.findOne(id);
  }

  @Post()
  @UseGuards(RolesGuard)
  @Roles(Role.OWNER)
  create(@Body() dto: CreateEntityDto) {
    return this.entitiesService.create(dto);
  }

  @Patch(':id')
  @UseGuards(RolesGuard)
  @Roles(Role.OWNER)
  update(@Param('id') id: string, @Body() dto: UpdateEntityDto) {
    return this.entitiesService.update(id, dto);
  }

  @Delete(':id')
  @UseGuards(RolesGuard)
  @Roles(Role.OWNER)
  remove(@Param('id') id: string) {
    return this.entitiesService.remove(id);
  }
}
