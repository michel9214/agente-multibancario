import 'package:flutter/material.dart';
import '../../models/shift.dart';
import '../../services/shift_service.dart';
import '../../widgets/currency_formatter.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/photo_picker.dart';
import 'section_detail_screen.dart';

class ShiftDetailScreen extends StatefulWidget {
  final String shiftId;
  const ShiftDetailScreen({super.key, required this.shiftId});

  @override
  State<ShiftDetailScreen> createState() => _ShiftDetailScreenState();
}

class _ShiftDetailScreenState extends State<ShiftDetailScreen> {
  Shift? _shift;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final shift = await ShiftService().getShift(widget.shiftId);
      setState(() {
        _shift = shift;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Color _discrepancyColor(double discrepancy) {
    if (discrepancy.abs() < 0.01 || discrepancy > 0) return Colors.green;
    return Colors.red;
  }

  String _discrepancyLabel(double discrepancy) {
    if (discrepancy.abs() < 0.01) return 'CUADRADO';
    if (discrepancy > 0) return 'SOBRANTE';
    return 'FALTANTE';
  }

  IconData _discrepancyIcon(double discrepancy) {
    if (discrepancy.abs() < 0.01) return Icons.check_circle;
    if (discrepancy > 0) return Icons.trending_up;
    return Icons.trending_down;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle del Turno')),
        body: const LoadingWidget(),
      );
    }

    if (_shift == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle del Turno')),
        body: const ErrorDisplay(message: 'Turno no encontrado'),
      );
    }

    final shift = _shift!;

    final openingEntries =
        shift.balanceEntries.where((b) => b.type == 'OPENING').toList();
    final closingEntries =
        shift.balanceEntries.where((b) => b.type == 'CLOSING').toList();

    final totalOpeningBalance =
        openingEntries.fold<double>(0.0, (sum, b) => sum + b.amount);
    final totalOpening = shift.startingCash + totalOpeningBalance;

    final totalMovementsIn = shift.movements
        .where((m) => m.direction == 'IN')
        .fold<double>(0.0, (sum, m) => sum + m.amount);
    final totalMovementsOut = shift.movements
        .where((m) => m.direction == 'OUT')
        .fold<double>(0.0, (sum, m) => sum + m.amount);
    final netMovements = totalMovementsIn - totalMovementsOut;
    final totalExpected = totalOpening + netMovements;

    final totalClosingBalance =
        closingEntries.fold<double>(0.0, (sum, b) => sum + b.amount);
    final totalClosing = (shift.endingCash ?? 0) + totalClosingBalance;
    final discrepancy = totalClosing - totalExpected;

    final statusColor = _discrepancyColor(discrepancy);
    final bgColor =
        statusColor == Colors.green ? Colors.green[50]! : Colors.red[50]!;
    final textColor =
        statusColor == Colors.green ? Colors.green[800]! : Colors.red[800]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Turno'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // General info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('Operador', shift.operator?.fullName ?? '-'),
                  _row('Inicio', formatDate(shift.startedAt)),
                  if (shift.closedAt != null)
                    _row('Cierre', formatDate(shift.closedAt!)),
                  if (shift.sencillo > 0)
                    _row('Sencillo', formatCurrency(shift.sencillo),
                        color: Colors.orange),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Status banner (for closed and preclosed shifts)
          if (shift.isClosed || shift.isPreclosed) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor, width: 2),
              ),
              child: Column(
                children: [
                  Icon(_discrepancyIcon(discrepancy),
                      size: 56, color: statusColor),
                  const SizedBox(height: 8),
                  Text(
                    _discrepancyLabel(discrepancy),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Discrepancia: ${formatCurrency(discrepancy)}',
                    style: TextStyle(fontSize: 16, color: textColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Summary rows
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row('Total apertura', formatCurrency(totalOpening)),
                  if (shift.movements.isNotEmpty)
                    _row('Movimientos netos', formatCurrency(netMovements),
                        color: netMovements >= 0 ? Colors.green : Colors.red),
                  if (shift.isClosed || shift.isPreclosed) ...[
                    _row('Total esperado', formatCurrency(totalExpected),
                        bold: true),
                    _row('Total cierre', formatCurrency(totalClosing),
                        bold: true),
                    const Divider(),
                    _row('Discrepancia', formatCurrency(discrepancy),
                        bold: true, color: statusColor),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Navigable section cards
          _SectionCard(
            title: 'APERTURA',
            titleColor: Colors.blue[800]!,
            cardColor: Colors.blue[50]!,
            subtitle: formatCurrency(totalOpening),
            icon: Icons.play_circle_outline,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SectionDetailScreen(
                  title: 'Apertura',
                  color: Colors.blue,
                  cashLabel: 'Efectivo inicial',
                  cashAmount: shift.startingCash,
                  sencillo: shift.sencillo,
                  entries: openingEntries,
                  totalBalance: totalOpeningBalance,
                  totalGeneral: totalOpening,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          _SectionCard(
            title: 'MOVIMIENTOS (${shift.movements.length})',
            titleColor: Colors.purple[800]!,
            cardColor: Colors.purple[50]!,
            subtitle: formatCurrency(netMovements),
            icon: Icons.swap_vert,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MovementsSectionScreen(
                  movements: shift.movements,
                  netMovements: netMovements,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Commissions card
          if (shift.commissionEntries.isNotEmpty) ...[
            Card(
              color: Colors.teal[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long,
                            color: Colors.teal[800], size: 20),
                        const SizedBox(width: 8),
                        Text('COMISIONES',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[800],
                              fontSize: 13,
                            )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...shift.commissionEntries.map((c) => _row(
                          c.name,
                          formatCurrency(c.amount),
                        )),
                    const Divider(),
                    _row(
                      'Total comisiones',
                      formatCurrency(shift.commissionEntries
                          .fold<double>(0.0, (sum, c) => sum + c.amount)),
                      bold: true,
                      color: Colors.teal[800],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Discrepancy justification
          if (shift.discrepancyNote != null ||
              shift.discrepancyPhotoUrl != null) ...[
            Card(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.note_alt,
                            color: Colors.grey[700], size: 20),
                        const SizedBox(width: 8),
                        Text('JUSTIFICACION',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                              fontSize: 13,
                            )),
                      ],
                    ),
                    if (shift.discrepancyNote != null) ...[
                      const SizedBox(height: 8),
                      Text(shift.discrepancyNote!,
                          style: const TextStyle(fontSize: 14)),
                    ],
                    if (shift.discrepancyPhotoUrl != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => showPhotoPreview(
                            context, shift.discrepancyPhotoUrl!),
                        child: const Row(
                          children: [
                            Icon(Icons.photo, color: Colors.blue, size: 18),
                            SizedBox(width: 6),
                            Text('Ver evidencia',
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
            const SizedBox(height: 8),
          ],

          if (shift.isClosed || shift.isPreclosed)
            _SectionCard(
              title: 'CIERRE',
              titleColor: Colors.orange[800]!,
              cardColor: Colors.orange[50]!,
              subtitle: formatCurrency(totalClosing),
              icon: Icons.stop_circle_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SectionDetailScreen(
                    title: 'Cierre',
                    color: Colors.orange,
                    cashLabel: 'Efectivo final',
                    cashAmount: shift.endingCash ?? 0,
                    entries: closingEntries,
                    totalBalance: totalClosingBalance,
                    totalGeneral: totalClosing,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: TextStyle(
                  color: color ?? Colors.grey[700],
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                )),
          ),
          Text(value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: color,
              )),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Color titleColor;
  final Color cardColor;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SectionCard({
    required this.title,
    required this.titleColor,
    required this.cardColor,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: titleColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                      fontSize: 14,
                    )),
              ),
              Text(subtitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                    fontSize: 14,
                  )),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: titleColor),
            ],
          ),
        ),
      ),
    );
  }
}
