import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/shift.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/currency_formatter.dart';
import '../../widgets/loading_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final activeShift = ref.watch(activeShiftProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agente Multibanco'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial',
            onPressed: () => context.push('/history'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'entities':
                  context.push('/entities');
                case 'reasons':
                  context.push('/movement-reasons');
                case 'logout':
                  ref.read(authProvider.notifier).logout();
                  context.go('/login');
              }
            },
            itemBuilder: (context) => [
              if (auth.user?.isOwner == true)
                const PopupMenuItem(
                  value: 'entities',
                  child: ListTile(
                    leading: Icon(Icons.account_balance),
                    title: Text('Entidades'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              if (auth.user?.isOwner == true)
                const PopupMenuItem(
                  value: 'reasons',
                  child: ListTile(
                    leading: Icon(Icons.category),
                    title: Text('Razones de Movimiento'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Cerrar Sesión',
                      style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(activeShiftProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            (auth.user?.fullName ?? 'U')[0].toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hola, ${auth.user?.fullName ?? 'Usuario'}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                auth.user?.role == 'OWNER'
                                    ? 'Dueño'
                                    : 'Operador',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Shift status
            activeShift.when(
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: LoadingWidget(message: 'Verificando turno...'),
                ),
              ),
              error: (e, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ErrorDisplay(
                    message: 'Error al cargar turno',
                    onRetry: () =>
                        ref.read(activeShiftProvider.notifier).refresh(),
                  ),
                ),
              ),
              data: (shift) {
                if (shift == null) {
                  return _buildNoShiftCard(context);
                }
                return _buildActiveShiftCard(context, ref, shift);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoShiftCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.access_time, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No tienes un turno abierto',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Inicia un turno para comenzar el cuadre de caja',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/shift/start'),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar Turno'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveShiftCard(
      BuildContext context, WidgetRef ref, Shift shift) {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'TURNO ACTIVO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  formatDate(shift.startedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _infoRow('Efectivo inicial', formatCurrency(shift.startingCash)),
            if (shift.sencillo > 0)
              _infoRow('Sencillo', formatCurrency(shift.sencillo)),
            _infoRow('Saldos de apertura',
                '${shift.balanceEntries.where((b) => b.type == "OPENING").length} entidades'),
            Builder(builder: (context) {
              final openingTotal = shift.balanceEntries
                  .where((b) => b.type == 'OPENING')
                  .fold<double>(0.0, (sum, b) => sum + b.amount);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total apertura',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      formatCurrency(shift.startingCash + openingTotal),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(),
            _infoRow('Movimientos', '${shift.movements.length} registrados'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/shift/active'),
                    icon: const Icon(Icons.visibility),
                    label: const Text('Ver Turno'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/shift/end'),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Cerrar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
