import { IsBoolean, IsEnum, IsOptional, IsString, MinLength } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { MovementDirection } from '@prisma/client';

export class UpdateMovementReasonDto {
  @ApiPropertyOptional({ example: 'Inyección de efectivo' })
  @IsOptional()
  @IsString()
  @MinLength(2)
  name?: string;

  @ApiPropertyOptional({ enum: MovementDirection })
  @IsOptional()
  @IsEnum(MovementDirection)
  defaultDirection?: MovementDirection;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
