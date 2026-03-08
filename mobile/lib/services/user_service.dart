import 'api_client.dart';
import '../models/user.dart';

class UserService {
  final _api = ApiClient().dio;

  Future<List<User>> getAll() async {
    final response = await _api.get('/users');
    return (response.data as List).map((e) => User.fromJson(e)).toList();
  }

  Future<User> getOne(String id) async {
    final response = await _api.get('/users/$id');
    return User.fromJson(response.data);
  }

  Future<User> update(String id,
      {String? fullName, String? photoUrl}) async {
    final response = await _api.patch('/users/$id', data: {
      if (fullName != null) 'fullName': fullName,
      if (photoUrl != null) 'photoUrl': photoUrl,
    });
    return User.fromJson(response.data);
  }

  Future<void> toggleActive(String id) async {
    await _api.patch('/users/$id/toggle-active');
  }
}
