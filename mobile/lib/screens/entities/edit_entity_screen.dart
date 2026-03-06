import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/banking_entity.dart';
import '../../providers/entities_provider.dart';

class EditEntityScreen extends ConsumerStatefulWidget {
  final String entityId;
  const EditEntityScreen({super.key, required this.entityId});

  @override
  ConsumerState<EditEntityScreen> createState() => _EditEntityScreenState();
}

class _EditEntityScreenState extends ConsumerState<EditEntityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _type = 'BANK';
  String _color = '#1976D2';
  bool _loading = false;
  bool _initialized = false;

  final List<Map<String, String>> _colors = [
    {'value': '#003882', 'label': 'Azul oscuro'},
    {'value': '#1976D2', 'label': 'Azul'},
    {'value': '#00A94F', 'label': 'Verde'},
    {'value': '#EC111A', 'label': 'Rojo'},
    {'value': '#FF6B00', 'label': 'Naranja'},
    {'value': '#6B21A8', 'label': 'Morado'},
    {'value': '#00529B', 'label': 'Azul medio'},
    {'value': '#00C4B4', 'label': 'Turquesa'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _initFromEntity(BankingEntity entity) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = entity.name;
    _type = entity.type;
    _color = entity.color;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(entitiesProvider.notifier).update(
            id: widget.entityId,
            name: _nameController.text.trim(),
            type: _type,
            color: _color,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entidad actualizada'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
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
    final entitiesAsync = ref.watch(entitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Entidad')),
      body: entitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entities) {
          final entity = entities.where((e) => e.id == widget.entityId).firstOrNull;
          if (entity == null) {
            return const Center(child: Text('Entidad no encontrada'));
          }
          _initFromEntity(entity);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la entidad',
                      hintText: 'Ej: BCP, Interbank, Kasnet...',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Ingrese un nombre';
                      if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _type,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(value: 'BANK', child: Text('Banco')),
                      DropdownMenuItem(
                          value: 'INTERMEDIARY', child: Text('Intermediario')),
                      DropdownMenuItem(value: 'FINTECH', child: Text('Fintech')),
                    ],
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 16),
                  const Text('Color',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _colors.map((c) {
                      final color = Color(
                          int.parse(c['value']!.replaceFirst('#', '0xFF')));
                      final isSelected = _color == c['value'];
                      return GestureDetector(
                        onTap: () => setState(() => _color = c['value']!),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.black, width: 3)
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 20)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Guardar Cambios'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
