import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/shift.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../services/shift_service.dart';
import '../../widgets/currency_formatter.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/photo_picker.dart';
import 'section_detail_screen.dart';

const _kSlate = Color(0xFF1E293B);
const _kSlateLight = Color(0xFF334155);
const _kMuted = Color(0xFF64748B);
const _kSurface = Color(0xFFF8FAFC);
const _kGreen = Color(0xFF059669);
const _kGreenBg = Color(0xFFECFDF5);
const _kRed = Color(0xFFDC2626);
const _kRedBg = Color(0xFFFEF2F2);
const _kBlue = Color(0xFF2563EB);
const _kAmber = Color(0xFFD97706);
const _kTeal = Color(0xFF0D9488);
const _kPurple = Color(0xFF7C3AED);

class ShiftDetailScreen extends ConsumerStatefulWidget {
  final String shiftId;
  const ShiftDetailScreen({super.key, required this.shiftId});

  @override
  ConsumerState<ShiftDetailScreen> createState() => _ShiftDetailScreenState();
}

class _ShiftDetailScreenState extends ConsumerState<ShiftDetailScreen> {
  Shift? _shift;
  bool _loading = true;
  bool _annulling = false;
  bool _isLastClosed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final shift = await ShiftService().getShift(widget.shiftId);

      // Check if this is the most recent closed shift
      bool isLast = false;
      if (shift.isClosed) {
        try {
          final data = await ShiftService().getShifts(page: 1, limit: 1);
          final shifts = (data['data'] as List)
              .map((e) => Shift.fromJson(e))
              .toList();
          // The first shift (most recent) — if it's this one, it's the last
          if (shifts.isNotEmpty && shifts.first.id == shift.id) {
            isLast = true;
          }
        } catch (_) {}
      }

      setState(() {
        _shift = shift;
        _isLastClosed = isLast;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Color _discColor(double d) {
    if (d.abs() < 0.01 || d > 0) return _kGreen;
    return _kRed;
  }

  Color _discBg(double d) {
    if (d.abs() < 0.01 || d > 0) return _kGreenBg;
    return _kRedBg;
  }

  String _discLabel(double d) {
    if (d.abs() < 0.01) return 'CUADRADO';
    if (d > 0) return 'SOBRANTE';
    return 'FALTANTE';
  }

  IconData _discIcon(double d) {
    if (d.abs() < 0.01) return Icons.check_circle_rounded;
    if (d > 0) return Icons.trending_up_rounded;
    return Icons.trending_down_rounded;
  }

  // ── Dialogs ──

  void _confirmAnnulShift() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular Turno'),
        content: const Text(
          'Se eliminara este turno y todos sus datos (saldos, movimientos, comisiones). '
          'Esta accion es irreversible.\n\n¿Continuar?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _annulShift();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _kRed, foregroundColor: Colors.white),
            child: const Text('Anular Turno'),
          ),
        ],
      ),
    );
  }

  Future<void> _annulShift() async {
    setState(() => _annulling = true);
    try {
      await ShiftService().annulShift(widget.shiftId);
      ref.read(activeShiftProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Turno anulado correctamente'),
            backgroundColor: _kGreen));
        context.go('/history');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _annulling = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _confirmAnnulClose() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular Cierre'),
        content: const Text(
          'El turno volvera a estado PRE-CERRADO. '
          'Podras editar saldos de cierre, comisiones y movimientos '
          'antes de cerrar definitivamente otra vez.\n\n¿Continuar?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _annulClose();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _kRed, foregroundColor: Colors.white),
            child: const Text('Anular Cierre'),
          ),
        ],
      ),
    );
  }

  Future<void> _annulClose() async {
    setState(() => _annulling = true);
    try {
      await ShiftService().annulClose(widget.shiftId);
      ref.read(activeShiftProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Cierre anulado. Turno en pre-cierre.'),
            backgroundColor: _kGreen));
        context.go('/shift/active');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _annulling = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(authProvider).user?.isOwner == true;

    if (_loading) {
      return Scaffold(
        backgroundColor: _kSurface,
        appBar: AppBar(title: const Text('Detalle del Turno')),
        body: const LoadingWidget(),
      );
    }

    if (_shift == null) {
      return Scaffold(
        backgroundColor: _kSurface,
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

    final dColor = _discColor(discrepancy);
    final dBg = _discBg(discrepancy);

    return Scaffold(
      backgroundColor: _kSurface,
      body: CustomScrollView(
        slivers: [
          // ── Header with discrepancy hero ──
          SliverAppBar(
            expandedHeight: (shift.isClosed || shift.isPreclosed) ? 230 : 160,
            pinned: true,
            backgroundColor: _kSlate,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F172A), _kSlate],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Operator + time
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.person_rounded,
                                  size: 18, color: Colors.white.withOpacity(0.7)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    shift.operator?.fullName ?? 'Operador',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '${formatDate(shift.startedAt)}${shift.closedAt != null ? '  →  ${formatTime(shift.closedAt!)}' : ''}',
                                    style: GoogleFonts.dmMono(
                                      fontSize: 11,
                                      color: Colors.white38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Discrepancy (closed/preclosed)
                        if (shift.isClosed || shift.isPreclosed) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: dColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _discLabel(discrepancy),
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: discrepancy.abs() < 0.01 || discrepancy > 0
                                    ? const Color(0xFF6EE7B7)
                                    : const Color(0xFFFCA5A5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatCurrency(discrepancy),
                            style: GoogleFonts.dmMono(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _kBlue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              shift.isPreclosed ? 'PRE-CERRADO' : 'ABIERTO',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF93C5FD),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Body ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 20, 16, MediaQuery.of(context).padding.bottom + 32),
              child: Column(
                children: [
                  // Summary card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _dataRow('Total apertura', formatCurrency(totalOpening)),
                        if (shift.movements.isNotEmpty)
                          _dataRow('Movimientos netos',
                              formatCurrency(netMovements),
                              valueColor:
                                  netMovements >= 0 ? _kGreen : _kRed),
                        if (shift.isClosed || shift.isPreclosed) ...[
                          _dataRow('Total esperado',
                              formatCurrency(totalExpected),
                              bold: true),
                          _dataRow(
                              'Total cierre', formatCurrency(totalClosing),
                              bold: true),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Divider(color: Colors.grey.shade200, height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Discrepancia',
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w700,
                                    color: dColor,
                                  )),
                              Text(formatCurrency(discrepancy),
                                  style: GoogleFonts.dmMono(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: dColor,
                                  )),
                            ],
                          ),
                        ],
                        if (shift.sencillo > 0) ...[
                          const SizedBox(height: 6),
                          _dataRow('Sencillo', formatCurrency(shift.sencillo),
                              valueColor: _kAmber),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section navigation cards
                  _navCard(
                    'APERTURA',
                    formatCurrency(totalOpening),
                    _kBlue,
                    Icons.login_rounded,
                    () => Navigator.push(
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
                                ))),
                  ),
                  const SizedBox(height: 8),

                  _navCard(
                    'MOVIMIENTOS (${shift.movements.length})',
                    formatCurrency(netMovements),
                    _kPurple,
                    Icons.swap_vert_rounded,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => MovementsSectionScreen(
                                  movements: shift.movements,
                                  netMovements: netMovements,
                                ))),
                  ),
                  const SizedBox(height: 8),

                  if (shift.isClosed || shift.isPreclosed) ...[
                    _navCard(
                      'CIERRE',
                      formatCurrency(totalClosing),
                      _kAmber,
                      Icons.logout_rounded,
                      () => Navigator.push(
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
                                  ))),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Commissions
                  if (shift.commissionEntries.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border(
                          left: BorderSide(color: _kTeal.withOpacity(0.5), width: 3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.receipt_long_rounded,
                                  color: _kTeal, size: 18),
                              const SizedBox(width: 8),
                              Text('COMISIONES',
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w700,
                                    color: _kTeal,
                                    fontSize: 12,
                                    letterSpacing: 0.8,
                                  )),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...shift.commissionEntries.map((c) => _dataRow(
                              c.name, formatCurrency(c.amount))),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Divider(
                                color: Colors.grey.shade200, height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total',
                                  style: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.w700,
                                      color: _kTeal)),
                              Text(
                                  formatCurrency(shift.commissionEntries
                                      .fold<double>(
                                          0.0, (s, c) => s + c.amount)),
                                  style: GoogleFonts.dmMono(
                                    fontWeight: FontWeight.w700,
                                    color: _kTeal,
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Justification
                  if (shift.discrepancyNote != null ||
                      shift.discrepancyPhotoUrl != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border(
                          left: BorderSide(
                              color: _kMuted.withOpacity(0.4), width: 3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.note_alt_rounded,
                                  color: _kMuted, size: 18),
                              const SizedBox(width: 8),
                              Text('JUSTIFICACION',
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w700,
                                    color: _kMuted,
                                    fontSize: 12,
                                    letterSpacing: 0.8,
                                  )),
                            ],
                          ),
                          if (shift.discrepancyNote != null) ...[
                            const SizedBox(height: 10),
                            Text(shift.discrepancyNote!,
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  color: _kSlateLight,
                                )),
                          ],
                          if (shift.discrepancyPhotoUrl != null) ...[
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () => showPhotoPreview(
                                  context, shift.discrepancyPhotoUrl!),
                              child: Row(
                                children: [
                                  const Icon(Icons.photo_rounded,
                                      color: _kBlue, size: 18),
                                  const SizedBox(width: 6),
                                  Text('Ver evidencia',
                                      style: GoogleFonts.dmSans(
                                        color: _kBlue,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ── Action buttons ──
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.home_rounded, size: 20),
                      label: Text('Volver al Inicio',
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kSlate,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),

                  // Annul open shift (OWNER + OPEN)
                  if (shift.isOpen && isOwner) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _annulling ? null : _confirmAnnulShift,
                        icon: _annulling
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.delete_forever_rounded),
                        label: const Text('Anular Turno'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kRed,
                          side: const BorderSide(color: _kRed),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],

                  // Annul close (OWNER + CLOSED + LAST CLOSED ONLY)
                  if (shift.isClosed && isOwner && _isLastClosed) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _annulling ? null : _confirmAnnulClose,
                        icon: _annulling
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.undo_rounded),
                        label: const Text('Anular Cierre'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kRed,
                          side: const BorderSide(color: _kRed),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataRow(String label, String value,
      {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: GoogleFonts.dmSans(
                  color: _kMuted,
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                )),
          ),
          Text(value,
              style: GoogleFonts.dmMono(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
                color: valueColor ?? _kSlate,
              )),
        ],
      ),
    );
  }

  Widget _navCard(String title, String subtitle, Color accent, IconData icon,
      VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(color: accent.withOpacity(0.5), width: 3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      color: accent,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    )),
              ),
              Text(subtitle,
                  style: GoogleFonts.dmMono(
                    fontWeight: FontWeight.w700,
                    color: _kSlate,
                    fontSize: 14,
                  )),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: accent.withOpacity(0.5), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _SectionCard kept for backward compat if used elsewhere ──
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
