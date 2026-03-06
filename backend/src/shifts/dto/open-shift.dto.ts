import { IsNumber, IsArray, ValidateNested, IsString, IsOptional, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class BalanceEntryDto {
  @ApiProperty({ example: 'entity-uuid' })
  @IsString()
  entityId: string;

  @ApiProperty({ example: 1500.50 })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  amount: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  receiptPhotoUrl?: string;
}

export class OpenShiftDto {
  @ApiProperty({ example: 2000.00, description: 'Efectivo inicial en caja' })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  startingCash: number;

  @ApiProperty({ type: [BalanceEntryDto], description: 'Saldos de apertura por entidad' })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BalanceEntryDto)
  openingBalances: BalanceEntryDto[];
}
