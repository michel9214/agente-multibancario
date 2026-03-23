import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/shift_comparison.dart';
import '../../services/shift_service.dart';
import '../../widgets/currency_formatter.dart';
import '../../widgets/loading_widget.dart';

class ShiftComparisonsScreen extends StatefulWidget {
  const ShiftComparisonsScreen({super.key});

  @override
  State<ShiftComparisonsScreen> createState() => _ShiftComparisonsScreenState();
}

class _ShiftComparisonsScreenState extends State<ShiftComparisonsScreen> {
  List<ShiftComparison> _comparisons = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ShiftService().getShiftComparisons();
      setState(() {
        _comparisons = (data['data'] as List)
            .map((e) => ShiftComparison.fromJson(e))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _diffColor(double diff) {
    if (diff.abs() < 0.01) return const Color(0xFF0E9F6E);
    if (diff > 0) return const Color(0xFF1A56DB);
    return const Color(0xFFE02424);
  }

  String _diffPrefix(double diff) {
    if (diff > 0.005) return '+';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comparación de Turnos')),
      body: _loading
          ? const LoadingWidget(message: 'Calculando diferencias...')
          : _error != null
              ? ErrorDisplay(message: 'Error al cargar', onRetry: _load)
              : _comparisons.isEmpty
                  ? const EmptyState(
                      icon: Icons.compare_arrows,
                      title: 'Sin comparaciones',
                      subtitle:
                          'Se necesitan al menos 2 turnos cerrados',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _comparisons.length,
                        itemBuilder: (context, index) =>
                            _buildComparisonCard(_comparisons[index]),
                      ),
                    ),
    );
  }

  Widget _buildComparisonCard(ShiftComparison comp) {
    final totalColor = _diffColor(comp.totalDiff);
    final totalBg = totalColor.withOpacity(0.08);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Total difference banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: totalBg,
            child: Row(
              children: [
                Icon(
                  comp.totalDiff.abs() < 0.01
                      ? Icons.check_circle
                      : comp.totalDiff > 0
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                  color: totalColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comp.totalDiff.abs() < 0.01
                            ? 'SIN DIFERENCIA'
                            : 'DIFERENCIA',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: totalColor,
                        ),
                      ),
                      Text(
                        '${_diffPrefix(comp.totalDiff)}${formatCurrency(comp.totalDiff)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          color: totalColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shift info row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CIERRE',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[700],
                              )),
                          Text(
                            comp.closingShift.operatorName,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            comp.closingShift.closedAt != null
                                ? formatDateTime(comp.closingShift.closedAt!)
                                : formatDateTime(comp.closingShift.startedAt),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward,
                        color: Colors.grey[400], size: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('APERTURA',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              )),
                          Text(
                            comp.openingShift.operatorName,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            formatDateTime(comp.openingShift.startedAt),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Header row
                Row(
                  children: [
                    const Expanded(
                        flex: 3,
                        child: Text('',
                            style: TextStyle(fontSize: 11))),
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
                const SizedBox(height: 6),

                // Cash row
                _comparisonRow(
                  'Efectivo',
                  comp.closingShift.cash,
                  comp.openingShift.cash,
                  comp.cashDiff,
                ),

                // Entity rows
                ...comp.entityComparisons.map((e) => _comparisonRow(
                      e.entityName,
                      e.closingAmount,
                      e.openingAmount,
                      e.diff,
                    )),

                const Divider(height: 16),

                // Total row
                _comparisonRow(
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
        ],
      ),
    );
  }

  Widget _comparisonRow(
    String label,
    double closingVal,
    double openingVal,
    double diff, {
    bool bold = false,
  }) {
    final diffColor = _diffColor(diff);
    final weight = bold ? FontWeight.w700 : FontWeight.w500;
    final fontSize = bold ? 13.0 : 12.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: bold ? Colors.black87 : Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formatCurrencyShort(closingVal),
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: weight,
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
                fontWeight: weight,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${_diffPrefix(diff)}${formatCurrencyShort(diff)}',
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
