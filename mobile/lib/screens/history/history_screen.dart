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

const _kSlate = Color(0xFF1E293B);
const _kSlateLight = Color(0xFF334155);
const _kMuted = Color(0xFF64748B);
const _kGreen = Color(0xFF059669);
const _kGreenBg = Color(0xFFECFDF5);
const _kRed = Color(0xFFDC2626);
const _kRedBg = Color(0xFFFEF2F2);
const _kBlue = Color(0xFF2563EB);
const _kBlueBg = Color(0xFFEFF6FF);
const _kTeal = Color(0xFF0D9488);
const _kAmber = Color(0xFFD97706);
const _kAmberBg = Color(0xFFFFFBEB);

String _turnoLabel(DateTime startedAt) {
  final hour = startedAt.toLocal().hour;
  if (hour < 12) return 'Mañana';
  if (hour < 18) return 'Tarde';
  return 'Noche';
}

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
      final shifts =
          (data['data'] as List).map((e) => Shift.fromJson(e)).toList();

      Map<String, ShiftComparison> compMap = {};
      final isOwner = ref.read(authProvider).user?.isOwner == true;
      if (isOwner) {
        try {
          final compData =
              await ShiftService().getShiftComparisons(page: 1, limit: 100);
          final comps = (compData['data'] as List)
              .map((e) => ShiftComparison.fromJson(e))
              .toList();
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Historial de Turnos')),
      body: _loading
          ? const LoadingWidget(message: 'Cargando historial...')
          : _error != null
              ? ErrorDisplay(
                  message: 'Error al cargar', onRetry: _loadShifts)
              : _shifts.isEmpty
                  ? const EmptyState(
                      icon: Icons.history_rounded,
                      title: 'Sin turnos registrados',
                      subtitle: 'Los turnos cerrados apareceran aqui',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadShifts,
                      color: _kSlate,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(16, 16, 16,
                            MediaQuery.of(context).padding.bottom + 32),
                        children: _buildGroupedList(),
                      ),
                    ),
    );
  }

  ShiftComparison? _findComparisonForOpeningShift(String shiftId) {
    for (final comp in _comparisons.values) {
      if (comp.openingShift.id == shiftId) return comp;
    }
    return null;
  }

  List<Widget> _buildGroupedList() {
    final grouped = <String, List<Shift>>{};
    for (final shift in _shifts) {
      final dateKey = formatDateShort(shift.startedAt);
      grouped.putIfAbsent(dateKey, () => []).add(shift);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    }

    final turnNumbers = <String, int>{};
    for (final entry in grouped.entries) {
      final count = entry.value.length;
      for (var i = 0; i < count; i++) {
        turnNumbers[entry.value[i].id] = count - i;
      }
    }

    final isOwner = ref.watch(authProvider).user?.isOwner == true;

    // Build flat list of all shifts in display order
    final allShiftsOrdered = <Shift>[];
    for (final entry in grouped.entries) {
      allShiftsOrdered.addAll(entry.value);
    }

    final widgets = <Widget>[];

    for (final entry in grouped.entries) {
      final dateKey = entry.key;
      final dayShifts = entry.value;

      // Spacing between day groups
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 16));

      // Day container
      widgets.add(
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Day header
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), _kSlate],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 14, color: Colors.white54),
                    const SizedBox(width: 8),
                    Text(
                      dateKey,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${dayShifts.length} turno${dayShifts.length > 1 ? 's' : ''}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: Colors.white60,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Shifts within this day
              ...List.generate(dayShifts.length, (i) {
                final shift = dayShifts[i];
                final turnNum = turnNumbers[shift.id] ?? 1;
                final globalIdx = allShiftsOrdered.indexOf(shift);

                final cardWidgets = <Widget>[];

                // Shift card content
                cardWidgets.add(_buildShiftTile(
                  context,
                  shift,
                  turnNumber: turnNum,
                  isLast: i == dayShifts.length - 1,
                ));

                // Comparison bridge (between this and next shift in global order)
                if (isOwner && globalIdx < allShiftsOrdered.length - 1) {
                  final comp =
                      _findComparisonForOpeningShift(shift.id);
                  if (comp != null) {
                    cardWidgets.add(_buildComparisonBridge(comp));
                  }
                }

                return Column(children: cardWidgets);
              }),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildComparisonBridge(ShiftComparison comp) {
    final diff = comp.totalDiff;
    final Color color;
    final Color bg;
    final String label;
    final IconData icon;

    if (diff.abs() < 0.01) {
      color = _kGreen;
      bg = _kGreenBg;
      label = 'Empalme correcto';
      icon = Icons.check_circle_rounded;
    } else {
      color = diff > 0 ? _kBlue : _kRed;
      bg = diff > 0 ? _kBlueBg : _kRedBg;
      final prefix = diff > 0 ? '+' : '';
      label = 'Diferencia: $prefix${formatCurrency(diff)}';
      icon = Icons.warning_amber_rounded;
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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            left: BorderSide(color: color, width: 3),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            Text(
              'Ver detalle',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color.withOpacity(0.6),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftTile(BuildContext context, Shift shift,
      {required int turnNumber, required bool isLast}) {
    final totalOpeningBalance = shift.totalOpeningBalance ?? 0.0;
    final totalOpening = shift.startingCash + totalOpeningBalance;
    final netMovements = shift.totalMovements ?? 0.0;
    final totalComm = shift.totalCommissions ?? 0.0;
    final totalExpected = totalOpening + netMovements;
    final totalClosingBalance = shift.totalClosingBalance ?? 0.0;
    final totalClosing = (shift.endingCash ?? 0.0) + totalClosingBalance;
    final discrepancy = totalClosing - totalExpected;

    final Color discColor;
    final Color discBg;
    final String discLabel;
    if (shift.isOpen) {
      discColor = _kBlue;
      discBg = _kBlueBg;
      discLabel = 'Abierto';
    } else if (shift.isPreclosed) {
      discColor = _kAmber;
      discBg = _kAmberBg;
      discLabel = 'Pre-cerrado';
    } else if (discrepancy.abs() < 0.01) {
      discColor = _kGreen;
      discBg = _kGreenBg;
      discLabel = 'Cuadrado';
    } else if (discrepancy > 0) {
      discColor = _kGreen;
      discBg = _kGreenBg;
      discLabel = 'Sobrante';
    } else {
      discColor = _kRed;
      discBg = _kRedBg;
      discLabel = 'Faltante';
    }

    final timeLabel = _turnoLabel(shift.startedAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/history/${shift.id}'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            border: !isLast
                ? Border(bottom: BorderSide(color: Colors.grey.shade100))
                : null,
          ),
          child: Column(
            children: [
              // Header: turn number + operator + status
              Row(
                children: [
                  // Turn badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _kSlate,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '$turnNumber',
                        style: GoogleFonts.dmMono(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                shift.operator?.fullName ?? 'Operador',
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: _kSlate,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              formatTime(shift.startedAt),
                              style: GoogleFonts.dmMono(
                                fontSize: 12,
                                color: _kMuted,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: _kSlate.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                timeLabel,
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _kMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: discBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      discLabel,
                      style: GoogleFonts.dmSans(
                        color: discColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),

              // Financial data
              if (shift.isClosed || shift.isPreclosed) ...[
                const SizedBox(height: 12),
                // Apertura vs Cierre
                Row(
                  children: [
                    Expanded(
                      child: _financialColumn(
                          'Apertura', totalOpening, _kBlue),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: Colors.grey.shade200,
                    ),
                    Expanded(
                      child: _financialColumn(
                          'Cierre', totalClosing, _kAmber),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Discrepancy
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: discColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            discrepancy.abs() < 0.01
                                ? Icons.check_circle_rounded
                                : discrepancy > 0
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_down_rounded,
                            size: 15,
                            color: discColor,
                          ),
                          const SizedBox(width: 6),
                          Text('Discrepancia',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: discColor,
                              )),
                        ],
                      ),
                      Text(
                        formatCurrency(discrepancy),
                        style: GoogleFonts.dmMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: discColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Movements & Commissions
                if (netMovements.abs() >= 0.01 || totalComm > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (netMovements.abs() >= 0.01)
                        _miniTag(
                          'Movimientos: ${formatCurrencyShort(netMovements)}',
                          netMovements >= 0 ? _kGreen : _kRed,
                        ),
                      if (netMovements.abs() >= 0.01 && totalComm > 0)
                        const SizedBox(width: 6),
                      if (totalComm > 0)
                        _miniTag(
                          'Comisiones: ${formatCurrencyShort(totalComm)}',
                          _kTeal,
                        ),
                    ],
                  ),
                ],
              ] else ...[
                const SizedBox(height: 8),
                _financialRow('Apertura', totalOpening),
                if (netMovements.abs() >= 0.01)
                  _financialRow('Movimientos', netMovements,
                      color: netMovements >= 0 ? _kGreen : _kRed),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _financialColumn(String label, double value, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: accent,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            formatCurrency(value),
            style: GoogleFonts.dmMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _kSlate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _financialRow(String label, double value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.dmSans(fontSize: 13, color: _kMuted)),
          Text(
            formatCurrency(value),
            style: GoogleFonts.dmMono(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color ?? _kSlate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTag(String text, Color color) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: GoogleFonts.dmMono(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
