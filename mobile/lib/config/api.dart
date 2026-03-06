class ApiConfig {
  // Uses adb reverse to map localhost:3000 on device to PC's localhost:3000
  static const String baseUrl = 'http://localhost:3000/api';
  static const String uploadsBaseUrl = 'http://localhost:3000';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
