import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/banking_entity.dart';
import '../../providers/entities_provider.dart';
import '../../widgets/loading_widget.dart';

class EntitiesScreen extends ConsumerWidget {
  const EntitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entities = ref.watch(entitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Entidades Bancarias')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/entities/create'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
      body: entities.when(
        loading: () => const LoadingWidget(message: 'Cargando entidades...'),
        error: (e, _) => ErrorDisplay(
          message: 'Error al cargar entidades',
          onRetry: () => ref.read(entitiesProvider.notifier).load(),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.account_balance,
              title: 'Sin entidades',
              subtitle: 'Agrega entidades bancarias para comenzar',
            );
          }

          final active = list.where((e) => e.isActive).toList();
          final inactive = list.where((e) => !e.isActive).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.read(entitiesProvider.notifier).load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Activas (${active.length})',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (active.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No hay entidades activas',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ...active.map((e) => _buildEntityCard(context, ref, e)),
                if (inactive.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Inactivas (${inactive.length})',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...inactive.map((e) => _buildEntityCard(context, ref, e)),
                ],
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEntityCard(
      BuildContext context, WidgetRef ref, BankingEntity entity) {
    final color = _parseColor(entity.color);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: entity.isActive ? null : Colors.grey[100],
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(entity.isActive ? 0.2 : 0.1),
          child: Icon(
            _iconForType(entity.type),
            color: entity.isActive ? color : Colors.grey,
          ),
        ),
        title: Text(
          entity.name,
          style: TextStyle(
            color: entity.isActive ? null : Colors.grey,
            decoration: entity.isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(_typeLabel(entity.type)),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            switch (action) {
              case 'edit':
                context.push('/entities/${entity.id}/edit');
              case 'toggle':
                _toggleActive(context, ref, entity);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Editar'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: ListTile(
                leading: Icon(
                  entity.isActive ? Icons.toggle_off : Icons.toggle_on,
                  color: entity.isActive ? Colors.orange : Colors.green,
                ),
                title: Text(entity.isActive ? 'Desactivar' : 'Activar'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleActive(
      BuildContext context, WidgetRef ref, BankingEntity entity) {
    final newState = !entity.isActive;
    ref.read(entitiesProvider.notifier).update(
          id: entity.id,
          isActive: newState,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newState
            ? '${entity.name} activada'
            : '${entity.name} desactivada'),
        backgroundColor: newState ? Colors.green : Colors.orange,
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

  IconData _iconForType(String type) {
    switch (type) {
      case 'BANK':
        return Icons.account_balance;
      case 'INTERMEDIARY':
        return Icons.swap_horiz;
      case 'FINTECH':
        return Icons.phone_android;
      default:
        return Icons.business;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'BANK':
        return 'Banco';
      case 'INTERMEDIARY':
        return 'Intermediario';
      case 'FINTECH':
        return 'Fintech';
      default:
        return type;
    }
  }
}
