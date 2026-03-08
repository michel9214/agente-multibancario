import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/movement.dart';
import '../../models/movement_reason.dart';
import '../../providers/movement_reasons_provider.dart';
import '../../providers/shift_provider.dart';
import '../../services/movement_service.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/photo_picker.dart';

class MovementFormScreen extends ConsumerStatefulWidget {
  final String shiftId;
  final String? movementId;
  const MovementFormScreen({super.key, required this.shiftId, this.movementId});

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
  bool _loadingMovement = false;
  Movement? _editingMovement;

  bool get isEditing => widget.movementId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) _loadMovement();
  }

  Future<void> _loadMovement() async {
    setState(() => _loadingMovement = true);
    try {
      final movements =
          await MovementService().getByShift(widget.shiftId);
      final m = movements.firstWhere((m) => m.id == widget.movementId);
      _editingMovement = m;
      _amountController.text = m.amount.toStringAsFixed(2);
      _descriptionController.text = m.description ?? '';
      _direction = m.direction;
      _photoUrl = m.receiptPhotoUrl;
      if (m.reason != null) {
        _selectedReason = m.reason;
      }
    } catch (_) {}
    setState(() => _loadingMovement = false);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handlePickPhoto() async {
    final url = await pickAndUploadPhoto(context);
    if (url != null) {
      setState(() => _photoUrl = url);
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
      if (isEditing) {
        await MovementService().update(
          shiftId: widget.shiftId,
          movementId: widget.movementId!,
          type: 'OTHER',
          reasonId: _selectedReason!.id,
          direction: _direction,
          amount: double.parse(_amountController.text),
          description: _descriptionController.text.isNotEmpty
              ? _descriptionController.text
              : null,
          receiptPhotoUrl: _photoUrl,
        );
      } else {
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
      }

      ref.read(activeShiftProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(isEditing ? 'Movimiento actualizado' : 'Movimiento registrado'),
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

    if (_loadingMovement) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: const LoadingWidget(message: 'Cargando movimiento...'),
      );
    }

    return Scaffold(
      appBar: AppBar(
          title: Text(isEditing ? 'Editar Movimiento' : 'Registrar Movimiento')),
      body: reasonsAsync.when(
        loading: () => const LoadingWidget(message: 'Cargando razones...'),
        error: (e, _) => ErrorDisplay(
          message: 'Error al cargar razones',
          onRetry: () =>
              ref.read(movementReasonsProvider.notifier).load(activeOnly: true),
        ),
        data: (reasons) {
          final activeReasons = reasons.where((r) => r.isActive).toList();

          // Set selected reason for edit mode
          if (isEditing &&
              _selectedReason != null &&
              !activeReasons.any((r) => r.id == _selectedReason!.id)) {
            activeReasons.add(_selectedReason!);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<MovementReason>(
                    value: activeReasons.any((r) => r.id == _selectedReason?.id)
                        ? _selectedReason
                        : null,
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handlePickPhoto,
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
                      ),
                      if (_photoUrl != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () =>
                              showPhotoPreview(context, _photoUrl!),
                          icon: const Icon(Icons.visibility,
                              color: Colors.blue),
                          tooltip: 'Ver foto',
                        ),
                      ],
                    ],
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
                            isEditing
                                ? 'Guardar Cambios'
                                : 'Registrar ${_direction == "IN" ? "Entrada" : "Salida"}',
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
