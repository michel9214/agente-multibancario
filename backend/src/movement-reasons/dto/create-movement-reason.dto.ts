import { IsEnum, IsString, MinLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { MovementDirection } from '@prisma/client';

export class CreateMovementReasonDto {
  @ApiProperty({ example: 'Inyección de efectivo' })
  @IsString()
  @MinLength(2)
  name: string;

  @ApiProperty({ enum: MovementDirection, example: MovementDirection.IN })
  @IsEnum(MovementDirection)
  defaultDirection: MovementDirection;
}
