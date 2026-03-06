import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/movement_reason.dart';
import '../../providers/movement_reasons_provider.dart';
import '../../providers/shift_provider.dart';
import '../../services/movement_service.dart';
import '../../services/upload_service.dart';
import '../../widgets/loading_widget.dart';

class MovementFormScreen extends ConsumerStatefulWidget {
  final String shiftId;
  const MovementFormScreen({super.key, required this.shiftId});

  @override
  ConsumerState<MovementFormScreen> createState() => _MovementFormScreenState();
}

class _MovementFormScreenState extends ConsumerState<MovementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  MovementReason? _selectedReason;
  String _direction = 'IN';
  String? _photoUrl;
  bool _loading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (image == null) return;

    try {
      final url = await UploadService().uploadReceipt(File(image.path));
      setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al subir foto')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione una razón de movimiento'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _loading = true);

    try {
      await MovementService().create(
        shiftId: widget.shiftId,
        type: 'OTHER',
        reasonId: _selectedReason!.id,
        direction: _direction,
        amount: double.parse(_amountController.text),
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        receiptPhotoUrl: _photoUrl,
      );

      ref.read(activeShiftProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Movimiento registrado'),
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
    final reasonsAsync = ref.watch(movementReasonsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Movimiento')),
      body: reasonsAsync.when(
        loading: () => const LoadingWidget(message: 'Cargando razones...'),
        error: (e, _) => ErrorDisplay(
          message: 'Error al cargar razones',
          onRetry: () => ref.read(movementReasonsProvider.notifier).load(activeOnly: true),
        ),
        data: (reasons) {
          final activeReasons = reasons.where((r) => r.isActive).toList();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<MovementReason>(
                    value: _selectedReason,
                    decoration: const InputDecoration(
                        labelText: 'Razón del movimiento'),
                    items: activeReasons
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Row(
                                children: [
                                  Icon(
                                    r.defaultDirection == 'IN'
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    size: 16,
                                    color: r.defaultDirection == 'IN'
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(r.name),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedReason = v;
                        if (v != null) {
                          _direction = v.defaultDirection;
                        }
                      });
                    },
                    validator: (v) =>
                        v == null ? 'Seleccione una razón' : null,
                  ),
                  const SizedBox(height: 16),

                  // Direction toggle
                  Row(
                    children: [
                      const Text('Dirección: '),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Entrada'),
                        selected: _direction == 'IN',
                        onSelected: (v) => setState(() => _direction = 'IN'),
                        selectedColor: Colors.green[200],
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Salida'),
                        selected: _direction == 'OUT',
                        onSelected: (v) => setState(() => _direction = 'OUT'),
                        selectedColor: Colors.red[200],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monto',
                      prefixText: 'S/ ',
                      hintText: '0.00',
                    ),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Ingrese un monto';
                      final amount = double.tryParse(v);
                      if (amount == null || amount <= 0) {
                        return 'Monto inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                      hintText: 'Ej: Dueño inyecta efectivo para BCP',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // Photo
                  OutlinedButton.icon(
                    onPressed: _pickPhoto,
                    icon: Icon(
                      _photoUrl != null
                          ? Icons.check_circle
                          : Icons.camera_alt,
                      color: _photoUrl != null ? Colors.green : null,
                    ),
                    label: Text(_photoUrl != null
                        ? 'Foto adjunta'
                        : 'Adjuntar foto (opcional)'),
                  ),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _direction == 'IN' ? Colors.green : Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            'Registrar ${_direction == "IN" ? "Entrada" : "Salida"}',
                            style: const TextStyle(fontSize: 16),
                          ),
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
