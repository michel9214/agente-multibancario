import { Controller, Post, Get, Body, Param, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { CurrentUser, Roles, RolesGuard } from '../common';
import { Role } from '@prisma/client';

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Get('operators')
  listOperators() {
    return this.authService.listOperators();
  }

  @Post('login-operator/:id')
  loginOperator(@Param('id') id: string) {
    return this.authService.loginOperator(id);
  }

  @Post('register')
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(Role.OWNER)
  register(
    @Body() dto: RegisterDto,
    @CurrentUser('role') role: Role,
  ) {
    return this.authService.register(dto, role);
  }
}
