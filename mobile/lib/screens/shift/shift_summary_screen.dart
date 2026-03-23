import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/reconciliation.dart';
import '../../services/shift_service.dart';
import '../../services/report_service.dart';
import '../../widgets/currency_formatter.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/photo_picker.dart';

const _kSlate = Color(0xFF1E293B);
const _kMuted = Color(0xFF64748B);
const _kGreen = Color(0xFF059669);
const _kRed = Color(0xFFDC2626);
const _kBlue = Color(0xFF2563EB);
const _kAmber = Color(0xFFD97706);
const _kTeal = Color(0xFF0D9488);

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
    if (r.isBalanced || r.isSurplus) return _kGreen;
    return _kRed;
  }

  Color _discrepancyBgColor(Reconciliation r) {
    if (r.isBalanced || r.isSurplus) return _kGreen.withOpacity(0.05);
    return _kRed.withOpacity(0.05);
  }

  Color _discrepancyTextColor(Reconciliation r) {
    if (r.isBalanced || r.isSurplus) return _kGreen;
    return _kRed;
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
                  leading: Icon(Icons.picture_as_pdf, color: _kRed),
                  title: Text('Exportar PDF'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'xlsx',
                child: ListTile(
                  leading: Icon(Icons.table_chart, color: _kGreen),
                  title: Text('Exportar Excel'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 32),
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
                  style: GoogleFonts.dmSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Discrepancia: ${formatCurrency(r.discrepancy)}',
                  style: GoogleFonts.dmMono(fontSize: 18, color: textColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Apertura card
          Card(
            color: _kBlue.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('APERTURA',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        color: _kBlue,
                        fontSize: 13,
                        letterSpacing: 0.3,
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
                      bold: true, color: _kBlue),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Movements card
          if (r.details.movements.isNotEmpty) ...[
            Card(
              color: Color(0xFF7C3AED).withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MOVIMIENTOS (${r.details.movements.length})',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7C3AED),
                          fontSize: 13,
                          letterSpacing: 0.3,
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
                                    ? _kGreen
                                    : _kRed,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _movementLabel(m.type) +
                                      (m.description != null
                                          ? ' - ${m.description}'
                                          : ''),
                                  style: GoogleFonts.dmSans(fontSize: 13, color: _kSlate),
                                ),
                              ),
                              Text(
                                '${m.direction == 'IN' ? '+' : '-'} ${formatCurrency(m.amount)}',
                                style: GoogleFonts.dmMono(
                                  fontWeight: FontWeight.w600,
                                  color: m.direction == 'IN'
                                      ? _kGreen
                                      : _kRed,
                                ),
                              ),
                            ],
                          ),
                        )),
                    const Divider(),
                    _row('Movimientos netos',
                        formatCurrency(r.totalMovements),
                        bold: true, color: Color(0xFF7C3AED)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Total esperado (sin comisiones)
          Card(
            color: _kGreen.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL ESPERADO',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        color: _kGreen,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      )),
                  const SizedBox(height: 8),
                  _row('Total apertura', formatCurrency(r.totalOpening)),
                  if (r.details.movements.isNotEmpty)
                    _row('Movimientos netos', formatCurrency(r.totalMovements)),
                  const Divider(),
                  _row('Debería tener', formatCurrency(r.totalExpected),
                      bold: true, color: _kGreen),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Cierre card
          Card(
            color: _kAmber.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CIERRE',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        color: _kAmber,
                        fontSize: 13,
                        letterSpacing: 0.3,
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
                      bold: true, color: _kAmber),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Commissions card
          if (r.details.commissions.isNotEmpty) ...[
            Card(
              color: _kTeal.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('COMISIONES',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          color: _kTeal,
                          fontSize: 13,
                          letterSpacing: 0.3,
                        )),
                    const SizedBox(height: 8),
                    ...r.details.commissions
                        .map((c) => _row(c.name, formatCurrency(c.amount))),
                    const Divider(),
                    _row('Total comisiones',
                        formatCurrency(r.totalCommissions),
                        bold: true, color: _kTeal),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Pending deliveries card
          if (r.details.pendingDeliveries.isNotEmpty) ...[
            Card(
              color: const Color(0xFF7C3AED).withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PENDIENTES POR ENTREGAR',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF7C3AED),
                          fontSize: 13,
                          letterSpacing: 0.3,
                        )),
                    const SizedBox(height: 8),
                    ...r.details.pendingDeliveries.map((pd) => _row(
                        '${pd.entityName}: ${pd.description ?? ""}',
                        formatCurrency(pd.amount))),
                    const Divider(),
                    _row('Total pendientes por entregar',
                        formatCurrency(r.totalPendingDeliveries),
                        bold: true, color: const Color(0xFF7C3AED)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

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
                    formatCurrency(r.discrepancy),
                    bold: true,
                    color: statusColor,
                    fontSize: 16,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.statusLabel,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
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
              color: _kMuted.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.note_alt, color: _kMuted, size: 20),
                        const SizedBox(width: 8),
                        Text('JUSTIFICACION',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              color: _kMuted,
                              fontSize: 13,
                              letterSpacing: 0.3,
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
                            const Icon(Icons.photo, color: _kBlue, size: 18),
                            const SizedBox(width: 6),
                            Text('Ver evidencia',
                                style: GoogleFonts.dmSans(
                                    color: _kBlue,
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
                style: GoogleFonts.dmSans(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                  color: color ?? _kSlate,
                  fontSize: fontSize,
                )),
          ),
          Text(value,
              style: GoogleFonts.dmMono(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: color ?? _kSlate,
                fontSize: fontSize,
              )),
        ],
      ),
    );
  }
}
