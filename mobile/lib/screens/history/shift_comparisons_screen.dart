import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/shift_comparison.dart';
import '../../widgets/currency_formatter.dart';

class ShiftComparisonDetailScreen extends StatelessWidget {
  final ShiftComparison comparison;

  const ShiftComparisonDetailScreen({super.key, required this.comparison});

  Color _diffColor(double diff) {
    if (diff.abs() < 0.01) return const Color(0xFF0E9F6E);
    if (diff > 0) return const Color(0xFF1A56DB);
    return const Color(0xFFE02424);
  }

  String _diffText(double diff) {
    if (diff.abs() < 0.01) return 'S/ 0.00';
    final prefix = diff > 0 ? '+' : '';
    return '$prefix${formatCurrency(diff)}';
  }

  @override
  Widget build(BuildContext context) {
    final comp = comparison;
    final totalColor = _diffColor(comp.totalDiff);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de Diferencia')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Total difference banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: totalColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: totalColor, width: 2),
            ),
            child: Column(
              children: [
                Icon(
                  comp.totalDiff.abs() < 0.01
                      ? Icons.check_circle
                      : Icons.swap_vert,
                  size: 48,
                  color: totalColor,
                ),
                const SizedBox(height: 8),
                Text(
                  comp.totalDiff.abs() < 0.01
                      ? 'SIN DIFERENCIA'
                      : 'DIFERENCIA TOTAL',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: totalColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _diffText(comp.totalDiff),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 28,
                    color: totalColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Shift info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CIERRE',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[700],
                            )),
                        const SizedBox(height: 4),
                        Text(
                          comp.closingShift.operatorName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          comp.closingShift.closedAt != null
                              ? formatDate(comp.closingShift.closedAt!)
                              : formatDate(comp.closingShift.startedAt),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_forward,
                        color: Colors.grey[500], size: 20),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('APERTURA',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            )),
                        const SizedBox(height: 4),
                        Text(
                          comp.openingShift.operatorName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          formatDate(comp.openingShift.startedAt),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Detail table card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header
                  _headerRow(),
                  const Divider(height: 16),

                  // Cash row
                  _detailRow(
                    'Efectivo',
                    comp.closingShift.cash,
                    comp.openingShift.cash,
                    comp.cashDiff,
                  ),
                  const Divider(height: 8),

                  // Entity rows
                  ...comp.entityComparisons.map((e) => Column(
                        children: [
                          _detailRow(
                            e.entityName,
                            e.closingAmount,
                            e.openingAmount,
                            e.diff,
                          ),
                          const Divider(height: 8),
                        ],
                      )),

                  const SizedBox(height: 4),
                  // Total row
                  _detailRow(
                    'TOTAL',
                    comp.closingShift.cash +
                        comp.entityComparisons.fold<double>(
                            0, (s, e) => s + e.closingAmount),
                    comp.openingShift.cash +
                        comp.entityComparisons.fold<double>(
                            0, (s, e) => s + e.openingAmount),
                    comp.totalDiff,
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Expanded(flex: 3, child: SizedBox()),
          Expanded(
            flex: 2,
            child: Text('Cierre',
                textAlign: TextAlign.right,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange[700],
                )),
          ),
          Expanded(
            flex: 2,
            child: Text('Apertura',
                textAlign: TextAlign.right,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                )),
          ),
          Expanded(
            flex: 2,
            child: Text('Dif.',
                textAlign: TextAlign.right,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                )),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    double closingVal,
    double openingVal,
    double diff, {
    bool bold = false,
  }) {
    final diffColor = _diffColor(diff);
    final fontSize = bold ? 13.0 : 12.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: bold ? Colors.black87 : Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formatCurrencyShort(closingVal),
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formatCurrencyShort(openingVal),
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _diffText(diff),
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: diffColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
