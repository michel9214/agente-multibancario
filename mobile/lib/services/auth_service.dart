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

  Future<Map<String, dynamic>> loginOperator(String operatorId) async {
    final response = await _api.post('/auth/login-operator/$operatorId', data: {});
    return response.data;
  }

  Future<List<User>> listOperators() async {
    final response = await _api.get('/auth/operators');
    return (response.data as List).map((e) => User.fromJson(e)).toList();
  }

  Future<User> register({
    required String fullName,
    String? email,
    String? password,
    String? photoUrl,
    String role = 'OPERATOR',
  }) async {
    final response = await _api.post('/auth/register', data: {
      'fullName': fullName,
      if (email != null) 'email': email,
      if (password != null) 'password': password,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'role': role,
    });
    return User.fromJson(response.data);
  }
}
