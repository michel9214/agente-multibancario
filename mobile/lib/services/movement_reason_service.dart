import 'api_client.dart';
import '../models/movement_reason.dart';

class MovementReasonService {
  final _api = ApiClient().dio;

  Future<List<MovementReason>> getAll({bool activeOnly = false}) async {
    final response = await _api.get('/movement-reasons', queryParameters: {
      if (activeOnly) 'activeOnly': true,
    });
    return (response.data as List)
        .map((e) => MovementReason.fromJson(e))
        .toList();
  }

  Future<MovementReason> create({
    required String name,
    required String defaultDirection,
  }) async {
    final response = await _api.post('/movement-reasons', data: {
      'name': name,
      'defaultDirection': defaultDirection,
    });
    return MovementReason.fromJson(response.data);
  }

  Future<MovementReason> update({
    required String id,
    String? name,
    String? defaultDirection,
    bool? isActive,
  }) async {
    final response = await _api.patch('/movement-reasons/$id', data: {
      if (name != null) 'name': name,
      if (defaultDirection != null) 'defaultDirection': defaultDirection,
      if (isActive != null) 'isActive': isActive,
    });
    return MovementReason.fromJson(response.data);
  }
}
