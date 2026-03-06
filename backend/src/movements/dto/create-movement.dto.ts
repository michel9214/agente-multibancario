import { IsEnum, IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MovementType, MovementDirection } from '@prisma/client';

export class CreateMovementDto {
  @ApiProperty({ enum: MovementType, example: MovementType.CASH_INJECTION })
  @IsEnum(MovementType)
  type: MovementType;

  @ApiPropertyOptional({ description: 'ID de la razón de movimiento' })
  @IsOptional()
  @IsUUID()
  reasonId?: string;

  @ApiProperty({ enum: MovementDirection, example: MovementDirection.IN })
  @IsEnum(MovementDirection)
  direction: MovementDirection;

  @ApiProperty({ example: 500.00 })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number;

  @ApiPropertyOptional({ example: 'Inyección de efectivo del dueño' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  receiptPhotoUrl?: string;
}
