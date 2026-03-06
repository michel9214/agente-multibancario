import 'api_client.dart';
import '../models/user.dart';

class AuthService {
  final _api = ApiClient().dio;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _api.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return response.data;
  }

  Future<User> register({
    required String email,
    required String password,
    required String fullName,
    String role = 'OPERATOR',
  }) async {
    final response = await _api.post('/auth/register', data: {
      'email': email,
      'password': password,
      'fullName': fullName,
      'role': role,
    });
    return User.fromJson(response.data);
  }
}
