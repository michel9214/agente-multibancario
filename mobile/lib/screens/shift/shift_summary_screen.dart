import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/reconciliation.dart';
import '../../services/shift_service.dart';
import '../../services/report_service.dart';
import '../../widgets/currency_formatter.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/photo_picker.dart';

class ShiftSummaryScreen extends ConsumerStatefulWidget {
  final String shiftId;
  const ShiftSummaryScreen({super.key, required this.shiftId});

  @override
  ConsumerState<ShiftSummaryScreen> createState() => _ShiftSummaryScreenState();
}

class _ShiftSummaryScreenState extends ConsumerState<ShiftSummaryScreen> {
  Reconciliation? _reconciliation;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final recon = await ShiftService().getReconciliation(widget.shiftId);
      setState(() {
        _reconciliation = recon;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _exportAndShare(String format) async {
    try {
      final bytes = await ReportService().exportShift(widget.shiftId, format);
      final dir = await getTemporaryDirectory();
      final ext = format == 'pdf' ? 'pdf' : 'xlsx';
      final file = File('${dir.path}/cuadre_${widget.shiftId.substring(0, 8)}.$ext');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Reporte de cuadre de caja',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    }
  }

  /// Color based on discrepancy: zero=green, positive=green (surplus), negative=red (deficit)
  Color _discrepancyColor(Reconciliation r) {
    if (r.isBalanced || r.isSurplus) return Colors.green;
    return Colors.red;
  }

  Color _discrepancyBgColor(Reconciliation r) {
    if (r.isBalanced || r.isSurplus) return Colors.green[50]!;
    return Colors.red[50]!;
  }

  Color _discrepancyTextColor(Reconciliation r) {
    if (r.isBalanced || r.isSurplus) return Colors.green[800]!;
    return Colors.red[800]!;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resultado del Cuadre')),
        body: const LoadingWidget(message: 'Calculando cuadre...'),
      );
    }

    if (_error != null || _reconciliation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resultado del Cuadre')),
        body: ErrorDisplay(
          message: 'Error al cargar el cuadre',
          onRetry: _loadData,
        ),
      );
    }

    final r = _reconciliation!;
    final statusColor = _discrepancyColor(r);
    final bgColor = _discrepancyBgColor(r);
    final textColor = _discrepancyTextColor(r);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado del Cuadre'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.share),
            onSelected: _exportAndShare,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pdf',
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text('Exportar PDF'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'xlsx',
                child: ListTile(
                  leading: Icon(Icons.table_chart, color: Colors.green),
                  title: Text('Exportar Excel'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status banner
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor, width: 2),
            ),
            child: Column(
              children: [
                Icon(
                  r.isBalanced
                      ? Icons.check_circle
                      : r.isSurplus
                          ? Icons.trending_up
                          : Icons.trending_down,
                  size: 64,
                  color: statusColor,
                ),
                const SizedBox(height: 12),
                Text(
                  r.statusLabel,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Discrepancia: ${formatCurrency(r.totalClosing - r.totalExpected)}',
                  style: TextStyle(fontSize: 18, color: textColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Apertura card
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('APERTURA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                        fontSize: 13,
                      )),
                  const SizedBox(height: 8),
                  _row('Efectivo inicial', formatCurrency(r.startingCash)),
                  ...r.details.openingBalances
                      .map((b) => _row(b.entityName, formatCurrency(b.amount))),
                  const Divider(),
                  _row('Total saldos apertura',
                      formatCurrency(r.totalOpeningBalance),
                      bold: true),
                  _row('Total apertura', formatCurrency(r.totalOpening),
                      bold: true, color: Colors.blue[800]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Movements card
          if (r.details.movements.isNotEmpty) ...[
            Card(
              color: Colors.purple[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MOVIMIENTOS (${r.details.movements.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[800],
                          fontSize: 13,
                        )),
                    const SizedBox(height: 8),
                    ...r.details.movements.map((m) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Icon(
                                m.direction == 'IN'
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                size: 16,
                                color: m.direction == 'IN'
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _movementLabel(m.type) +
                                      (m.description != null
                                          ? ' - ${m.description}'
                                          : ''),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                '${m.direction == 'IN' ? '+' : '-'} ${formatCurrency(m.amount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: m.direction == 'IN'
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        )),
                    const Divider(),
                    _row('Movimientos netos',
                        formatCurrency(r.totalMovements),
                        bold: true, color: Colors.purple[800]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Commissions card
          if (r.details.commissions.isNotEmpty) ...[
            Card(
              color: Colors.teal[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('COMISIONES',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[800],
                          fontSize: 13,
                        )),
                    const SizedBox(height: 8),
                    ...r.details.commissions
                        .map((c) => _row(c.name, formatCurrency(c.amount))),
                    const Divider(),
                    _row('Total comisiones',
                        formatCurrency(r.totalCommissions),
                        bold: true, color: Colors.teal[800]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Total esperado (sin comisiones)
          Card(
            color: Colors.green[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL ESPERADO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                        fontSize: 13,
                      )),
                  const SizedBox(height: 8),
                  _row('Total apertura', formatCurrency(r.totalOpening)),
                  if (r.details.movements.isNotEmpty)
                    _row('Movimientos netos', formatCurrency(r.totalMovements)),
                  const Divider(),
                  _row('Debería tener', formatCurrency(r.totalExpected),
                      bold: true, color: Colors.green[800]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Cierre card
          Card(
            color: Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CIERRE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                        fontSize: 13,
                      )),
                  const SizedBox(height: 8),
                  _row('Efectivo final', formatCurrency(r.endingCash)),
                  ...r.details.closingBalances
                      .map((b) => _row(b.entityName, formatCurrency(b.amount))),
                  const Divider(),
                  _row('Total saldos cierre',
                      formatCurrency(r.totalClosingBalance),
                      bold: true),
                  _row('Total cierre', formatCurrency(r.totalClosing),
                      bold: true, color: Colors.orange[800]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Discrepancy result
          Card(
            color: bgColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row('Total esperado', formatCurrency(r.totalExpected)),
                  _row('Total cierre', formatCurrency(r.totalClosing)),
                  const Divider(),
                  _row(
                    'DISCREPANCIA',
                    formatCurrency(r.totalClosing - r.totalExpected),
                    bold: true,
                    color: statusColor,
                    fontSize: 16,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.statusLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Discrepancy justification
          if (r.discrepancyNote != null || r.discrepancyPhotoUrl != null) ...[
            const SizedBox(height: 8),
            Card(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.note_alt, color: Colors.grey[700], size: 20),
                        const SizedBox(width: 8),
                        Text('JUSTIFICACION',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                              fontSize: 13,
                            )),
                      ],
                    ),
                    if (r.discrepancyNote != null) ...[
                      const SizedBox(height: 8),
                      Text(r.discrepancyNote!,
                          style: const TextStyle(fontSize: 14)),
                    ],
                    if (r.discrepancyPhotoUrl != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => showPhotoPreview(
                            context, r.discrepancyPhotoUrl!),
                        child: Row(
                          children: [
                            const Icon(Icons.photo, color: Colors.blue, size: 18),
                            const SizedBox(width: 6),
                            const Text('Ver evidencia',
                                style: TextStyle(
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Volver al Inicio'),
            ),
          ),
        ],
      ),
    );
  }

  String _movementLabel(String type) {
    switch (type) {
      case 'CASH_INJECTION': return 'Inyección de efectivo';
      case 'BALANCE_INJECTION': return 'Inyección de saldo';
      case 'ATM_WITHDRAWAL': return 'Retiro ATM';
      case 'PERSONAL_PAYMENT': return 'Pago personal';
      case 'BUSINESS_PAYMENT': return 'Pago de negocio';
      case 'OTHER': return 'Otro';
      default: return type;
    }
  }

  Widget _row(String label, String value,
      {bool bold = false, Color? color, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color,
                  fontSize: fontSize,
                )),
          ),
          Text(value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: color,
                fontSize: fontSize,
              )),
        ],
      ),
    );
  }
}
