import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/banking_entity.dart';
import '../services/entity_service.dart';
import '../services/sync_service.dart';

class EntitiesNotifier extends StateNotifier<AsyncValue<List<BankingEntity>>> {
  final EntityService _service = EntityService();
  final SyncService _syncService = SyncService();

  EntitiesNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({bool activeOnly = false}) async {
    state = const AsyncValue.loading();
    try {
      final entities = await _service.getAll(activeOnly: activeOnly);
      // Cache for offline use
      _syncService.cacheEntities(entities);
      state = AsyncValue.data(entities);
    } catch (e, st) {
      // Try offline cache
      try {
        final cached = await _syncService.getCachedEntities();
        if (cached.isNotEmpty) {
          state = AsyncValue.data(cached);
          return;
        }
      } catch (_) {}
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> create({
    required String name,
    String type = 'BANK',
    String color = '#1976D2',
  }) async {
    await _service.create(name: name, type: type, color: color);
    await load();
  }

  Future<void> update({
    required String id,
    String? name,
    String? type,
    String? color,
    bool? isActive,
  }) async {
    await _service.update(
      id: id,
      name: name,
      type: type,
      color: color,
      isActive: isActive,
    );
    await load();
  }

  Future<void> delete(String id) async {
    await _service.delete(id);
    await load();
  }
}

final entitiesProvider =
    StateNotifierProvider<EntitiesNotifier, AsyncValue<List<BankingEntity>>>(
        (ref) {
  return EntitiesNotifier();
});

final activeEntitiesProvider =
    FutureProvider<List<BankingEntity>>((ref) async {
  final service = EntityService();
  return service.getAll(activeOnly: true);
});
