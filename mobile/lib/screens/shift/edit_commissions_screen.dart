import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/shift.dart';
import '../../models/balance_entry.dart';
import '../../providers/shift_provider.dart';
import '../../services/shift_service.dart';
import '../../widgets/currency_formatter.dart';

const _extraCommissionConcepts = ['Depositos', 'Retiros', 'Recargas'];

class EditCommissionsScreen extends ConsumerStatefulWidget {
  const EditCommissionsScreen({super.key});

  @override
  ConsumerState<EditCommissionsScreen> createState() =>
      _EditCommissionsScreenState();
}

class _EditCommissionsScreenState
    extends ConsumerState<EditCommissionsScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initFromShift(Shift shift) {
    if (_initialized) return;
    _initialized = true;

    // Initialize controllers for all opening entities
    final openingEntries =
        shift.balanceEntries.where((b) => b.type == 'OPENING').toList();
    for (final entry in openingEntries) {
      final key = 'entity_${entry.entityId}';
      _controllers.putIfAbsent(key, () => TextEditingController());
    }
    // Initialize controllers for extra concepts
    for (final concept in _extraCommissionConcepts) {
      final key = 'concept_$concept';
      _controllers.putIfAbsent(key, () => TextEditingController());
    }

    // Pre-fill from existing commissions
    for (final comm in shift.commissionEntries) {
      if (comm.entityId != null) {
        final key = 'entity_${comm.entityId}';
        if (_controllers.containsKey(key)) {
          _controllers[key]!.text =
              comm.amount > 0 ? _formatAmount(comm.amount) : '';
        }
      } else if (comm.concept != null) {
        final key = 'concept_${comm.concept}';
        if (_controllers.containsKey(key)) {
          _controllers[key]!.text =
              comm.amount > 0 ? _formatAmount(comm.amount) : '';
        }
      }
    }
  }

  double _getTotal() {
    double total = 0;
    for (final c in _controllers.values) {
      total += double.tryParse(c.text) ?? 0;
    }
    return total;
  }

  Future<void> _save(Shift shift) async {
    setState(() => _saving = true);
    try {
      final openingEntries =
          shift.balanceEntries.where((b) => b.type == 'OPENING').toList();
      final commissions = <Map<String, dynamic>>[];

      for (final entry in openingEntries) {
        final text = _controllers['entity_${entry.entityId}']?.text ?? '';
        final amount = double.tryParse(text) ?? 0;
        if (amount > 0) {
          commissions.add({
            'entityId': entry.entityId,
            'amount': amount,
          });
        }
      }

      for (final concept in _extraCommissionConcepts) {
        final text = _controllers['concept_$concept']?.text ?? '';
        final amount = double.tryParse(text) ?? 0;
        if (amount > 0) {
          commissions.add({
            'concept': concept,
            'amount': amount,
          });
        }
      }

      await ShiftService().updateCommissions(shift.id, commissions);
      ref.read(activeShiftProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comisiones actualizadas'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatAmount(double amount) {
    return amount % 1 == 0
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shiftAsync = ref.watch(activeShiftProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Comisiones')),
      body: shiftAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (shift) {
          if (shift == null) {
            return const Center(child: Text('No hay turno activo'));
          }

          _initFromShift(shift);

          final openingEntries = shift.balanceEntries
              .where((b) => b.type == 'OPENING')
              .toList();

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Comisiones Cobradas',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Ingresa el monto cobrado por comisiones (max 999.99). Deja en blanco si no aplica.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),

                    // Entity commissions
                    Text('Por entidad',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey[700],
                        )),
                    const SizedBox(height: 8),
                    ...openingEntries.map((entry) {
                      final entityName =
                          entry.entity?.name ?? 'Entidad';
                      final entityColor = entry.entity?.color != null
                          ? _parseColor(entry.entity!.color)
                          : Colors.blue;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  entityColor.withOpacity(0.2),
                              radius: 14,
                              child: Icon(Icons.account_balance,
                                  color: entityColor, size: 14),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(entityName,
                                  style:
                                      const TextStyle(fontSize: 14)),
                            ),
                            SizedBox(
                              width: 110,
                              child: TextFormField(
                                controller: _controllers[
                                    'entity_${entry.entityId}'],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  DecimalInputFormatter(),
                                ],
                                decoration: const InputDecoration(
                                  prefixText: 'S/ ',
                                  hintText: '0.00',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 12),
                    Text('Por concepto',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey[700],
                        )),
                    const SizedBox(height: 8),
                    ..._extraCommissionConcepts.map((concept) {
                      final icon = concept == 'Depositos'
                          ? Icons.savings
                          : concept == 'Retiros'
                              ? Icons.atm
                              : Icons.phone_android;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.teal[50],
                              radius: 14,
                              child: Icon(icon,
                                  color: Colors.teal, size: 14),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(concept,
                                  style:
                                      const TextStyle(fontSize: 14)),
                            ),
                            SizedBox(
                              width: 110,
                              child: TextFormField(
                                controller: _controllers[
                                    'concept_$concept'],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  DecimalInputFormatter(),
                                ],
                                decoration: const InputDecoration(
                                  prefixText: 'S/ ',
                                  hintText: '0.00',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total comisiones',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        Text(
                          formatCurrency(_getTotal()),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _getTotal() > 0
                                ? Colors.teal[700]
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : () => _save(shift),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Guardar Comisiones'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
