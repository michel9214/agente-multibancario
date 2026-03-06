import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';
import 'connectivity_service.dart';
import 'movement_service.dart';
import '../models/banking_entity.dart';

class SyncService {
  final AppDatabase _db = AppDatabase.instance;
  final MovementService _movementService = MovementService();
  bool _syncing = false;
  final _pendingCountController = StreamController<int>.broadcast();

  Stream<int> get pendingCountStream => _pendingCountController.stream;

  /// Cache entities locally for offline access
  Future<void> cacheEntities(List<BankingEntity> entities) async {
    await _db.cacheEntities(entities.map((e) => CachedEntitiesCompanion(
      id: Value(e.id),
      name: Value(e.name),
      type: Value(e.type),
      color: Value(e.color),
      isActive: Value(e.isActive),
    )).toList());
  }

  /// Get cached entities when offline
  Future<List<BankingEntity>> getCachedEntities() async {
    final cached = await _db.getCachedEntities();
    return cached.map((c) => BankingEntity(
      id: c.id,
      name: c.name,
      type: c.type,
      color: c.color,
      isActive: c.isActive,
    )).toList();
  }

  /// Cache active shift data
  Future<void> cacheActiveShift(String id, Map<String, dynamic> jsonData) async {
    await _db.cacheActiveShift(id, jsonEncode(jsonData));
  }

  /// Get cached active shift JSON
  Future<Map<String, dynamic>?> getCachedActiveShift() async {
    final cached = await _db.getActiveShiftCache();
    if (cached == null) return null;
    return jsonDecode(cached.jsonData) as Map<String, dynamic>;
  }

  /// Queue an operation for later sync
  Future<void> queueOperation(String type, Map<String, dynamic> payload) async {
    await _db.addPendingOperation(type, jsonEncode(payload));
    _emitPendingCount();
  }

  /// Get pending operations count
  Future<int> getPendingCount() async {
    return _db.pendingCount();
  }

  /// Sync all pending operations
  Future<void> syncPendingOperations() async {
    if (_syncing) return;
    _syncing = true;

    try {
      final operations = await _db.getPendingOperations();
      for (final op in operations) {
        try {
          await _db.markOperationSyncing(op.id);
          final payload = jsonDecode(op.payload) as Map<String, dynamic>;

          switch (op.operationType) {
            case 'ADD_MOVEMENT':
              await _movementService.create(
                shiftId: payload['shiftId'],
                type: payload['type'],
                direction: payload['direction'],
                amount: (payload['amount'] as num).toDouble(),
                description: payload['description'],
                receiptPhotoUrl: payload['receiptPhotoUrl'],
              );
              break;
          }

          await _db.removeOperation(op.id);
        } catch (e) {
          await _db.markOperationFailed(op.id, e.toString());
        }
      }
    } finally {
      _syncing = false;
      _emitPendingCount();
    }
  }

  void _emitPendingCount() async {
    final count = await getPendingCount();
    _pendingCountController.add(count);
  }

  void dispose() {
    _pendingCountController.close();
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService();

  // Listen for connectivity changes and sync when back online
  ref.listen<AsyncValue<bool>>(isOnlineProvider, (prev, next) {
    final wasOffline = prev?.value == false;
    final isNowOnline = next.value == true;
    if (wasOffline && isNowOnline) {
      service.syncPendingOperations();
    }
  });

  ref.onDispose(() => service.dispose());
  return service;
});

final pendingCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(syncServiceProvider);
  return service.pendingCountStream;
});
