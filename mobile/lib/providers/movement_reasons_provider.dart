import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/movement_reason.dart';
import '../services/movement_reason_service.dart';

class MovementReasonsNotifier
    extends StateNotifier<AsyncValue<List<MovementReason>>> {
  final MovementReasonService _service = MovementReasonService();

  MovementReasonsNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({bool activeOnly = false}) async {
    state = const AsyncValue.loading();
    try {
      final reasons = await _service.getAll(activeOnly: activeOnly);
      state = AsyncValue.data(reasons);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> create({
    required String name,
    required String defaultDirection,
  }) async {
    await _service.create(name: name, defaultDirection: defaultDirection);
    await load();
  }

  Future<void> update({
    required String id,
    String? name,
    String? defaultDirection,
    bool? isActive,
  }) async {
    await _service.update(
      id: id,
      name: name,
      defaultDirection: defaultDirection,
      isActive: isActive,
    );
    await load();
  }
}

final movementReasonsProvider = StateNotifierProvider<MovementReasonsNotifier,
    AsyncValue<List<MovementReason>>>((ref) {
  return MovementReasonsNotifier();
});
