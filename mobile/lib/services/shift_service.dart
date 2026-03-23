import 'api_client.dart';
import '../models/shift.dart';
import '../models/reconciliation.dart';

class ShiftService {
  final _api = ApiClient().dio;

  Future<Shift> openShift({
    required double startingCash,
    double sencillo = 0,
    required List<Map<String, dynamic>> openingBalances,
  }) async {
    final response = await _api.post('/shifts', data: {
      'startingCash': startingCash,
      if (sencillo > 0) 'sencillo': sencillo,
      'openingBalances': openingBalances,
    });
    return Shift.fromJson(response.data);
  }

  Future<Shift?> getActiveShift() async {
    final response = await _api.get('/shifts/active');
    if (response.data == null || response.data == '') return null;
    return Shift.fromJson(response.data);
  }

  Future<Shift> getShift(String id) async {
    final response = await _api.get('/shifts/$id');
    return Shift.fromJson(response.data);
  }

  /// Pre-close: saves closing data, status becomes PRECLOSED
  Future<Shift> preCloseShift({
    required String shiftId,
    required double endingCash,
    required List<Map<String, dynamic>> closingBalances,
    List<Map<String, dynamic>> commissions = const [],
  }) async {
    final response = await _api.patch('/shifts/$shiftId/preclose', data: {
      'endingCash': endingCash,
      'closingBalances': closingBalances,
      if (commissions.isNotEmpty) 'commissions': commissions,
    });
    return Shift.fromJson(response.data);
  }

  /// Final close: from PRECLOSED to CLOSED
  Future<Shift> finalCloseShift({
    required String shiftId,
    String? discrepancyNote,
    String? discrepancyPhotoUrl,
  }) async {
    final response = await _api.patch('/shifts/$shiftId/close', data: {
      if (discrepancyNote != null) 'discrepancyNote': discrepancyNote,
      if (discrepancyPhotoUrl != null) 'discrepancyPhotoUrl': discrepancyPhotoUrl,
    });
    return Shift.fromJson(response.data);
  }

  /// Reopen from PRECLOSED back to OPEN
  Future<Shift> reopenShift(String shiftId) async {
    final response = await _api.patch('/shifts/$shiftId/reopen', data: {});
    return Shift.fromJson(response.data);
  }

  Future<Shift> updateCommissions(
      String shiftId, List<Map<String, dynamic>> commissions) async {
    final response = await _api.patch('/shifts/$shiftId/commissions', data: {
      'commissions': commissions,
    });
    return Shift.fromJson(response.data);
  }

  /// Annul an OPEN shift (OWNER only) - deletes shift and all data
  Future<void> annulShift(String shiftId) async {
    await _api.delete('/shifts/$shiftId');
  }

  Future<Shift> annulClose(String shiftId) async {
    final response = await _api.patch('/shifts/$shiftId/annul-close', data: {});
    return Shift.fromJson(response.data);
  }

  Future<Shift?> getLastClosedShift() async {
    final response = await _api.get('/shifts/last-closed');
    if (response.data == null || response.data == '') return null;
    return Shift.fromJson(response.data);
  }

  Future<Map<String, dynamic>> getShifts({int page = 1, int limit = 20}) async {
    final response = await _api.get('/shifts', queryParameters: {
      'page': page,
      'limit': limit,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getShiftComparisons({int page = 1, int limit = 20}) async {
    final response = await _api.get('/shifts/comparisons', queryParameters: {
      'page': page,
      'limit': limit,
    });
    return response.data;
  }

  Future<Reconciliation> getReconciliation(String shiftId) async {
    final response = await _api.get('/shifts/$shiftId/reconciliation');
    return Reconciliation.fromJson(response.data);
  }
}
