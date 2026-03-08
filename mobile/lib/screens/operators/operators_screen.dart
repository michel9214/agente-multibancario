import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../widgets/loading_widget.dart';

class OperatorsScreen extends ConsumerStatefulWidget {
  const OperatorsScreen({super.key});

  @override
  ConsumerState<OperatorsScreen> createState() => _OperatorsScreenState();
}

class _OperatorsScreenState extends ConsumerState<OperatorsScreen> {
  List<User> _operators = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await UserService().getAll();
      setState(() {
        _operators = users.where((u) => u.role == 'OPERATOR').toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(User op) async {
    try {
      await UserService().toggleActive(op.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Operadores')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/operators/create');
          _load();
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const LoadingWidget(message: 'Cargando operadores...')
          : _operators.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text('No hay operadores registrados'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _operators.length,
                    itemBuilder: (context, i) {
                      final op = _operators[i];
                      final isActive = op.isActive ?? true;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: isActive ? null : Colors.grey[100],
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: isActive
                                ? Colors.green[100]
                                : Colors.grey[300],
                            backgroundImage: op.photoUrl != null
                                ? NetworkImage(op.photoUrl!)
                                : null,
                            child: op.photoUrl == null
                                ? Text(
                                    op.fullName[0].toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isActive
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            op.fullName,
                            style: TextStyle(
                              color: isActive ? null : Colors.grey,
                            ),
                          ),
                          subtitle: Text(isActive ? 'Activo' : 'Inactivo',
                              style: TextStyle(
                                color: isActive ? Colors.green : Colors.red,
                                fontSize: 12,
                              )),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) async {
                              if (action == 'edit') {
                                await context
                                    .push('/operators/${op.id}/edit');
                                _load();
                              } else if (action == 'toggle') {
                                _toggleActive(op);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text('Editar'),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Row(children: [
                                  Icon(
                                    isActive
                                        ? Icons.person_off
                                        : Icons.person,
                                    size: 18,
                                    color: isActive
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(isActive
                                      ? 'Desactivar'
                                      : 'Activar'),
                                ]),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
