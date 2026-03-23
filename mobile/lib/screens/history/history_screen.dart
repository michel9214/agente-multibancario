import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/shift.dart';
import '../../models/shift_comparison.dart';
import '../../providers/auth_provider.dart';
import '../../services/shift_service.dart';
import '../../widgets/currency_formatter.dart';
import '../../widgets/loading_widget.dart';
import 'shift_comparisons_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<Shift> _shifts = [];
  Map<String, ShiftComparison> _comparisons = {};
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
      final shifts = (data['data'] as List)
          .map((e) => Shift.fromJson(e))
          .toList();

      // Load comparisons for OWNER
      Map<String, ShiftComparison> compMap = {};
      final isOwner = ref.read(authProvider).user?.isOwner == true;
      if (isOwner) {
        try {
          final compData = await ShiftService().getShiftComparisons(page: 1, limit: 100);
          final comps = (compData['data'] as List)
              .map((e) => ShiftComparison.fromJson(e))
              .toList();
          // Index by "closingShiftId_openingShiftId"
          for (final comp in comps) {
            compMap['${comp.closingShift.id}_${comp.openingShift.id}'] = comp;
          }
        } catch (_) {}
      }

      setState(() {
        _shifts = shifts;
        _comparisons = compMap;
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

  /// Find comparison where shift is the OPENING shift (i.e., comparison with previous shift)
  ShiftComparison? _findComparisonForOpeningShift(String shiftId) {
    for (final comp in _comparisons.values) {
      if (comp.openingShift.id == shiftId) return comp;
    }
    return null;
  }

  List<Widget> _buildGroupedList() {
    // Flatten all shifts in display order (most recent first)
    final allShiftsOrdered = <Shift>[];
    final grouped = <String, List<Shift>>{};
    for (final shift in _shifts) {
      final dateKey = formatDateShort(shift.startedAt);
      grouped.putIfAbsent(dateKey, () => []).add(shift);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    }

    // Build flat list in display order
    for (final entry in grouped.entries) {
      allShiftsOrdered.addAll(entry.value);
    }

    // Assign turn numbers per date (based on opening order)
    final turnNumbers = <String, int>{};
    for (final entry in grouped.entries) {
      final count = entry.value.length;
      for (var i = 0; i < count; i++) {
        turnNumbers[entry.value[i].id] = count - i;
      }
    }

    final isOwner = ref.watch(authProvider).user?.isOwner == true;
    final widgets = <Widget>[];
    String? lastDateKey;

    for (var idx = 0; idx < allShiftsOrdered.length; idx++) {
      final shift = allShiftsOrdered[idx];
      final dateKey = formatDateShort(shift.startedAt);

      // Date header
      if (dateKey != lastDateKey) {
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
                  dateKey,
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
        lastDateKey = dateKey;
      }

      // Shift card
      widgets.add(_buildShiftCard(
        context,
        shift,
        turnNumber: turnNumbers[shift.id] ?? 1,
      ));

      // Comparison link between this shift and the next one (if OWNER and both closed)
      if (isOwner && idx < allShiftsOrdered.length - 1) {
        final nextShift = allShiftsOrdered[idx + 1];
        // The current shift (higher in list = more recent) is the opening shift
        // The next shift (lower in list = older) is the closing shift
        final comp = _findComparisonForOpeningShift(shift.id);
        if (comp != null) {
          widgets.add(_buildComparisonLink(comp));
        }
      }
    }
    return widgets;
  }

  Widget _buildComparisonLink(ShiftComparison comp) {
    final diff = comp.totalDiff;
    final Color color;
    final String label;
    if (diff.abs() < 0.01) {
      color = const Color(0xFF0E9F6E);
      label = 'Sin diferencia';
    } else {
      color = diff > 0 ? const Color(0xFF1A56DB) : const Color(0xFFE02424);
      final prefix = diff > 0 ? '+' : '';
      label = 'Diferencia: $prefix${formatCurrency(diff)}';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShiftComparisonDetailScreen(comparison: comp),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.swap_vert, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: color),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftCard(BuildContext context, Shift shift,
      {required int turnNumber}) {
    final totalOpeningBalance = shift.totalOpeningBalance ?? 0.0;
    final totalOpening = shift.startingCash + totalOpeningBalance;
    final netMovements = shift.totalMovements ?? 0.0;
    final totalComm = shift.totalCommissions ?? 0.0;
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
                      color: (shift.isOpen
                              ? const Color(0xFF1A56DB)
                              : shift.isPreclosed
                                  ? Colors.amber
                                  : discColor)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      shift.isOpen
                          ? 'Abierto'
                          : shift.isPreclosed
                              ? 'Pre-cerrado'
                              : discLabel,
                      style: GoogleFonts.poppins(
                        color: shift.isOpen
                            ? const Color(0xFF1A56DB)
                            : shift.isPreclosed
                                ? Colors.amber[800]
                                : discColor,
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
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  if (shift.operator != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A56DB).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        shift.operator!.fullName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: const Color(0xFF1A56DB),
                        ),
                      ),
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
              if (shift.isClosed || shift.isPreclosed) ...[
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
                if (totalComm > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Comisiones',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0D9488),
                            )),
                        Text(
                          formatCurrency(totalComm),
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0D9488),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
