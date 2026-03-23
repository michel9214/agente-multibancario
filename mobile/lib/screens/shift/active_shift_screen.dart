import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../services/movement_service.dart';
import '../../services/shift_service.dart';
import '../../models/reconciliation.dart';
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

class ActiveShiftScreen extends ConsumerStatefulWidget {
  const ActiveShiftScreen({super.key});

  @override
  ConsumerState<ActiveShiftScreen> createState() => _ActiveShiftScreenState();
}

class _ActiveShiftScreenState extends ConsumerState<ActiveShiftScreen> {
  Reconciliation? _reconciliation;
  bool _loadingRecon = false;

  @override
  Widget build(BuildContext context) {
    final shiftAsync = ref.watch(activeShiftProvider);
    final authState = ref.watch(authProvider);
    final isOwner = authState.user?.isOwner == true;
    final currentUserId = authState.user?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Turno Activo')),
      body: shiftAsync.when(
        loading: () => const LoadingWidget(message: 'Cargando turno...'),
        error: (e, _) => ErrorDisplay(
          message: 'Error al cargar turno',
          onRetry: () => ref.read(activeShiftProvider.notifier).refresh(),
        ),
        data: (shift) {
          if (shift == null) {
            return const EmptyState(
              icon: Icons.access_time,
              title: 'No hay turno activo',
            );
          }

          // Load reconciliation for PRECLOSED shifts
          if (shift.isPreclosed && _reconciliation == null && !_loadingRecon) {
            _loadingRecon = true;
            ShiftService().getReconciliation(shift.id).then((recon) {
              if (mounted) {
                setState(() {
                  _reconciliation = recon;
                  _loadingRecon = false;
                });
              }
            }).catchError((_) {
              if (mounted) setState(() => _loadingRecon = false);
            });
          }

          final openingEntries =
              shift.balanceEntries.where((b) => b.type == 'OPENING').toList();
          final closingEntries =
              shift.balanceEntries.where((b) => b.type == 'CLOSING').toList();

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _reconciliation = null;
                _loadingRecon = false;
              });
              ref.read(activeShiftProvider.notifier).refresh();
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 32),
              children: [
                // PRECLOSED banner
                if (shift.isPreclosed) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kAmber.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kAmber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _kAmber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.pause_circle_filled,
                              color: _kAmber, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TURNO PRE-CERRADO',
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w700,
                                    color: _kAmber,
                                    fontSize: 14,
                                    letterSpacing: 0.3,
                                  )),
                              const SizedBox(height: 2),
                              Text(
                                'Puedes modificar datos antes del cierre definitivo',
                                style: GoogleFonts.dmSans(
                                  color: _kMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Opening summary card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Resumen de Apertura',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _infoRow('Efectivo inicial',
                            formatCurrency(shift.startingCash)),
                        if (shift.sencillo > 0)
                          _infoRow(
                              'Sencillo', formatCurrency(shift.sencillo)),
                        _infoRow('Inicio', formatDate(shift.startedAt)),
                        const Divider(),
                        ...openingEntries.map((b) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                        b.entity?.name ?? 'Entidad',
                                        style: const TextStyle(
                                            color: Colors.grey)),
                                  ),
                                  Text(formatCurrency(b.amount),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  if (b.receiptPhotoUrl != null) ...[
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => showPhotoPreview(
                                          context, b.receiptPhotoUrl!),
                                      child: const Icon(Icons.visibility,
                                          color: Colors.blue, size: 20),
                                    ),
                                  ],
                                ],
                              ),
                            )),
                        if (openingEntries.isNotEmpty) ...[
                          const Divider(),
                          _infoRow(
                            'Total saldos entidades',
                            formatCurrency(openingEntries.fold<double>(
                                0.0, (sum, b) => sum + b.amount)),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('TOTAL APERTURA',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                Text(
                                  formatCurrency(shift.startingCash +
                                      openingEntries.fold<double>(
                                          0.0,
                                          (sum, b) => sum + b.amount)),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Movements section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Movimientos (${shift.movements.length})',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),

                if (shift.movements.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.swap_vert,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          const Text('Sin movimientos registrados'),
                          const SizedBox(height: 4),
                          Text(
                            'Los movimientos aparecerán aquí',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...shift.movements.map((m) {
                    final canEditDelete =
                        isOwner || m.createdById == currentUserId;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: m.direction == 'IN'
                              ? Colors.green[100]
                              : Colors.red[100],
                          child: Icon(
                            m.direction == 'IN'
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: m.direction == 'IN'
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        title: Text(m.typeLabel),
                        subtitle: m.description != null
                            ? Text(m.description!)
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${m.direction == 'IN' ? '+' : '-'} ${formatCurrency(m.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: m.direction == 'IN'
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            if (m.receiptPhotoUrl != null) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => showPhotoPreview(
                                    context, m.receiptPhotoUrl!),
                                child: const Icon(Icons.visibility,
                                    color: Colors.blue, size: 20),
                              ),
                            ],
                            if (canEditDelete) ...[
                              const SizedBox(width: 4),
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                iconSize: 20,
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    context.push(
                                        '/shift/${shift.id}/movement/${m.id}');
                                  } else if (action == 'delete') {
                                    _confirmDelete(
                                        context, shift.id, m.id);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(children: [
                                      Icon(Icons.edit, size: 18),
                                      SizedBox(width: 8),
                                      Text('Editar'),
                                    ]),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(children: [
                                      Icon(Icons.delete,
                                          size: 18,
                                          color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Eliminar',
                                          style: TextStyle(
                                              color: Colors.red)),
                                    ]),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/shift/${shift.id}/movement'),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar Movimiento'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                // PRECLOSED: show closing summary + actions
                if (shift.isPreclosed) ...[
                  const SizedBox(height: 20),
                  const Divider(thickness: 2),
                  const SizedBox(height: 12),

                  // Closing balances
                  Card(
                    color: _kAmber.withOpacity(0.05),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text('DATOS DE CIERRE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _kAmber,
                                    fontSize: 13,
                                  )),
                              TextButton.icon(
                                onPressed: () =>
                                    context.push('/shift/end'),
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Editar'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(60, 30),
                                ),
                              ),
                            ],
                          ),
                          _infoRow('Efectivo final',
                              formatCurrency(shift.endingCash ?? 0)),
                          ...closingEntries.map((b) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                          b.entity?.name ?? 'Entidad',
                                          style: const TextStyle(
                                              color: Colors.grey)),
                                    ),
                                    Text(formatCurrency(b.amount),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500)),
                                    if (b.receiptPhotoUrl != null) ...[
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => showPhotoPreview(
                                            context, b.receiptPhotoUrl!),
                                        child: const Icon(
                                            Icons.visibility,
                                            color: Colors.blue,
                                            size: 20),
                                      ),
                                    ],
                                  ],
                                ),
                              )),
                          if (closingEntries.isNotEmpty) ...[
                            const Divider(),
                            _infoRow(
                              'Total saldos cierre',
                              formatCurrency(closingEntries.fold<double>(
                                  0.0, (sum, b) => sum + b.amount)),
                            ),
                            _infoRow(
                              'TOTAL CIERRE',
                              formatCurrency((shift.endingCash ?? 0) +
                                  closingEntries.fold<double>(
                                      0.0, (sum, b) => sum + b.amount)),
                              bold: true,
                              color: _kAmber,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Commissions (always show with edit button)
                  Card(
                    color: _kTeal.withOpacity(0.05),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text('COMISIONES',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _kTeal,
                                    fontSize: 13,
                                  )),
                              TextButton.icon(
                                onPressed: () =>
                                    context.push('/shift/commissions'),
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Editar'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(60, 30),
                                  foregroundColor: _kTeal,
                                ),
                              ),
                            ],
                          ),
                          if (shift.commissionEntries.isEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Sin comisiones registradas',
                                style: TextStyle(
                                    color: _kMuted,
                                    fontSize: 13),
                              ),
                            )
                          else ...[
                            const SizedBox(height: 8),
                            ...shift.commissionEntries.map((c) =>
                                _infoRow(c.name,
                                    formatCurrency(c.amount))),
                            const Divider(),
                            _infoRow(
                              'Total comisiones',
                              formatCurrency(
                                  shift.commissionEntries
                                      .fold<double>(
                                          0.0,
                                          (sum, c) =>
                                              sum + c.amount)),
                              bold: true,
                              color: _kTeal,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Discrepancy preview
                  if (_reconciliation != null) ...[
                    _buildDiscrepancyPreview(_reconciliation!),
                  ] else if (_loadingRecon) ...[
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Reopen button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _reopenShift(shift.id),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reabrir Turno'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kBlue,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Final close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showFinalCloseDialog(context, shift.id),
                      icon: const Icon(Icons.lock),
                      label: const Text('Cerrar Turno Definitivamente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kRed,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ] else ...[
                  // OPEN state: show close button
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/shift/end'),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Cerrar Turno'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAmber,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiscrepancyPreview(Reconciliation r) {
    final discrepancy = r.totalClosing - r.totalExpected;
    final Color discColor;
    final String discLabel;
    if (discrepancy.abs() < 0.01) {
      discColor = Colors.green;
      discLabel = 'CUADRADO';
    } else if (discrepancy > 0) {
      discColor = Colors.green;
      discLabel = 'SOBRANTE';
    } else {
      discColor = Colors.red;
      discLabel = 'FALTANTE';
    }

    return Card(
      color: discColor.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              discrepancy.abs() < 0.01
                  ? Icons.check_circle
                  : discrepancy > 0
                      ? Icons.trending_up
                      : Icons.trending_down,
              size: 40,
              color: discColor,
            ),
            const SizedBox(height: 8),
            Text(
              discLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: discColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Discrepancia: ${formatCurrency(discrepancy)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: discColor,
              ),
            ),
            const SizedBox(height: 8),
            _infoRow('Esperado (apertura + mov.)',
                formatCurrency(r.totalExpected)),
            _infoRow('Cierre real', formatCurrency(r.totalClosing)),
          ],
        ),
      ),
    );
  }

  void _reopenShift(String shiftId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reabrir Turno'),
        content: const Text(
            'Se eliminaran los datos de cierre y el turno volvera a estado ABIERTO. ¿Continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(activeShiftProvider.notifier)
                    .reopenShift(shiftId);
                setState(() {
                  _reconciliation = null;
                  _loadingRecon = false;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Turno reabierto'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Reabrir',
                style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _showFinalCloseDialog(BuildContext context, String shiftId) {
    showDialog(
      context: context,
      builder: (ctx) => _FinalCloseDialog(
        shiftId: shiftId,
        onConfirm: (note, photoUrl) async {
          try {
            await ref
                .read(activeShiftProvider.notifier)
                .finalCloseShift(
                  shiftId: shiftId,
                  discrepancyNote: note,
                  discrepancyPhotoUrl: photoUrl,
                );
            if (mounted) {
              context.go('/history/$shiftId');
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, String shiftId, String movementId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: const Text(
            '¿Estas seguro de que deseas eliminar este movimiento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await MovementService().delete(movementId, shiftId);
                setState(() {
                  _reconciliation = null;
                  _loadingRecon = false;
                });
                ref.read(activeShiftProvider.notifier).refresh();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Movimiento eliminado'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: TextStyle(
                  color: color ?? Colors.grey,
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

/// Dialog for final close with optional discrepancy justification
class _FinalCloseDialog extends StatefulWidget {
  final String shiftId;
  final Future<void> Function(String? note, String? photoUrl) onConfirm;

  const _FinalCloseDialog({
    required this.shiftId,
    required this.onConfirm,
  });

  @override
  State<_FinalCloseDialog> createState() => _FinalCloseDialogState();
}

class _FinalCloseDialogState extends State<_FinalCloseDialog> {
  final _noteController = TextEditingController();
  String? _photoUrl;
  bool _closing = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cerrar Turno Definitivamente'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta accion es irreversible. El turno quedara cerrado permanentemente.',
              style: TextStyle(color: Colors.red, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text(
              'Justificacion de discrepancia (opcional):',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Describe por que hay diferencia...',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _closing
                      ? null
                      : () async {
                          final url = await pickAndUploadPhoto(context);
                          if (url != null) {
                            setState(() => _photoUrl = url);
                          }
                        },
                  icon: Icon(
                      _photoUrl != null ? Icons.check_circle : Icons.camera_alt,
                      size: 18),
                  label: Text(_photoUrl != null
                      ? 'Evidencia cargada'
                      : 'Agregar evidencia'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        _photoUrl != null ? Colors.green : null,
                  ),
                ),
                if (_photoUrl != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => showPhotoPreview(context, _photoUrl!),
                    child: const Icon(Icons.visibility,
                        color: Colors.blue, size: 20),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _closing ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _closing
              ? null
              : () async {
                  setState(() => _closing = true);
                  final note = _noteController.text.trim().isNotEmpty
                      ? _noteController.text.trim()
                      : null;
                  final photoUrl = _photoUrl;
                  final onConfirm = widget.onConfirm;
                  Navigator.pop(context);
                  await onConfirm(note, photoUrl);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _closing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Cerrar Definitivamente'),
        ),
      ],
    );
  }
}
