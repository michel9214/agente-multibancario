import { IsNumber, IsArray, ValidateNested, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';
import { BalanceEntryDto } from './open-shift.dto';

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
}
