import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';

class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(isOnlineProvider);
    final pendingCount = ref.watch(pendingCountProvider);

    final isOffline = connectivity.when(
      data: (online) => !online,
      loading: () => false,
      error: (_, __) => false,
    );

    final pending = pendingCount.when(
      data: (count) => count,
      loading: () => 0,
      error: (_, __) => 0,
    );

    if (!isOffline && pending == 0) return const SizedBox.shrink();

    return Material(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: isOffline ? Colors.red[700] : Colors.orange[700],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Icon(
                isOffline ? Icons.cloud_off : Icons.sync,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOffline
                      ? 'Sin conexión - Los cambios se guardarán localmente'
                      : 'Sincronizando $pending operaciones pendientes...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (!isOffline && pending > 0)
                GestureDetector(
                  onTap: () => ref.read(syncServiceProvider).syncPendingOperations(),
                  child: const Icon(Icons.refresh, color: Colors.white, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
