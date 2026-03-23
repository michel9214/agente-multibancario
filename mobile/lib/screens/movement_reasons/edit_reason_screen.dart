import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/movement_reasons_provider.dart';

class EditReasonScreen extends ConsumerStatefulWidget {
  final String reasonId;
  const EditReasonScreen({super.key, required this.reasonId});

  @override
  ConsumerState<EditReasonScreen> createState() => _EditReasonScreenState();
}

class _EditReasonScreenState extends ConsumerState<EditReasonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _direction = 'IN';
  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await ref.read(movementReasonsProvider.notifier).update(
            id: widget.reasonId,
            name: _nameController.text.trim(),
            defaultDirection: _direction,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Razón actualizada'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasons = ref.watch(movementReasonsProvider);

    return reasons.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Editar Razón')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (list) {
        final reason = list.where((r) => r.id == widget.reasonId).firstOrNull;
        if (reason == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Editar Razón')),
            body: const Center(child: Text('Razón no encontrada')),
          );
        }

        if (!_initialized) {
          _nameController.text = reason.name;
          _direction = reason.defaultDirection;
          _initialized = true;
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Editar Razón')),
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      hintText: 'Ej: Inyección de efectivo',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Ingrese un nombre';
                      }
                      if (v.trim().length < 2) {
                        return 'Mínimo 2 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Text('Dirección por defecto',
                      style:
                          GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_downward, size: 16),
                              SizedBox(width: 4),
                              Text('Entrada'),
                            ],
                          ),
                          selected: _direction == 'IN',
                          onSelected: (_) =>
                              setState(() => _direction = 'IN'),
                          selectedColor: const Color(0xFF059669).withOpacity(0.3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_upward, size: 16),
                              SizedBox(width: 4),
                              Text('Salida'),
                            ],
                          ),
                          selected: _direction == 'OUT',
                          onSelected: (_) =>
                              setState(() => _direction = 'OUT'),
                          selectedColor: const Color(0xFFDC2626).withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Guardar Cambios',
                            style: GoogleFonts.dmSans(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
