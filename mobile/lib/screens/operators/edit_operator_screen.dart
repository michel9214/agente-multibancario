import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/photo_picker.dart';

class EditOperatorScreen extends ConsumerStatefulWidget {
  final String operatorId;
  const EditOperatorScreen({super.key, required this.operatorId});

  @override
  ConsumerState<EditOperatorScreen> createState() =>
      _EditOperatorScreenState();
}

class _EditOperatorScreenState extends ConsumerState<EditOperatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _photoUrl;
  bool _loading = false;
  bool _loadingData = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await UserService().getOne(widget.operatorId);
      _nameController.text = user.fullName;
      _photoUrl = user.photoUrl;
    } catch (_) {}
    setState(() => _loadingData = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await UserService().update(
        widget.operatorId,
        fullName: _nameController.text.trim(),
        photoUrl: _photoUrl,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Operador actualizado'),
              backgroundColor: Colors.green),
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
    if (_loadingData) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar Operador')),
        body: const LoadingWidget(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Operador')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 32),
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
                    backgroundColor: const Color(0xFF059669).withOpacity(0.1),
                    backgroundImage:
                        _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                    child: _photoUrl == null
                        ? const Icon(Icons.camera_alt,
                            size: 32, color: Color(0xFF059669))
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Toca para cambiar foto',
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
                    : Text('Guardar Cambios',
                        style: GoogleFonts.dmSans(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
