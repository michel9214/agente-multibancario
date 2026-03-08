import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { Role } from '@prisma/client';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
  ) {}

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });

    if (!user || !user.isActive) {
      throw new UnauthorizedException('Credenciales inválidas');
    }

    const passwordValid = await bcrypt.compare(dto.password, user.passwordHash || '');
    if (!passwordValid) {
      throw new UnauthorizedException('Credenciales inválidas');
    }

    const token = this.jwtService.sign({
      sub: user.id,
      email: user.email,
      role: user.role,
    });

    return {
      accessToken: token,
      user: {
        id: user.id,
        email: user.email,
        fullName: user.fullName,
        photoUrl: user.photoUrl,
        role: user.role,
      },
    };
  }

  async loginOperator(operatorId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: operatorId },
    });

    if (!user || !user.isActive || user.role !== Role.OPERATOR) {
      throw new NotFoundException('Operador no encontrado');
    }

    const token = this.jwtService.sign({
      sub: user.id,
      role: user.role,
    });

    return {
      accessToken: token,
      user: {
        id: user.id,
        email: user.email,
        fullName: user.fullName,
        photoUrl: user.photoUrl,
        role: user.role,
      },
    };
  }

  async listOperators() {
    return this.prisma.user.findMany({
      where: { role: Role.OPERATOR, isActive: true },
      select: {
        id: true,
        fullName: true,
        photoUrl: true,
      },
      orderBy: { fullName: 'asc' },
    });
  }

  async register(dto: RegisterDto, currentUserRole?: Role) {
    if (currentUserRole && currentUserRole !== Role.OWNER) {
      throw new ForbiddenException('Solo el dueño puede registrar usuarios');
    }

    if (dto.email) {
      const existing = await this.prisma.user.findUnique({
        where: { email: dto.email },
      });
      if (existing) {
        throw new ConflictException('El email ya está registrado');
      }
    }

    const passwordHash = dto.password ? await bcrypt.hash(dto.password, 10) : null;

    const user = await this.prisma.user.create({
      data: {
        email: dto.email || null,
        passwordHash,
        fullName: dto.fullName,
        role: dto.role || Role.OPERATOR,
      },
    });

    return {
      id: user.id,
      email: user.email,
      fullName: user.fullName,
      role: user.role,
    };
  }
}
