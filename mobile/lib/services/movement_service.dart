import 'api_client.dart';
import '../models/movement.dart';

class MovementService {
  final _api = ApiClient().dio;

  Future<Movement> create({
    required String shiftId,
    required String type,
    required String direction,
    required double amount,
    String? reasonId,
    String? description,
    String? receiptPhotoUrl,
  }) async {
    final response = await _api.post('/shifts/$shiftId/movements', data: {
      'type': type,
      'direction': direction,
      'amount': amount,
      if (reasonId != null) 'reasonId': reasonId,
      if (description != null) 'description': description,
      if (receiptPhotoUrl != null) 'receiptPhotoUrl': receiptPhotoUrl,
    });
    return Movement.fromJson(response.data);
  }

  Future<Movement> update({
    required String shiftId,
    required String movementId,
    String? type,
    String? reasonId,
    String? direction,
    double? amount,
    String? description,
    String? receiptPhotoUrl,
  }) async {
    final response =
        await _api.patch('/shifts/$shiftId/movements/$movementId', data: {
      if (type != null) 'type': type,
      if (reasonId != null) 'reasonId': reasonId,
      if (direction != null) 'direction': direction,
      if (amount != null) 'amount': amount,
      if (description != null) 'description': description,
      if (receiptPhotoUrl != null) 'receiptPhotoUrl': receiptPhotoUrl,
    });
    return Movement.fromJson(response.data);
  }

  Future<List<Movement>> getByShift(String shiftId) async {
    final response = await _api.get('/shifts/$shiftId/movements');
    return (response.data as List)
        .map((e) => Movement.fromJson(e))
        .toList();
  }

  Future<void> delete(String id, String shiftId) async {
    await _api.delete('/shifts/$shiftId/movements/$id');
  }
}
