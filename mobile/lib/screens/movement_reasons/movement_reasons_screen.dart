import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/movement_reason.dart';
import '../../providers/movement_reasons_provider.dart';
import '../../widgets/loading_widget.dart';

class MovementReasonsScreen extends ConsumerWidget {
  const MovementReasonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reasons = ref.watch(movementReasonsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Razones de Movimiento')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/movement-reasons/create'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
      body: reasons.when(
        loading: () =>
            const LoadingWidget(message: 'Cargando razones...'),
        error: (e, _) => ErrorDisplay(
          message: 'Error al cargar razones',
          onRetry: () => ref.read(movementReasonsProvider.notifier).load(),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.category,
              title: 'Sin razones',
              subtitle: 'Agrega razones de movimiento',
            );
          }

          final active = list.where((e) => e.isActive).toList();
          final inactive = list.where((e) => !e.isActive).toList();

          return RefreshIndicator(
            onRefresh: () async =>
                ref.read(movementReasonsProvider.notifier).load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Activas (${active.length})',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (active.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No hay razones activas',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ...active.map((r) => _buildReasonCard(context, ref, r)),
                if (inactive.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Inactivas (${inactive.length})',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...inactive.map((r) => _buildReasonCard(context, ref, r)),
                ],
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReasonCard(
      BuildContext context, WidgetRef ref, MovementReason reason) {
    final isIn = reason.defaultDirection == 'IN';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: reason.isActive ? null : Colors.grey[100],
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIn
              ? Colors.green.withOpacity(reason.isActive ? 0.2 : 0.1)
              : Colors.red.withOpacity(reason.isActive ? 0.2 : 0.1),
          child: Icon(
            isIn ? Icons.arrow_downward : Icons.arrow_upward,
            color: reason.isActive
                ? (isIn ? Colors.green : Colors.red)
                : Colors.grey,
          ),
        ),
        title: Text(
          reason.name,
          style: TextStyle(
            color: reason.isActive ? null : Colors.grey,
            decoration: reason.isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(isIn ? 'Entrada' : 'Salida'),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            switch (action) {
              case 'edit':
                context.push('/movement-reasons/${reason.id}/edit');
              case 'toggle':
                _toggleActive(context, ref, reason);
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
                  reason.isActive ? Icons.toggle_off : Icons.toggle_on,
                  color: reason.isActive ? Colors.orange : Colors.green,
                ),
                title: Text(reason.isActive ? 'Desactivar' : 'Activar'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleActive(
      BuildContext context, WidgetRef ref, MovementReason reason) {
    final newState = !reason.isActive;
    ref.read(movementReasonsProvider.notifier).update(
          id: reason.id,
          isActive: newState,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newState
            ? '${reason.name} activada'
            : '${reason.name} desactivada'),
        backgroundColor: newState ? Colors.green : Colors.orange,
      ),
    );
  }
}
