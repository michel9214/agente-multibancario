import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
          if (auth.user?.isOwner == true)
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
                case 'operators':
                  context.push('/operators');
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
              if (auth.user?.isOwner == true)
                const PopupMenuItem(
                  value: 'operators',
                  child: ListTile(
                    leading: Icon(Icons.people),
                    title: Text('Operadores'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Cerrar Sesion',
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        (auth.user?.fullName ?? 'U')[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hola, ${auth.user?.fullName ?? 'Usuario'}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            auth.user?.role == 'OWNER'
                                ? 'Administrador'
                                : 'Operador',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Shift status
            activeShift.when(
              loading: () => Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text('Verificando turno...',
                          style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.access_time, size: 36, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            Text(
              'No tienes un turno abierto',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Inicia un turno para comenzar el cuadre de caja',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/shift/start'),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar Turno'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E9F6E),
                  foregroundColor: Colors.white,
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
      child: Column(
        children: [
          // Green status header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0E9F6E), Color(0xFF10B981)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'TURNO ACTIVO',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  formatDate(shift.startedAt),
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
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
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A56DB).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total apertura',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(
                            formatCurrency(shift.startingCash + openingTotal),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: const Color(0xFF1A56DB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 4),
                _infoRow(
                    'Movimientos', '${shift.movements.length} registrados'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/shift/active'),
                        icon: const Icon(Icons.visibility, size: 20),
                        label: const Text('Ver Turno'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/shift/end'),
                        icon: const Icon(Icons.stop_circle_outlined, size: 20),
                        label: const Text('Cerrar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500, fontSize: 14)),
        ],
      ),
    );
  }
}
