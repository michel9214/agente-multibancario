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
const _kMuted = Color(0xFF64748B);
const _kGreen = Color(0xFF059669);
const _kRed = Color(0xFFDC2626);
const _kBlue = Color(0xFF2563EB);
const _kAmber = Color(0xFFD97706);
const _kTeal = Color(0xFF0D9488);

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

  void _confirmAnnulShift() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular Turno'),
        content: const Text(
          'Se eliminara este turno y todos sus datos (saldos, movimientos, comisiones). '
          'Esta accion es irreversible.\n\n'
          '¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _annulShift();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turno anulado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/history');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _annulling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
          'antes de cerrar definitivamente otra vez.\n\n'
          '¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _annulClose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
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
      // Refresh active shift provider so home shows it
      ref.read(activeShiftProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cierre anulado. Turno en pre-cierre.'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to active shift screen
        context.go('/shift/active');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _annulling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isOwner = authState.user?.isOwner == true;

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
        statusColor == Colors.green ? _kGreen.withOpacity(0.05) : _kRed.withOpacity(0.05);
    final textColor =
        statusColor == Colors.green ? _kGreen : _kRed;

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
                        color:
                            netMovements >= 0 ? Colors.green : Colors.red),
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
            titleColor: _kBlue,
            cardColor: _kBlue.withOpacity(0.05),
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
            titleColor: Color(0xFF7C3AED),
            cardColor: Color(0xFF7C3AED).withOpacity(0.05),
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

          if (shift.isClosed || shift.isPreclosed)
            _SectionCard(
              title: 'CIERRE',
              titleColor: _kAmber,
              cardColor: _kAmber.withOpacity(0.05),
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
          const SizedBox(height: 8),

          // Commissions card
          if (shift.commissionEntries.isNotEmpty) ...[
            Card(
              color: _kTeal.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long,
                            color: _kTeal, size: 20),
                        const SizedBox(width: 8),
                        Text('COMISIONES',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _kTeal,
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
                      color: _kTeal,
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
                        Icon(Icons.note_alt,
                            color: _kMuted, size: 20),
                        const SizedBox(width: 8),
                        Text('JUSTIFICACION',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _kMuted,
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
                            Icon(Icons.photo,
                                color: Colors.blue, size: 18),
                            SizedBox(width: 6),
                            Text('Ver evidencia',
                                style: TextStyle(
                                    color: Colors.blue,
                                    decoration:
                                        TextDecoration.underline)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // Back to home button (always visible)
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.home),
              label: const Text('Volver al Inicio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // Annul open shift button (OWNER only, OPEN shifts only)
          if (shift.isOpen && isOwner) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _annulling ? null : _confirmAnnulShift,
                icon: _annulling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_forever),
                label: const Text('Anular Turno'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],

          // Annul close button (OWNER only, CLOSED shifts only)
          if (shift.isClosed && isOwner) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _annulling ? null : _confirmAnnulClose,
                icon: _annulling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.undo),
                label: const Text('Anular Cierre'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                  color: color ?? _kMuted,
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
