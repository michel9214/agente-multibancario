import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/shift.dart';
import '../../services/shift_service.dart';
import '../../widgets/currency_formatter.dart';
import '../../widgets/loading_widget.dart';

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

  Color _discrepancyColorFromValue(double discrepancy) {
    if (discrepancy >= 0) return Colors.green;
    return Colors.red;
  }

  String _discrepancyLabel(double discrepancy) {
    if (discrepancy == 0) return 'CUADRADO';
    if (discrepancy > 0) return 'SOBRANTE';
    return 'FALTANTE';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Turno'),
        actions: [
          if (shift.isClosed)
            IconButton(
              icon: const Icon(Icons.assessment),
              onPressed: () => context.push('/shift/${shift.id}/summary'),
              tooltip: 'Ver cuadre',
            ),
        ],
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
                  Text('Información General',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _row('Estado', shift.statusLabel),
                  _row('Operador', shift.operator?.fullName ?? '-'),
                  _row('Inicio', formatDate(shift.startedAt)),
                  if (shift.closedAt != null)
                    _row('Cierre', formatDate(shift.closedAt!)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

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
                  _row('Efectivo inicial', formatCurrency(shift.startingCash)),
                  ...openingEntries.map((b) => _row(
                        b.entity?.name ?? 'Entidad',
                        formatCurrency(b.amount),
                      )),
                  if (openingEntries.isNotEmpty) const Divider(),
                  _row('Total saldos', formatCurrency(totalOpeningBalance),
                      bold: true),
                  _row('Total apertura', formatCurrency(totalOpening),
                      bold: true, color: Colors.blue[800]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Movements
          if (shift.movements.isNotEmpty) ...[
            Card(
              color: Colors.purple[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MOVIMIENTOS (${shift.movements.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[800],
                          fontSize: 13,
                        )),
                    const SizedBox(height: 8),
                    ...shift.movements.map((m) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Icon(
                                m.isIncoming
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                size: 16,
                                color:
                                    m.isIncoming ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  m.typeLabel +
                                      (m.description != null
                                          ? ' - ${m.description}'
                                          : ''),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                '${m.isIncoming ? '+' : '-'} ${formatCurrency(m.amount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: m.isIncoming
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        )),
                    const Divider(),
                    _row('Movimientos netos', formatCurrency(netMovements),
                        bold: true, color: Colors.purple[800]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Total esperado
          if (shift.isClosed) ...[
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
                    _row('Total apertura', formatCurrency(totalOpening)),
                    if (shift.movements.isNotEmpty)
                      _row('Movimientos netos', formatCurrency(netMovements)),
                    const Divider(),
                    _row('Debería tener', formatCurrency(totalExpected),
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
                    _row('Efectivo final',
                        formatCurrency(shift.endingCash ?? 0)),
                    ...closingEntries.map((b) => _row(
                          b.entity?.name ?? 'Entidad',
                          formatCurrency(b.amount),
                        )),
                    if (closingEntries.isNotEmpty) const Divider(),
                    _row('Total saldos cierre',
                        formatCurrency(totalClosingBalance),
                        bold: true),
                    _row('Total cierre', formatCurrency(totalClosing),
                        bold: true, color: Colors.orange[800]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Discrepancy
            Card(
              color: _discrepancyColorFromValue(discrepancy) == Colors.green
                  ? Colors.green[50]
                  : Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _row('Total esperado', formatCurrency(totalExpected)),
                    _row('Total cierre', formatCurrency(totalClosing)),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('DISCREPANCIA',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _discrepancyColorFromValue(discrepancy),
                              )),
                          Text(
                            formatCurrency(discrepancy),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _discrepancyColorFromValue(discrepancy),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _discrepancyLabel(discrepancy),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _discrepancyColorFromValue(discrepancy),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
