import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/shift.dart';
import '../../models/balance_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/currency_formatter.dart';
import '../../widgets/photo_picker.dart';

const _extraCommissionConcepts = ['Depositos', 'Retiros', 'Recargas'];

class EndShiftScreen extends ConsumerStatefulWidget {
  const EndShiftScreen({super.key});

  @override
  ConsumerState<EndShiftScreen> createState() => _EndShiftScreenState();
}

class _EndShiftScreenState extends ConsumerState<EndShiftScreen> {
  int _step = 0;
  static const _totalSteps = 4;
  final _cashController = TextEditingController();
  final Map<String, TextEditingController> _balanceControllers = {};
  final Map<String, String?> _photoUrls = {};
  // Commission controllers: entityId -> controller, concept -> controller
  final Map<String, TextEditingController> _commissionControllers = {};
  bool _loading = false;

  @override
  void dispose() {
    _cashController.dispose();
    for (final c in _balanceControllers.values) {
      c.dispose();
    }
    for (final c in _commissionControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handlePickPhoto(String entityId) async {
    final url = await pickAndUploadPhoto(context);
    if (url != null) {
      setState(() => _photoUrls[entityId] = url);
    }
  }

  List<BalanceEntry> _getOpeningEntries(Shift shift) {
    return shift.balanceEntries.where((b) => b.type == 'OPENING').toList();
  }

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
    // Step 1 (commissions) - no validation needed, amounts are optional
    if (_step == 2) {
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

  List<Map<String, dynamic>> _buildCommissions(List<BalanceEntry> openingEntries) {
    final commissions = <Map<String, dynamic>>[];
    // Entity commissions
    for (final entry in openingEntries) {
      final text = _commissionControllers['entity_${entry.entityId}']?.text ?? '';
      final amount = double.tryParse(text) ?? 0;
      if (amount > 0) {
        commissions.add({
          'entityId': entry.entityId,
          'amount': amount,
        });
      }
    }
    // Extra concept commissions
    for (final concept in _extraCommissionConcepts) {
      final text = _commissionControllers['concept_$concept']?.text ?? '';
      final amount = double.tryParse(text) ?? 0;
      if (amount > 0) {
        commissions.add({
          'concept': concept,
          'amount': amount,
        });
      }
    }
    return commissions;
  }

  double _getTotalCommissions(List<BalanceEntry> openingEntries) {
    double total = 0;
    for (final entry in openingEntries) {
      final text = _commissionControllers['entity_${entry.entityId}']?.text ?? '';
      total += double.tryParse(text) ?? 0;
    }
    for (final concept in _extraCommissionConcepts) {
      final text = _commissionControllers['concept_$concept']?.text ?? '';
      total += double.tryParse(text) ?? 0;
    }
    return total;
  }

  Future<void> _preCloseShift(
      Shift shift, List<BalanceEntry> openingEntries) async {
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

      final commissions = _buildCommissions(openingEntries);

      await ref.read(activeShiftProvider.notifier).preCloseShift(
            shiftId: shift.id,
            endingCash: double.tryParse(_cashController.text) ?? 0,
            closingBalances: balances,
            commissions: commissions,
          );

      if (mounted) {
        context.go('/home');
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
        title: Text('Cerrar Turno - Paso ${_step + 1}/$_totalSteps'),
      ),
      body: shiftAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (shift) {
          if (shift == null) {
            return const Center(child: Text('No hay turno activo'));
          }

          final openingEntries = _getOpeningEntries(shift);

          for (final entry in openingEntries) {
            _balanceControllers.putIfAbsent(
                entry.entityId, () => TextEditingController());
            _commissionControllers.putIfAbsent(
                'entity_${entry.entityId}', () => TextEditingController());
          }
          for (final concept in _extraCommissionConcepts) {
            _commissionControllers.putIfAbsent(
                'concept_$concept', () => TextEditingController());
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: List.generate(_totalSteps, (i) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color:
                              i <= _step ? Colors.orange : Colors.grey[300],
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
                        ? _buildCommissionsStep(openingEntries)
                        : _step == 2
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
                                if (_step < _totalSteps - 1) {
                                  _tryNextStep(shift);
                                } else {
                                  _preCloseShift(shift, openingEntries);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _step == _totalSteps - 1
                              ? Colors.orange
                              : Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(_step == _totalSteps - 1
                                ? 'Pre-Cerrar Turno'
                                : 'Siguiente'),
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
        final hasPhoto = _photoUrls[entry.entityId] != null;
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
                      child: Icon(Icons.account_balance,
                          color: entityColor, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entityName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
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
                        border: !hasPhoto
                            ? Border.all(color: Colors.red, width: 2)
                            : null,
                      ),
                      child: IconButton(
                        onPressed: () =>
                            _handlePickPhoto(entry.entityId),
                        icon: Icon(
                          hasPhoto
                              ? Icons.check_circle
                              : Icons.camera_alt,
                          color: hasPhoto ? Colors.green : Colors.red,
                        ),
                        tooltip: 'Foto obligatoria',
                      ),
                    ),
                    if (hasPhoto)
                      IconButton(
                        onPressed: () => showPhotoPreview(
                            context, _photoUrls[entry.entityId]!),
                        icon: const Icon(Icons.visibility,
                            color: Colors.blue, size: 20),
                        tooltip: 'Ver foto',
                      ),
                  ],
                ),
                if (!hasPhoto)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Foto del comprobante obligatoria',
                      style:
                          TextStyle(color: Colors.red[700], fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommissionsStep(List<BalanceEntry> openingEntries) {
    final items = <Widget>[
      Text('Comisiones Cobradas',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(
        'Ingresa el monto cobrado por comisiones (max 999.99). Deja en blanco si no aplica.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.teal[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.teal[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.teal[700], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Las comisiones se suman al total esperado del cierre.',
                style: TextStyle(fontSize: 12, color: Colors.teal[800]),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text('Por entidad',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey[700],
          )),
      const SizedBox(height: 8),
    ];

    // Entity commissions
    for (final entry in openingEntries) {
      final entityName = entry.entity?.name ?? 'Entidad';
      final entityColor = entry.entity?.color != null
          ? _parseColor(entry.entity!.color)
          : Colors.blue;
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: entityColor.withOpacity(0.2),
                radius: 14,
                child: Icon(Icons.account_balance,
                    color: entityColor, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(entityName, style: const TextStyle(fontSize: 14)),
              ),
              SizedBox(
                width: 110,
                child: TextFormField(
                  controller: _commissionControllers['entity_${entry.entityId}'],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    DecimalInputFormatter(),
                  ],
                  decoration: const InputDecoration(
                    prefixText: 'S/ ',
                    hintText: '0.00',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Extra concepts
    items.addAll([
      const SizedBox(height: 12),
      Text('Por concepto',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey[700],
          )),
      const SizedBox(height: 8),
    ]);

    for (final concept in _extraCommissionConcepts) {
      final icon = concept == 'Depositos'
          ? Icons.savings
          : concept == 'Retiros'
              ? Icons.atm
              : Icons.phone_android;
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.teal[50],
                radius: 14,
                child: Icon(icon, color: Colors.teal, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(concept, style: const TextStyle(fontSize: 14)),
              ),
              SizedBox(
                width: 110,
                child: TextFormField(
                  controller: _commissionControllers['concept_$concept'],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    DecimalInputFormatter(),
                  ],
                  decoration: const InputDecoration(
                    prefixText: 'S/ ',
                    hintText: '0.00',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Total
    final totalComm = _getTotalCommissions(openingEntries);
    items.addAll([
      const Divider(),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Total comisiones',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text(
            formatCurrency(totalComm),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: totalComm > 0 ? Colors.teal[700] : Colors.grey,
            ),
          ),
        ],
      ),
    ]);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: items,
    );
  }

  Widget _buildCashStep() {
    final shift = ref.read(activeShiftProvider).value;
    final sencillo = shift?.sencillo ?? 0;

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
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monto en soles *',
              prefixText: 'S/ ',
              hintText: '0.00',
            ),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          if (sencillo > 0) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sencillo a devolver',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          'Debes devolver ${formatCurrency(sencillo)} de sencillo recibido al inicio del turno.',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewStep(
      Shift shift, List<BalanceEntry> openingEntries) {
    final cash = double.tryParse(_cashController.text) ?? 0;

    double totalClosing = 0;
    final closingItems = <MapEntry<String, double>>[];
    for (final entry in openingEntries) {
      final amount = double.tryParse(
              _balanceControllers[entry.entityId]?.text ?? '') ??
          0;
      closingItems
          .add(MapEntry(entry.entity?.name ?? 'Entidad', amount));
      totalClosing += amount;
    }

    final totalOpening = openingEntries.fold<double>(
        0.0, (sum, b) => sum + b.amount);
    final totalOpeningGeneral = shift.startingCash + totalOpening;

    final movements = shift.movements;
    final totalMovementsIn = movements
        .where((m) => m.direction == 'IN')
        .fold<double>(0.0, (sum, m) => sum + m.amount);
    final totalMovementsOut = movements
        .where((m) => m.direction == 'OUT')
        .fold<double>(0.0, (sum, m) => sum + m.amount);
    final netMovements = totalMovementsIn - totalMovementsOut;

    final totalComm = _getTotalCommissions(openingEntries);
    final commissionItems = <MapEntry<String, double>>[];
    for (final entry in openingEntries) {
      final text = _commissionControllers['entity_${entry.entityId}']?.text ?? '';
      final amount = double.tryParse(text) ?? 0;
      if (amount > 0) {
        commissionItems.add(MapEntry(entry.entity?.name ?? 'Entidad', amount));
      }
    }
    for (final concept in _extraCommissionConcepts) {
      final text = _commissionControllers['concept_$concept']?.text ?? '';
      final amount = double.tryParse(text) ?? 0;
      if (amount > 0) {
        commissionItems.add(MapEntry(concept, amount));
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Vista Previa del Cierre',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
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
                _reviewRow('Efectivo inicial',
                    formatCurrency(shift.startingCash)),
                _reviewRow(
                    'Saldos entidades', formatCurrency(totalOpening)),
                const Divider(),
                _reviewRow('Total apertura',
                    formatCurrency(totalOpeningGeneral),
                    bold: true, color: Colors.blue[800]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
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
                                m.typeLabel +
                                    (m.description != null
                                        ? ' - ${m.description}'
                                        : ''),
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
                  _reviewRow('Movimientos netos',
                      formatCurrency(netMovements),
                      bold: true, color: Colors.purple[800]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (commissionItems.isNotEmpty) ...[
          Card(
            color: Colors.teal[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('COMISIONES',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[800],
                        fontSize: 13,
                      )),
                  const SizedBox(height: 8),
                  ...commissionItems.map((e) => _reviewRow(
                      e.key, formatCurrency(e.value))),
                  const Divider(),
                  _reviewRow('Total comisiones',
                      formatCurrency(totalComm),
                      bold: true, color: Colors.teal[800]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
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
                _reviewRow('Total apertura',
                    formatCurrency(totalOpeningGeneral)),
                if (movements.isNotEmpty)
                  _reviewRow('Movimientos netos',
                      formatCurrency(netMovements)),
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
                ...closingItems.map(
                    (e) => _reviewRow(e.key, formatCurrency(e.value))),
                const Divider(),
                _reviewRow(
                    'Total saldos cierre', formatCurrency(totalClosing),
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
        if (shift.sencillo > 0) ...[
          Card(
            color: Colors.amber[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.money, color: Colors.orange, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sencillo a devolver',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(formatCurrency(shift.sencillo),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
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
                  'Se realizará un pre-cierre. Podrás revisar y modificar los datos antes del cierre definitivo.',
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
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.normal,
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
