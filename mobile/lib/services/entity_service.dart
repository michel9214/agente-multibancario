import 'api_client.dart';
import '../models/banking_entity.dart';

class EntityService {
  final _api = ApiClient().dio;

  Future<List<BankingEntity>> getAll({bool activeOnly = true}) async {
    final response = await _api.get('/entities', queryParameters: {
      if (activeOnly) 'activeOnly': true,
    });
    return (response.data as List)
        .map((e) => BankingEntity.fromJson(e))
        .toList();
  }

  Future<BankingEntity> create({
    required String name,
    String type = 'BANK',
    String color = '#1976D2',
  }) async {
    final response = await _api.post('/entities', data: {
      'name': name,
      'type': type,
      'color': color,
    });
    return BankingEntity.fromJson(response.data);
  }

  Future<BankingEntity> update({
    required String id,
    String? name,
    String? type,
    String? color,
    bool? isActive,
  }) async {
    final response = await _api.patch('/entities/$id', data: {
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (color != null) 'color': color,
      if (isActive != null) 'isActive': isActive,
    });
    return BankingEntity.fromJson(response.data);
  }

  Future<void> delete(String id) async {
    await _api.delete('/entities/$id');
  }
}
