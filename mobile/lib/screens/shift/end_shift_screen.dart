import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/shift.dart';
import '../../models/balance_entry.dart';
import '../../providers/shift_provider.dart';
import '../../services/upload_service.dart';
import '../../widgets/currency_formatter.dart';
import '../../models/banking_entity.dart';

class EndShiftScreen extends ConsumerStatefulWidget {
  const EndShiftScreen({super.key});

  @override
  ConsumerState<EndShiftScreen> createState() => _EndShiftScreenState();
}

class _EndShiftScreenState extends ConsumerState<EndShiftScreen> {
  int _step = 0;
  final _cashController = TextEditingController();
  final Map<String, TextEditingController> _balanceControllers = {};
  final Map<String, String?> _photoUrls = {};
  bool _loading = false;

  @override
  void dispose() {
    _cashController.dispose();
    for (final c in _balanceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto(String entityId) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (image == null) return;

    try {
      final url = await UploadService().uploadReceipt(File(image.path));
      setState(() => _photoUrls[entityId] = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al subir foto')),
        );
      }
    }
  }

  /// Get opening entries from the active shift
  List<BalanceEntry> _getOpeningEntries(Shift shift) {
    return shift.balanceEntries.where((b) => b.type == 'OPENING').toList();
  }

  /// Validate that all opening entities have a closing balance entered
  List<String> _getMissingEntities(List<BalanceEntry> openingEntries) {
    final missing = <String>[];
    for (final entry in openingEntries) {
      final text = _balanceControllers[entry.entityId]?.text ?? '';
      final amount = double.tryParse(text);
      if (text.isEmpty || amount == null) {
        missing.add(entry.entity?.name ?? 'Entidad');
      }
    }
    return missing;
  }

  /// Get entities missing their closing photo
  List<String> _getMissingPhotos(List<BalanceEntry> openingEntries) {
    final missing = <String>[];
    for (final entry in openingEntries) {
      if (_photoUrls[entry.entityId] == null) {
        missing.add(entry.entity?.name ?? 'Entidad');
      }
    }
    return missing;
  }

  void _tryNextStep(Shift shift) {
    if (_step == 0) {
      // Validate all opening entities have closing balances
      final openingEntries = _getOpeningEntries(shift);
      final missing = _getMissingEntities(openingEntries);
      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falta ingresar saldo de: ${missing.join(", ")}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      // Validate all entities have photos
      final missingPhotos = _getMissingPhotos(openingEntries);
      if (missingPhotos.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falta foto de: ${missingPhotos.join(", ")}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }
    if (_step == 1) {
      final cash = double.tryParse(_cashController.text);
      if (_cashController.text.isEmpty || cash == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes ingresar el efectivo final'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    setState(() => _step++);
  }

  Future<void> _closeShift(Shift shift, List<BalanceEntry> openingEntries) async {
    setState(() => _loading = true);
    try {
      final balances = <Map<String, dynamic>>[];
      for (final entry in openingEntries) {
        final controller = _balanceControllers[entry.entityId];
        final amount = double.tryParse(controller?.text ?? '') ?? 0;
        balances.add({
          'entityId': entry.entityId,
          'amount': amount,
          if (_photoUrls[entry.entityId] != null)
            'receiptPhotoUrl': _photoUrls[entry.entityId],
        });
      }

      final closedShift = await ref.read(activeShiftProvider.notifier).closeShift(
            shiftId: shift.id,
            endingCash: double.tryParse(_cashController.text) ?? 0,
            closingBalances: balances,
          );

      if (mounted) {
        context.go('/shift/${closedShift.id}/summary');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shiftAsync = ref.watch(activeShiftProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Cerrar Turno - Paso ${_step + 1}/3'),
      ),
      body: shiftAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (shift) {
          if (shift == null) {
            return const Center(child: Text('No hay turno activo'));
          }

          final openingEntries = _getOpeningEntries(shift);

          // Initialize controllers for opening entities only
          for (final entry in openingEntries) {
            _balanceControllers.putIfAbsent(
                entry.entityId, () => TextEditingController());
          }

          return Column(
            children: [
              // Step indicator
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: List.generate(3, (i) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i <= _step
                              ? Colors.orange
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              Expanded(
                child: _step == 0
                    ? _buildBalancesStep(openingEntries)
                    : _step == 1
                        ? _buildCashStep()
                        : _buildPreviewStep(shift, openingEntries),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _step--),
                          child: const Text('Anterior'),
                        ),
                      ),
                    if (_step > 0) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loading
                            ? null
                            : () {
                                if (_step < 2) {
                                  _tryNextStep(shift);
                                } else {
                                  _closeShift(shift, openingEntries);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _step == 2 ? Colors.orange : Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(_step == 2 ? 'Cerrar Turno' : 'Siguiente'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBalancesStep(List<BalanceEntry> openingEntries) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: openingEntries.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Saldos de Cierre',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Ingresa el saldo final de las ${openingEntries.length} entidades que aperturaron',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
            ],
          );
        }
        final entry = openingEntries[i - 1];
        final entityName = entry.entity?.name ?? 'Entidad';
        final entityColor = entry.entity?.color != null
            ? _parseColor(entry.entity!.color)
            : Colors.blue;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: entityColor.withOpacity(0.2),
                      radius: 16,
                      child: Icon(Icons.account_balance, color: entityColor, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entityName,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            'Apertura: ${formatCurrency(entry.amount)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _balanceControllers[entry.entityId],
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Saldo de cierre *',
                          prefixText: 'S/ ',
                          hintText: '0.00',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: _photoUrls[entry.entityId] == null
                            ? Border.all(color: Colors.red, width: 2)
                            : null,
                      ),
                      child: IconButton(
                        onPressed: () => _pickPhoto(entry.entityId),
                        icon: Icon(
                          _photoUrls[entry.entityId] != null
                              ? Icons.check_circle
                              : Icons.camera_alt,
                          color: _photoUrls[entry.entityId] != null
                              ? Colors.green
                              : Colors.red,
                        ),
                        tooltip: 'Foto obligatoria',
                      ),
                    ),
                  ],
                ),
                if (_photoUrls[entry.entityId] == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Foto del comprobante obligatoria',
                      style: TextStyle(color: Colors.red[700], fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCashStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Efectivo Final',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Ingresa el monto de efectivo al final del turno'),
          const SizedBox(height: 24),
          TextFormField(
            controller: _cashController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monto en soles *',
              prefixText: 'S/ ',
              hintText: '0.00',
            ),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewStep(Shift shift, List<BalanceEntry> openingEntries) {
    final cash = double.tryParse(_cashController.text) ?? 0;

    // Closing balances
    double totalClosing = 0;
    final closingItems = <MapEntry<String, double>>[];
    for (final entry in openingEntries) {
      final amount =
          double.tryParse(_balanceControllers[entry.entityId]?.text ?? '') ?? 0;
      closingItems.add(MapEntry(entry.entity?.name ?? 'Entidad', amount));
      totalClosing += amount;
    }

    // Opening totals
    final totalOpening = openingEntries.fold<double>(
        0.0, (sum, b) => sum + b.amount);
    final totalOpeningGeneral = shift.startingCash + totalOpening;

    // Movements
    final movements = shift.movements;
    final totalMovementsIn = movements
        .where((m) => m.direction == 'IN')
        .fold<double>(0.0, (sum, m) => sum + m.amount);
    final totalMovementsOut = movements
        .where((m) => m.direction == 'OUT')
        .fold<double>(0.0, (sum, m) => sum + m.amount);
    final netMovements = totalMovementsIn - totalMovementsOut;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Vista Previa del Cierre',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),

        // Opening summary
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
                _reviewRow('Efectivo inicial', formatCurrency(shift.startingCash)),
                _reviewRow('Saldos entidades', formatCurrency(totalOpening)),
                const Divider(),
                _reviewRow('Total apertura', formatCurrency(totalOpeningGeneral),
                    bold: true, color: Colors.blue[800]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Movements summary
        if (movements.isNotEmpty) ...[
          Card(
            color: Colors.purple[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MOVIMIENTOS (${movements.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[800],
                        fontSize: 13,
                      )),
                  const SizedBox(height: 8),
                  ...movements.map((m) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Icon(
                              m.direction == 'IN'
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              size: 16,
                              color: m.direction == 'IN'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                m.typeLabel + (m.description != null ? ' - ${m.description}' : ''),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Text(
                              '${m.direction == 'IN' ? '+' : '-'} ${formatCurrency(m.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: m.direction == 'IN'
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      )),
                  const Divider(),
                  _reviewRow('Movimientos netos', formatCurrency(netMovements),
                      bold: true, color: Colors.purple[800]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Total esperado = apertura + movimientos netos
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
                _reviewRow('Total apertura', formatCurrency(totalOpeningGeneral)),
                if (movements.isNotEmpty)
                  _reviewRow('Movimientos netos', formatCurrency(netMovements)),
                const Divider(),
                _reviewRow(
                  'Debería tener',
                  formatCurrency(totalOpeningGeneral + netMovements),
                  bold: true,
                  color: Colors.green[800],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Closing balances
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
                _reviewRow('Efectivo final', formatCurrency(cash)),
                const Divider(),
                ...closingItems.map((e) => _reviewRow(e.key, formatCurrency(e.value))),
                const Divider(),
                _reviewRow('Total saldos cierre', formatCurrency(totalClosing),
                    bold: true),
                const Divider(),
                _reviewRow(
                  'TOTAL CIERRE',
                  formatCurrency(cash + totalClosing),
                  bold: true,
                  color: Colors.orange[800],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Al cerrar el turno se calculará el cuadre automáticamente. Esta acción no se puede deshacer.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    color: color)),
          ),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.blue;
    }
  }
}
