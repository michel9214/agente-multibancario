import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
                      subtitle: 'Los turnos cerrados apareceran aqui',
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

    for (final list in grouped.values) {
      list.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    }

    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A56DB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calendar_today,
                    size: 14, color: Color(0xFF1A56DB)),
              ),
              const SizedBox(width: 10),
              Text(
                entry.key,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),
        ),
      );
      for (var i = 0; i < entry.value.length; i++) {
        widgets
            .add(_buildShiftCard(context, entry.value[i], turnNumber: i + 1));
      }
    }
    return widgets;
  }

  Widget _buildShiftCard(BuildContext context, Shift shift,
      {required int turnNumber}) {
    final totalOpeningBalance = shift.totalOpeningBalance ?? 0.0;
    final totalOpening = shift.startingCash + totalOpeningBalance;
    final netMovements = shift.totalMovements ?? 0.0;
    final totalExpected = totalOpening + netMovements;
    final totalClosingBalance = shift.totalClosingBalance ?? 0.0;
    final totalClosing = (shift.endingCash ?? 0.0) + totalClosingBalance;
    final discrepancy = totalClosing - totalExpected;

    final Color discColor;
    final String discLabel;
    if (discrepancy.abs() < 0.01) {
      discColor = const Color(0xFF0E9F6E);
      discLabel = 'Cuadrado';
    } else if (discrepancy > 0) {
      discColor = const Color(0xFF0E9F6E);
      discLabel = 'Sobrante';
    } else {
      discColor = const Color(0xFFE02424);
      discLabel = 'Faltante';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => context.push('/history/${shift.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (shift.isOpen ? const Color(0xFF1A56DB) : discColor)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      shift.isOpen ? 'Abierto' : discLabel,
                      style: GoogleFonts.poppins(
                        color: shift.isOpen ? const Color(0xFF1A56DB) : discColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatTime(shift.startedAt),
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Turno $turnNumber',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (shift.operator != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '- ${shift.operator!.fullName}',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              _cardRow('Apertura', formatCurrency(totalOpening)),
              if (netMovements.abs() >= 0.01)
                _cardRow('Movimientos', formatCurrency(netMovements),
                    valueColor:
                        netMovements >= 0 ? const Color(0xFF0E9F6E) : const Color(0xFFE02424)),
              if (shift.isClosed) ...[
                _cardRow('Esperado', formatCurrency(totalExpected)),
                _cardRow('Cierre', formatCurrency(totalClosing)),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: discColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Discrepancia',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: discColor,
                            )),
                        Text(
                          formatCurrency(discrepancy),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: discColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Text(value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor,
              )),
        ],
      ),
    );
  }
}
