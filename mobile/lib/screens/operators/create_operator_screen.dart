import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../widgets/photo_picker.dart';

class CreateOperatorScreen extends ConsumerStatefulWidget {
  const CreateOperatorScreen({super.key});

  @override
  ConsumerState<CreateOperatorScreen> createState() =>
      _CreateOperatorScreenState();
}

class _CreateOperatorScreenState extends ConsumerState<CreateOperatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _photoUrl;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService().register(
        fullName: _nameController.text.trim(),
        photoUrl: _photoUrl,
        role: 'OPERATOR',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Operador creado'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Operador')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: () async {
                    final url = await pickAndUploadPhoto(context);
                    if (url != null) setState(() => _photoUrl = url);
                  },
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.green[100],
                    backgroundImage:
                        _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                    child: _photoUrl == null
                        ? const Icon(Icons.camera_alt,
                            size: 32, color: Colors.green)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Toca para agregar foto',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingrese el nombre';
                  if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Crear Operador',
                        style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
