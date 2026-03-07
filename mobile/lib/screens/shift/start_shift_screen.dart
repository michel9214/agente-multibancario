import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/entities_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/currency_formatter.dart';
import '../../widgets/photo_picker.dart';
import '../../models/banking_entity.dart';

class StartShiftScreen extends ConsumerStatefulWidget {
  const StartShiftScreen({super.key});

  @override
  ConsumerState<StartShiftScreen> createState() => _StartShiftScreenState();
}

class _StartShiftScreenState extends ConsumerState<StartShiftScreen> {
  int _step = 0;
  final _cashController = TextEditingController();
  final Map<String, TextEditingController> _balanceControllers = {};
  final Map<String, String?> _photoUrls = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Force refresh active entities when entering the screen
    Future.microtask(() => ref.invalidate(activeEntitiesProvider));
  }

  @override
  void dispose() {
    _cashController.dispose();
    for (final c in _balanceControllers.values) {
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

  List<String> _getMissingPhotos(List<BankingEntity> entities) {
    final missing = <String>[];
    for (final entity in entities) {
      final amount =
          double.tryParse(_balanceControllers[entity.id]?.text ?? '') ?? 0;
      if (amount > 0 && _photoUrls[entity.id] == null) {
        missing.add(entity.name);
      }
    }
    return missing;
  }

  void _tryNextStep(List<BankingEntity> entities) {
    if (_step == 1) {
      // Validate photos for entities with balance > 0
      final missingPhotos = _getMissingPhotos(entities);
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
    setState(() => _step++);
  }

  Future<void> _openShift(List<BankingEntity> entities) async {
    setState(() => _loading = true);
    try {
      final balances = <Map<String, dynamic>>[];
      for (final entity in entities) {
        final controller = _balanceControllers[entity.id];
        final amount = double.tryParse(controller?.text ?? '') ?? 0;
        if (amount > 0) {
          balances.add({
            'entityId': entity.id,
            'amount': amount,
            if (_photoUrls[entity.id] != null)
              'receiptPhotoUrl': _photoUrls[entity.id],
          });
        }
      }

      await ref.read(activeShiftProvider.notifier).openShift(
            startingCash: double.tryParse(_cashController.text) ?? 0,
            openingBalances: balances,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turno iniciado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
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
    final entitiesAsync = ref.watch(activeEntitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Iniciar Turno - Paso ${_step + 1}/3'),
      ),
      body: entitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entities) {
          for (final e in entities) {
            _balanceControllers.putIfAbsent(e.id, () => TextEditingController());
          }

          return Column(
            children: [
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
                              ? Theme.of(context).colorScheme.primary
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
                    ? _buildCashStep()
                    : _step == 1
                        ? _buildBalancesStep(entities)
                        : _buildReviewStep(entities),
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
                                  _tryNextStep(entities);
                                } else {
                                  _openShift(entities);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _step == 2
                              ? Colors.green
                              : Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(_step == 2
                                ? 'Confirmar e Iniciar'
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

  Widget _buildCashStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Efectivo Inicial',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Ingresa el monto de efectivo con el que inicias el turno'),
          const SizedBox(height: 24),
          TextFormField(
            controller: _cashController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monto en soles',
              prefixText: 'S/ ',
              hintText: '0.00',
            ),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBalancesStep(List<BankingEntity> entities) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entities.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Saldos de Apertura',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Ingresa el saldo de cada entidad bancaria'),
              const SizedBox(height: 16),
            ],
          );
        }
        final entity = entities[i - 1];
        final color = _parseColor(entity.color);
        final hasPhoto = _photoUrls[entity.id] != null;
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
                      backgroundColor: color.withOpacity(0.2),
                      radius: 16,
                      child: Icon(Icons.account_balance,
                          color: color, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(entity.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _balanceControllers[entity.id],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Saldo',
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
                        onPressed: () => _handlePickPhoto(entity.id),
                        icon: Icon(
                          hasPhoto ? Icons.check_circle : Icons.camera_alt,
                          color: hasPhoto ? Colors.green : Colors.red,
                        ),
                        tooltip: 'Foto obligatoria',
                      ),
                    ),
                    if (hasPhoto)
                      IconButton(
                        onPressed: () => showPhotoPreview(
                            context, _photoUrls[entity.id]!),
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

  Widget _buildReviewStep(List<BankingEntity> entities) {
    final cash = double.tryParse(_cashController.text) ?? 0;
    double totalBalances = 0;
    final balanceItems = <MapEntry<String, double>>[];

    for (final entity in entities) {
      final amount =
          double.tryParse(_balanceControllers[entity.id]?.text ?? '') ?? 0;
      if (amount > 0) {
        balanceItems.add(MapEntry(entity.name, amount));
        totalBalances += amount;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen de Apertura',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _reviewRow('Efectivo inicial', formatCurrency(cash)),
                  const Divider(),
                  ...balanceItems
                      .map((e) => _reviewRow(e.key, formatCurrency(e.value))),
                  if (balanceItems.isNotEmpty) const Divider(),
                  _reviewRow(
                      'Total saldos', formatCurrency(totalBalances),
                      bold: true),
                  const Divider(),
                  _reviewRow(
                    'TOTAL GENERAL',
                    formatCurrency(cash + totalBalances),
                    bold: true,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
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
