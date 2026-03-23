import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/shift.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/currency_formatter.dart';
import '../../widgets/loading_widget.dart';

const _kSlate = Color(0xFF1E293B);
const _kMuted = Color(0xFF64748B);
const _kGreen = Color(0xFF059669);
const _kBlue = Color(0xFF2563EB);
const _kAmber = Color(0xFFD97706);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final activeShift = ref.watch(activeShiftProvider);
    final isOwner = auth.user?.isOwner == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(activeShiftProvider.notifier).refresh(),
        color: _kSlate,
        child: CustomScrollView(
          slivers: [
            // -- Dark header --
            SliverAppBar(
              expandedHeight: 150,
              pinned: true,
              backgroundColor: _kSlate,
              foregroundColor: Colors.white,
              actions: [
                if (isOwner)
                  IconButton(
                    icon: const Icon(Icons.history_rounded),
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
                    if (isOwner)
                      const PopupMenuItem(
                        value: 'entities',
                        child: ListTile(
                          leading: Icon(Icons.account_balance_rounded),
                          title: Text('Entidades'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (isOwner)
                      const PopupMenuItem(
                        value: 'reasons',
                        child: ListTile(
                          leading: Icon(Icons.category_rounded),
                          title: Text('Razones de Movimiento'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (isOwner)
                      const PopupMenuItem(
                        value: 'operators',
                        child: ListTile(
                          leading: Icon(Icons.people_rounded),
                          title: Text('Operadores'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: ListTile(
                        leading: Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
                        title: Text('Cerrar Sesion',
                            style: TextStyle(color: Color(0xFFDC2626))),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F172A), _kSlate],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                (auth.user?.fullName ?? 'U')[0].toUpperCase(),
                                style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Hola, ${auth.user?.fullName ?? 'Usuario'}',
                                  style: GoogleFonts.dmSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isOwner ? _kBlue : _kGreen)
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isOwner ? 'Administrador' : 'Operador',
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white60,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // -- Content --
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: activeShift.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: LoadingWidget(message: 'Verificando turno...'),
                  ),
                  error: (e, _) => ErrorDisplay(
                    message: 'Error al cargar turno',
                    onRetry: () =>
                        ref.read(activeShiftProvider.notifier).refresh(),
                  ),
                  data: (shift) {
                    if (shift == null) return _buildNoShiftCard(context);
                    return _buildActiveShiftCard(context, ref, shift);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoShiftCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.access_time_rounded,
                size: 32, color: _kMuted),
          ),
          const SizedBox(height: 20),
          Text(
            'No tienes un turno abierto',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: _kSlate,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Inicia un turno para comenzar el cuadre de caja',
            style: GoogleFonts.dmSans(color: _kMuted, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/shift/start'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('Iniciar Turno',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  )),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveShiftCard(
      BuildContext context, WidgetRef ref, Shift shift) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Status header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: shift.isPreclosed
                ? _kAmber.withOpacity(0.08)
                : _kGreen.withOpacity(0.08),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: shift.isPreclosed ? _kAmber : _kGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  shift.isPreclosed ? 'PRE-CERRADO' : 'TURNO ACTIVO',
                  style: GoogleFonts.dmSans(
                    color: shift.isPreclosed ? _kAmber : _kGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  formatDate(shift.startedAt),
                  style: GoogleFonts.dmSans(color: _kMuted, fontSize: 12),
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
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _kBlue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total apertura',
                              style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: _kSlate)),
                          Text(
                            formatCurrency(shift.startingCash + openingTotal),
                            style: GoogleFonts.dmMono(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: _kBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 4),
                _infoRow('Movimientos', '${shift.movements.length} registrados'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/shift/active'),
                        icon: Icon(
                          shift.isPreclosed
                              ? Icons.checklist_rounded
                              : Icons.visibility_rounded,
                          size: 20,
                        ),
                        label: Text(
                            shift.isPreclosed ? 'Revisar y Cerrar' : 'Ver Turno'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              shift.isPreclosed ? _kAmber : _kSlate,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    if (!shift.isPreclosed) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/shift/end'),
                          icon: const Icon(Icons.stop_circle_outlined,
                              size: 20),
                          label: const Text('Cerrar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kAmber,
                            side: const BorderSide(color: _kAmber),
                          ),
                        ),
                      ),
                    ],
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
          Text(label,
              style: GoogleFonts.dmSans(color: _kMuted, fontSize: 14)),
          Text(value,
              style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: _kSlate)),
        ],
      ),
    );
  }
}
