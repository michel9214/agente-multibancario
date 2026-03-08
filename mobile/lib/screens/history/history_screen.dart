import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/shift.dart';
import '../../services/shift_service.dart';
import '../../widgets/currency_formatter.dart';
import '../../widgets/loading_widget.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<Shift> _shifts = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    setState(() => _loading = true);
    try {
      final data = await ShiftService().getShifts(page: _page);
      setState(() {
        _shifts = (data['data'] as List)
            .map((e) => Shift.fromJson(e))
            .toList();
        _total = data['total'];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Turnos')),
      body: _loading
          ? const LoadingWidget(message: 'Cargando historial...')
          : _error != null
              ? ErrorDisplay(message: 'Error al cargar', onRetry: _loadShifts)
              : _shifts.isEmpty
                  ? const EmptyState(
                      icon: Icons.history,
                      title: 'Sin turnos registrados',
                      subtitle: 'Los turnos cerrados aparecerán aquí',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadShifts,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: _buildGroupedList(),
                      ),
                    ),
    );
  }

  List<Widget> _buildGroupedList() {
    final grouped = <String, List<Shift>>{};
    for (final shift in _shifts) {
      final dateKey = formatDateShort(shift.startedAt);
      grouped.putIfAbsent(dateKey, () => []).add(shift);
    }

    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                entry.key,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Divider(color: Colors.grey[300])),
            ],
          ),
        ),
      );
      for (var i = 0; i < entry.value.length; i++) {
        widgets.add(_buildShiftCard(context, entry.value[i], turnNumber: i + 1));
      }
    }
    return widgets;
  }

  Widget _buildShiftCard(BuildContext context, Shift shift, {required int turnNumber}) {

    // Use pre-calculated fields from backend (history list doesn't include balanceEntries/movements)
    final totalOpeningBalance = shift.totalOpeningBalance ?? 0.0;
    final totalOpening = shift.startingCash + totalOpeningBalance;
    final netMovements = shift.totalMovements ?? 0.0;
    final totalExpected = totalOpening + netMovements;
    final totalClosingBalance = shift.totalClosingBalance ?? 0.0;
    final totalClosing = (shift.endingCash ?? 0.0) + totalClosingBalance;
    // Compute discrepancy from displayed values to guarantee visual consistency
    final discrepancy = totalClosing - totalExpected;

    // Color based on computed discrepancy
    final Color discColor;
    final String discLabel;
    if (discrepancy.abs() < 0.01) {
      discColor = Colors.green;
      discLabel = 'Cuadrado';
    } else if (discrepancy > 0) {
      discColor = Colors.green;
      discLabel = 'Sobrante';
    } else {
      discColor = Colors.red;
      discLabel = 'Faltante';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/history/${shift.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    shift.isOpen
                        ? Icons.access_time
                        : discrepancy.abs() < 0.01
                            ? Icons.check_circle
                            : discrepancy > 0
                                ? Icons.trending_up
                                : Icons.trending_down,
                    color: shift.isOpen ? Colors.blue : discColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (shift.isOpen ? Colors.blue : discColor).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      shift.isOpen ? 'Abierto' : discLabel,
                      style: TextStyle(
                        color: shift.isOpen ? Colors.blue : discColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatTime(shift.startedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Turno $turnNumber',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (shift.operator != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '— ${shift.operator!.fullName}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              _cardRow('Apertura', formatCurrency(totalOpening)),
              if (netMovements.abs() >= 0.01)
                _cardRow('Movimientos', formatCurrency(netMovements),
                    valueColor: netMovements >= 0 ? Colors.green : Colors.red),
              if (shift.isClosed) ...[
                _cardRow('Esperado', formatCurrency(totalExpected)),
                _cardRow('Cierre', formatCurrency(totalClosing)),
                const Divider(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Discrepancia:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: discColor,
                        )),
                    Text(
                      formatCurrency(discrepancy),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: discColor,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$label:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor,
            )),
      ],
    );
  }
}
