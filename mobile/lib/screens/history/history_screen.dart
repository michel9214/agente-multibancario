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

String _dayName(DateTime date) {
  const days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  return days[date.toLocal().weekday - 1];
}

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
    final allShiftsOrdered = <Shift>[];
    for (final entry in grouped.entries) {
      allShiftsOrdered.addAll(entry.value);
    }

    final widgets = <Widget>[];
    final groupKeys = grouped.keys.toList();

    for (var g = 0; g < groupKeys.length; g++) {
      final dateKey = groupKeys[g];
      final dayShifts = grouped[dateKey]!;

      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 6));

      // -- Cross-day bridge --
      // Groups are ordered most-recent-first. g-1 = newer day, g = older day.
      // Chronologically: older day's latest shift closes → newer day's earliest opens.
      // In display: newer day (.first=latest, .last=earliest) is at g-1.
      // The "opening" shift is the earliest of the newer day = grouped[g-1].last
      if (g > 0 && isOwner) {
        final newerDayShifts = grouped[groupKeys[g - 1]]!;
        final earliestOfNewerDay = newerDayShifts.last;
        final comp = _findComparisonForOpeningShift(earliestOfNewerDay.id);
        if (comp != null) {
          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _buildComparisonBridge(comp),
          ));
          widgets.add(const SizedBox(height: 6));
        }
      }

      // -- Day container --
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
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), _kSlate],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 13, color: Colors.white54),
                    const SizedBox(width: 8),
                    Text(
                      '$dateKey  ·  ${_dayName(dayShifts.first.startedAt)}',
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

              // Shifts + intra-day bridges only
              ...List.generate(dayShifts.length, (i) {
                final shift = dayShifts[i];
                final turnNum = turnNumbers[shift.id] ?? 1;
                final items = <Widget>[];

                items.add(_buildShiftTile(
                  context,
                  shift,
                  turnNumber: turnNum,
                  isLast: i == dayShifts.length - 1,
                  isEven: i.isEven,
                ));

                // Only show bridge INSIDE the day card if next shift is same day
                if (isOwner && i < dayShifts.length - 1) {
                  final comp = _findComparisonForOpeningShift(shift.id);
                  if (comp != null) {
                    items.add(_buildComparisonBridge(comp));
                  }
                }

                return Column(children: items);
              }),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  // ── Comparison bridge: visual connector between shifts ──
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
      icon = Icons.link_rounded;
    } else {
      color = diff > 0 ? _kBlue : _kRed;
      bg = diff > 0 ? _kBlueBg : _kRedBg;
      final prefix = diff > 0 ? '+' : '';
      label = 'Diferencia: $prefix${formatCurrency(diff)}';
      icon = Icons.link_off_rounded;
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
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            // Connector dots
            Column(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 1.5,
                  height: 8,
                  color: color.withOpacity(0.25),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  // ── Shift tile: discrepancy is the hero ──
  Widget _buildShiftTile(BuildContext context, Shift shift,
      {required int turnNumber, required bool isLast, bool isEven = true}) {
    final totalOpeningBalance = shift.totalOpeningBalance ?? 0.0;
    final totalOpening = shift.startingCash + totalOpeningBalance;
    final netMovements = shift.totalMovements ?? 0.0;
    final totalComm = shift.totalCommissions ?? 0.0;
    final totalPendingDel = shift.pendingDeliveries.fold<double>(0.0, (sum, pd) => sum + pd.amount);
    final totalExpected = totalOpening + netMovements + totalPendingDel;
    final totalClosingBalance = shift.totalClosingBalance ?? 0.0;
    final totalClosing = (shift.endingCash ?? 0.0) + totalClosingBalance;
    final discrepancy = totalClosing - totalExpected;

    final Color discColor;
    final Color discBg;
    final String discLabel;
    final IconData discIcon;

    if (shift.isOpen) {
      discColor = _kBlue;
      discBg = _kBlueBg;
      discLabel = 'Abierto';
      discIcon = Icons.access_time_rounded;
    } else if (shift.isPreclosed) {
      discColor = _kAmber;
      discBg = _kAmberBg;
      discLabel = 'Pre-cerrado';
      discIcon = Icons.pause_circle_rounded;
    } else if (discrepancy.abs() < 0.01) {
      discColor = _kGreen;
      discBg = _kGreenBg;
      discLabel = 'Cuadrado';
      discIcon = Icons.check_circle_rounded;
    } else if (discrepancy > 0) {
      discColor = _kGreen;
      discBg = _kGreenBg;
      discLabel = 'Sobrante';
      discIcon = Icons.trending_up_rounded;
    } else {
      discColor = _kRed;
      discBg = _kRedBg;
      discLabel = 'Faltante';
      discIcon = Icons.trending_down_rounded;
    }

    final timeLabel = _turnoLabel(shift.startedAt);

    // Subtle alternating tint so adjacent shifts feel distinct
    final tileBg = isEven ? Colors.white : const Color(0xFFF8FAFC);

    return Material(
      color: tileBg,
      child: InkWell(
        onTap: () => context.push('/history/${shift.id}'),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: discColor.withOpacity(0.5),
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: Identity ──
              Row(
                children: [
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
                        Text(
                          shift.operator?.fullName ?? 'Operador',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: _kSlate,
                          ),
                          overflow: TextOverflow.ellipsis,
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
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _kSlate,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                timeLabel,
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
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
                      ),
                    ),
                  ),
                ],
              ),

              // ── Row 2: Discrepancy hero (closed/preclosed only) ──
              if (shift.isClosed || shift.isPreclosed) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: discColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(discIcon, size: 28, color: discColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Discrepancia',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: discColor.withOpacity(0.7),
                              ),
                            ),
                            Text(
                              formatCurrency(discrepancy),
                              style: GoogleFonts.dmMono(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: discColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Row 3+4: Movimientos & Comisiones stacked ──
                if (netMovements.abs() >= 0.01 || totalComm > 0) ...[
                  const SizedBox(height: 8),
                  if (netMovements.abs() >= 0.01)
                    _detailRow(
                      'Movimientos',
                      formatCurrency(netMovements),
                      netMovements >= 0 ? _kGreen : _kRed,
                    ),
                  if (totalComm > 0)
                    _detailRow(
                      'Comisiones',
                      formatCurrency(totalComm),
                      _kTeal,
                    ),
                ],
              ] else ...[
                // Open shift
                const SizedBox(height: 8),
                _detailRow(
                  'Apertura',
                  formatCurrency(totalOpening),
                  _kBlue,
                ),
                if (netMovements.abs() >= 0.01)
                  _detailRow(
                    'Movimientos',
                    formatCurrency(netMovements),
                    netMovements >= 0 ? _kGreen : _kRed,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: _kMuted,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.dmMono(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
