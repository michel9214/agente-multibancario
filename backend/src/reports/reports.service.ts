import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ReconciliationService } from '../reconciliation/reconciliation.service';
import Decimal from 'decimal.js';
import * as ExcelJS from 'exceljs';

@Injectable()
export class ReportsService {
  constructor(
    private prisma: PrismaService,
    private reconciliation: ReconciliationService,
  ) {}

  async getSummary(from?: string, to?: string) {
    const where: any = { status: 'CLOSED' as const };
    if (from || to) {
      where.closedAt = {};
      if (from) where.closedAt.gte = new Date(from);
      if (to) where.closedAt.lte = new Date(to);
    }

    const shifts = await this.prisma.shift.findMany({
      where,
      include: {
        balanceEntries: { include: { entity: true } },
        operator: { select: { fullName: true } },
      },
      orderBy: { closedAt: 'desc' },
    });

    const totalShifts = shifts.length;
    const balanced = shifts.filter(
      (s) => s.discrepancy && new Decimal(s.discrepancy.toString()).equals(0),
    ).length;
    const unbalanced = totalShifts - balanced;

    // Amounts per entity
    const entityTotals: Record<string, { name: string; total: number }> = {};
    for (const shift of shifts) {
      for (const entry of shift.balanceEntries) {
        if (entry.type === 'CLOSING') {
          if (!entityTotals[entry.entityId]) {
            entityTotals[entry.entityId] = {
              name: entry.entity.name,
              total: 0,
            };
          }
          entityTotals[entry.entityId].total += Number(entry.amount);
        }
      }
    }

    // Discrepancy trend
    const discrepancyTrend = shifts
      .filter((s) => s.closedAt)
      .map((s) => ({
        date: s.closedAt!.toISOString().split('T')[0],
        discrepancy: Number(s.discrepancy || 0),
        operator: s.operator.fullName,
      }))
      .reverse();

    return {
      totalShifts,
      balanced,
      unbalanced,
      entityTotals: Object.values(entityTotals),
      discrepancyTrend,
    };
  }

  async exportShiftPdf(shiftId: string): Promise<Buffer> {
    const reconciliation = await this.reconciliation.getReconciliation(shiftId);
    const shift = await this.prisma.shift.findUnique({
      where: { id: shiftId },
      include: { operator: { select: { fullName: true } } },
    });
    if (!shift) throw new NotFoundException('Turno no encontrado');

    // Generate PDF using pdfmake
    const PdfPrinter = require('pdfmake');
    const fonts = {
      Roboto: {
        normal: require.resolve('pdfmake/build/vfs_fonts.js') ? undefined : undefined,
      },
    };

    // Simple PDF generation with pdfmake
    const pdfmake = require('pdfmake/build/pdfmake');
    const pdfFonts = require('pdfmake/build/vfs_fonts');
    if (pdfFonts?.pdfMake?.vfs) {
      pdfmake.vfs = pdfFonts.pdfMake.vfs;
    }

    const statusText =
      reconciliation.status === 'BALANCED'
        ? 'CUADRADO'
        : reconciliation.status === 'SURPLUS'
          ? 'SOBRANTE'
          : 'FALTANTE';

    const docDefinition = {
      content: [
        { text: 'Reporte de Cuadre de Caja', style: 'header' },
        { text: `Operador: ${shift.operator.fullName}`, margin: [0, 10, 0, 5] },
        {
          text: `Fecha: ${shift.startedAt.toLocaleDateString('es-PE')} - ${shift.closedAt?.toLocaleDateString('es-PE') || 'Abierto'}`,
          margin: [0, 0, 0, 10],
        },
        { text: 'Resumen', style: 'subheader' },
        {
          table: {
            widths: ['*', 'auto'],
            body: [
              ['Efectivo Inicial', `S/ ${reconciliation.startingCash.toFixed(2)}`],
              ['Efectivo Final', `S/ ${reconciliation.endingCash.toFixed(2)}`],
              ['Total Saldos Apertura', `S/ ${reconciliation.totalOpeningBalance.toFixed(2)}`],
              ['Total Saldos Cierre', `S/ ${reconciliation.totalClosingBalance.toFixed(2)}`],
              ['Movimientos Netos', `S/ ${reconciliation.totalMovements.toFixed(2)}`],
              [
                { text: 'Discrepancia', bold: true },
                {
                  text: `S/ ${reconciliation.discrepancy.toFixed(2)} (${statusText})`,
                  bold: true,
                  color: reconciliation.status === 'BALANCED' ? 'green' : 'red',
                },
              ],
            ],
          },
          margin: [0, 5, 0, 15],
        },
        { text: 'Saldos de Apertura', style: 'subheader' },
        {
          table: {
            widths: ['*', 'auto'],
            body: [
              [{ text: 'Entidad', bold: true }, { text: 'Monto', bold: true }],
              ...reconciliation.details.openingBalances.map((b) => [
                b.entityName,
                `S/ ${b.amount.toFixed(2)}`,
              ]),
            ],
          },
          margin: [0, 5, 0, 15],
        },
        { text: 'Saldos de Cierre', style: 'subheader' },
        {
          table: {
            widths: ['*', 'auto'],
            body: [
              [{ text: 'Entidad', bold: true }, { text: 'Monto', bold: true }],
              ...reconciliation.details.closingBalances.map((b) => [
                b.entityName,
                `S/ ${b.amount.toFixed(2)}`,
              ]),
            ],
          },
          margin: [0, 5, 0, 15],
        },
        ...(reconciliation.details.movements.length > 0
          ? [
              { text: 'Movimientos', style: 'subheader' as const },
              {
                table: {
                  widths: ['auto', 'auto', 'auto', '*'],
                  body: [
                    [
                      { text: 'Tipo', bold: true },
                      { text: 'Dirección', bold: true },
                      { text: 'Monto', bold: true },
                      { text: 'Descripción', bold: true },
                    ],
                    ...reconciliation.details.movements.map((m) => [
                      m.type,
                      m.direction === 'IN' ? 'Entrada' : 'Salida',
                      `S/ ${m.amount.toFixed(2)}`,
                      m.description || '-',
                    ]),
                  ],
                },
                margin: [0, 5, 0, 15],
              },
            ]
          : []),
      ],
      styles: {
        header: { fontSize: 18, bold: true, margin: [0, 0, 0, 10] },
        subheader: { fontSize: 14, bold: true, margin: [0, 10, 0, 5] },
      },
    };

    return new Promise((resolve, reject) => {
      const pdfDoc = pdfmake.createPdf(docDefinition);
      pdfDoc.getBuffer((buffer: Buffer) => {
        resolve(buffer);
      });
    });
  }

  async exportShiftExcel(shiftId: string): Promise<Buffer> {
    const reconciliation = await this.reconciliation.getReconciliation(shiftId);
    const shift = await this.prisma.shift.findUnique({
      where: { id: shiftId },
      include: { operator: { select: { fullName: true } } },
    });
    if (!shift) throw new NotFoundException('Turno no encontrado');

    const workbook = new ExcelJS.Workbook();
    const sheet = workbook.addWorksheet('Cuadre de Caja');

    // Header
    sheet.mergeCells('A1:D1');
    const titleCell = sheet.getCell('A1');
    titleCell.value = 'Reporte de Cuadre de Caja';
    titleCell.font = { size: 16, bold: true };

    sheet.getCell('A3').value = 'Operador:';
    sheet.getCell('B3').value = shift.operator.fullName;
    sheet.getCell('A4').value = 'Inicio:';
    sheet.getCell('B4').value = shift.startedAt.toLocaleString('es-PE');
    sheet.getCell('A5').value = 'Cierre:';
    sheet.getCell('B5').value = shift.closedAt?.toLocaleString('es-PE') || 'Abierto';

    // Summary
    let row = 7;
    sheet.getCell(`A${row}`).value = 'Resumen';
    sheet.getCell(`A${row}`).font = { size: 14, bold: true };
    row++;

    const summaryData = [
      ['Efectivo Inicial', reconciliation.startingCash],
      ['Efectivo Final', reconciliation.endingCash],
      ['Total Saldos Apertura', reconciliation.totalOpeningBalance],
      ['Total Saldos Cierre', reconciliation.totalClosingBalance],
      ['Movimientos Netos', reconciliation.totalMovements],
      ['Discrepancia', reconciliation.discrepancy],
    ];

    for (const [label, value] of summaryData) {
      sheet.getCell(`A${row}`).value = label as string;
      const cell = sheet.getCell(`B${row}`);
      cell.value = value as number;
      cell.numFmt = '"S/ "#,##0.00';
      row++;
    }

    // Opening balances
    row += 1;
    sheet.getCell(`A${row}`).value = 'Saldos de Apertura';
    sheet.getCell(`A${row}`).font = { bold: true };
    row++;
    for (const b of reconciliation.details.openingBalances) {
      sheet.getCell(`A${row}`).value = b.entityName;
      const cell = sheet.getCell(`B${row}`);
      cell.value = b.amount;
      cell.numFmt = '"S/ "#,##0.00';
      row++;
    }

    // Closing balances
    row += 1;
    sheet.getCell(`A${row}`).value = 'Saldos de Cierre';
    sheet.getCell(`A${row}`).font = { bold: true };
    row++;
    for (const b of reconciliation.details.closingBalances) {
      sheet.getCell(`A${row}`).value = b.entityName;
      const cell = sheet.getCell(`B${row}`);
      cell.value = b.amount;
      cell.numFmt = '"S/ "#,##0.00';
      row++;
    }

    // Movements
    if (reconciliation.details.movements.length > 0) {
      row += 1;
      sheet.getCell(`A${row}`).value = 'Movimientos';
      sheet.getCell(`A${row}`).font = { bold: true };
      row++;
      sheet.getCell(`A${row}`).value = 'Tipo';
      sheet.getCell(`B${row}`).value = 'Dirección';
      sheet.getCell(`C${row}`).value = 'Monto';
      sheet.getCell(`D${row}`).value = 'Descripción';
      row++;
      for (const m of reconciliation.details.movements) {
        sheet.getCell(`A${row}`).value = m.type;
        sheet.getCell(`B${row}`).value = m.direction === 'IN' ? 'Entrada' : 'Salida';
        const cell = sheet.getCell(`C${row}`);
        cell.value = m.amount;
        cell.numFmt = '"S/ "#,##0.00';
        sheet.getCell(`D${row}`).value = m.description || '-';
        row++;
      }
    }

    // Auto-width columns
    sheet.columns.forEach((col) => {
      col.width = 20;
    });

    const buffer = await workbook.xlsx.writeBuffer();
    return Buffer.from(buffer);
  }
}
