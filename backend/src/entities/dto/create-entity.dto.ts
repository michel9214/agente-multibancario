import { IsString, IsOptional, IsEnum, MinLength, Matches } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { EntityType } from '@prisma/client';

export class CreateEntityDto {
  @ApiProperty({ example: 'BCP' })
  @IsString()
  @MinLength(2)
  name: string;

  @ApiPropertyOptional({ enum: EntityType, default: EntityType.BANK })
  @IsOptional()
  @IsEnum(EntityType)
  type?: EntityType;

  @ApiPropertyOptional({ example: '#1976D2' })
  @IsOptional()
  @IsString()
  @Matches(/^#[0-9A-Fa-f]{6}$/, { message: 'Color must be a hex color code' })
  color?: string;
}
