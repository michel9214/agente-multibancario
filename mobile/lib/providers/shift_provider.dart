import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shift.dart';
import '../services/shift_service.dart';

class ActiveShiftNotifier extends StateNotifier<AsyncValue<Shift?>> {
  final ShiftService _service = ShiftService();

  ActiveShiftNotifier() : super(const AsyncValue.loading()) {
    _loadWithRetry();
  }

  Future<void> _loadWithRetry() async {
    for (var i = 0; i < 3; i++) {
      try {
        final shift = await _service.getActiveShift();
        state = AsyncValue.data(shift);
        return;
      } catch (e, st) {
        if (i == 2) {
          state = AsyncValue.error(e, st);
        } else {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final shift = await _service.getActiveShift();
      state = AsyncValue.data(shift);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Shift> openShift({
    required double startingCash,
    double sencillo = 0,
    required List<Map<String, dynamic>> openingBalances,
  }) async {
    final shift = await _service.openShift(
      startingCash: startingCash,
      sencillo: sencillo,
      openingBalances: openingBalances,
    );
    state = AsyncValue.data(shift);
    return shift;
  }

  Future<Shift> closeShift({
    required String shiftId,
    required double endingCash,
    required List<Map<String, dynamic>> closingBalances,
  }) async {
    final shift = await _service.closeShift(
      shiftId: shiftId,
      endingCash: endingCash,
      closingBalances: closingBalances,
    );
    state = const AsyncValue.data(null);
    return shift;
  }

  void refresh() => load();
}

final activeShiftProvider =
    StateNotifierProvider<ActiveShiftNotifier, AsyncValue<Shift?>>((ref) {
  return ActiveShiftNotifier();
});

final shiftHistoryProvider = FutureProvider.family<Map<String, dynamic>, int>(
  (ref, page) async {
    final service = ShiftService();
    return service.getShifts(page: page);
  },
);
