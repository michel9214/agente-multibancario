import {
  Controller, Get, Param, Query, Res, UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiTags, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { FastifyReply } from 'fastify';
import { ReportsService } from './reports.service';

@ApiTags('Reports')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('reports')
export class ReportsController {
  constructor(private reportsService: ReportsService) {}

  @Get('summary')
  @ApiQuery({ name: 'from', required: false })
  @ApiQuery({ name: 'to', required: false })
  getSummary(@Query('from') from?: string, @Query('to') to?: string) {
    return this.reportsService.getSummary(from, to);
  }

  @Get('shifts/:id/export')
  @ApiQuery({ name: 'format', enum: ['pdf', 'xlsx'] })
  async exportShift(
    @Param('id') id: string,
    @Query('format') format: string,
    @Res() reply: FastifyReply,
  ) {
    if (format === 'pdf') {
      const buffer = await this.reportsService.exportShiftPdf(id);
      reply
        .header('Content-Type', 'application/pdf')
        .header(
          'Content-Disposition',
          `attachment; filename="cuadre-${id.slice(0, 8)}.pdf"`,
        )
        .send(buffer);
    } else {
      const buffer = await this.reportsService.exportShiftExcel(id);
      reply
        .header(
          'Content-Type',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        )
        .header(
          'Content-Disposition',
          `attachment; filename="cuadre-${id.slice(0, 8)}.xlsx"`,
        )
        .send(buffer);
    }
  }
}
