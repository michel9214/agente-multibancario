import { Controller, Get, Param, Patch, Body, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { Roles, RolesGuard } from '../common';
import { Role } from '@prisma/client';

@ApiTags('Users')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'), RolesGuard)
@Controller('users')
export class UsersController {
  constructor(private usersService: UsersService) {}

  @Get()
  @Roles(Role.OWNER)
  findAll() {
    return this.usersService.findAll();
  }

  @Get(':id')
  @Roles(Role.OWNER)
  findOne(@Param('id') id: string) {
    return this.usersService.findOne(id);
  }

  @Patch(':id')
  @Roles(Role.OWNER)
  update(@Param('id') id: string, @Body() data: { fullName?: string; photoUrl?: string }) {
    return this.usersService.update(id, data);
  }

  @Patch(':id/toggle-active')
  @Roles(Role.OWNER)
  toggleActive(@Param('id') id: string) {
    return this.usersService.toggleActive(id);
  }
}
