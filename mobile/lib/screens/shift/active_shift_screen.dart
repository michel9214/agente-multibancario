import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/currency_formatter.dart';
import '../../widgets/loading_widget.dart';

class ActiveShiftScreen extends ConsumerWidget {
  const ActiveShiftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftAsync = ref.watch(activeShiftProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Turno Activo')),
      floatingActionButton: shiftAsync.whenOrNull(
        data: (shift) => shift != null
            ? FloatingActionButton.extended(
                onPressed: () => context.push('/shift/${shift.id}/movement'),
                icon: const Icon(Icons.add),
                label: const Text('Movimiento'),
              )
            : null,
      ),
      body: shiftAsync.when(
        loading: () => const LoadingWidget(message: 'Cargando turno...'),
        error: (e, _) => ErrorDisplay(
          message: 'Error al cargar turno',
          onRetry: () => ref.read(activeShiftProvider.notifier).refresh(),
        ),
        data: (shift) {
          if (shift == null) {
            return const EmptyState(
              icon: Icons.access_time,
              title: 'No hay turno activo',
            );
          }

          final openingEntries =
              shift.balanceEntries.where((b) => b.type == 'OPENING').toList();

          return RefreshIndicator(
            onRefresh: () async =>
                ref.read(activeShiftProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Resumen de Apertura',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _infoRow('Efectivo inicial',
                            formatCurrency(shift.startingCash)),
                        _infoRow('Inicio', formatDate(shift.startedAt)),
                        const Divider(),
                        ...openingEntries.map((b) => _infoRow(
                              b.entity?.name ?? 'Entidad',
                              formatCurrency(b.amount),
                            )),
                        if (openingEntries.isNotEmpty) ...[
                          const Divider(),
                          _infoRow(
                            'Total saldos entidades',
                            formatCurrency(openingEntries.fold<double>(
                                0.0, (sum, b) => sum + b.amount)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('TOTAL APERTURA',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text(
                                  formatCurrency(shift.startingCash +
                                      openingEntries.fold<double>(
                                          0.0, (sum, b) => sum + b.amount)),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Movements section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Movimientos (${shift.movements.length})',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),

                if (shift.movements.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.swap_vert,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          const Text('Sin movimientos registrados'),
                          const SizedBox(height: 4),
                          Text(
                            'Los movimientos del dueño aparecerán aquí',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...shift.movements.map((m) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: m.direction == 'IN'
                                ? Colors.green[100]
                                : Colors.red[100],
                            child: Icon(
                              m.direction == 'IN'
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: m.direction == 'IN'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                          title: Text(m.typeLabel),
                          subtitle: m.description != null
                              ? Text(m.description!)
                              : null,
                          trailing: Text(
                            '${m.direction == 'IN' ? '+' : '-'} ${formatCurrency(m.amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: m.direction == 'IN'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ),
                      )),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/shift/end'),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Cerrar Turno'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
