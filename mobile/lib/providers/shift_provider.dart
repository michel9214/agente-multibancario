import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';
import '../models/shift.dart';
import '../services/shift_service.dart';

class ActiveShiftNotifier extends StateNotifier<AsyncValue<Shift?>> {
  final ShiftService _service = ShiftService();
  final AppDatabase _db = AppDatabase.instance;

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
      if (shift == null) {
        await _db.clearActiveShiftCache();
      }
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

  Future<Shift> preCloseShift({
    required String shiftId,
    required double endingCash,
    required List<Map<String, dynamic>> closingBalances,
    List<Map<String, dynamic>> commissions = const [],
  }) async {
    final shift = await _service.preCloseShift(
      shiftId: shiftId,
      endingCash: endingCash,
      closingBalances: closingBalances,
      commissions: commissions,
    );
    state = AsyncValue.data(shift);
    return shift;
  }

  Future<Shift> finalCloseShift({
    required String shiftId,
    String? discrepancyNote,
    String? discrepancyPhotoUrl,
  }) async {
    final shift = await _service.finalCloseShift(
      shiftId: shiftId,
      discrepancyNote: discrepancyNote,
      discrepancyPhotoUrl: discrepancyPhotoUrl,
    );
    await _db.clearActiveShiftCache();
    state = const AsyncValue.data(null);
    return shift;
  }

  Future<Shift> reopenShift(String shiftId) async {
    final shift = await _service.reopenShift(shiftId);
    state = AsyncValue.data(shift);
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
