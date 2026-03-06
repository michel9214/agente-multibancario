import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shift.dart';
import '../services/shift_service.dart';

class ActiveShiftNotifier extends StateNotifier<AsyncValue<Shift?>> {
  final ShiftService _service = ShiftService();

  ActiveShiftNotifier() : super(const AsyncValue.loading()) {
    load();
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
    required List<Map<String, dynamic>> openingBalances,
  }) async {
    final shift = await _service.openShift(
      startingCash: startingCash,
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
