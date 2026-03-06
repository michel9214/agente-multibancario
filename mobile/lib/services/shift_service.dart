import 'api_client.dart';
import '../models/shift.dart';
import '../models/reconciliation.dart';

class ShiftService {
  final _api = ApiClient().dio;

  Future<Shift> openShift({
    required double startingCash,
    required List<Map<String, dynamic>> openingBalances,
  }) async {
    final response = await _api.post('/shifts', data: {
      'startingCash': startingCash,
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

  Future<Shift> closeShift({
    required String shiftId,
    required double endingCash,
    required List<Map<String, dynamic>> closingBalances,
  }) async {
    final response = await _api.patch('/shifts/$shiftId/close', data: {
      'endingCash': endingCash,
      'closingBalances': closingBalances,
    });
    return Shift.fromJson(response.data);
  }

  Future<Map<String, dynamic>> getShifts({int page = 1, int limit = 20}) async {
    final response = await _api.get('/shifts', queryParameters: {
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
