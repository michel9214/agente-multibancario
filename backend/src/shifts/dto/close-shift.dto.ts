import { IsNumber, IsArray, ValidateNested, Min, IsOptional, IsString, Max } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { BalanceEntryDto } from './open-shift.dto';

export class CommissionEntryDto {
  @ApiPropertyOptional({ description: 'ID de la entidad bancaria (para comisiones por entidad)' })
  @IsOptional()
  @IsString()
  entityId?: string;

  @ApiPropertyOptional({ description: 'Concepto (Depositos, Retiros, Recargas)' })
  @IsOptional()
  @IsString()
  concept?: string;

  @ApiProperty({ example: 15, description: 'Monto de comisión (max 999)' })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(999)
  amount: number;
}

export class CloseShiftDto {
  @ApiProperty({ example: 1800.00, description: 'Efectivo final en caja' })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  endingCash: number;

  @ApiProperty({ type: [BalanceEntryDto], description: 'Saldos de cierre por entidad' })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BalanceEntryDto)
  closingBalances: BalanceEntryDto[];

  @ApiProperty({ type: [CommissionEntryDto], description: 'Comisiones cobradas' })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CommissionEntryDto)
  commissions?: CommissionEntryDto[];
}
