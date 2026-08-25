class ApiConfig {
  // Production URL (homelab via Cloudflare Tunnel)
  static const String baseUrl = 'https://multibanco.luanmaju.com/api';
  static const String uploadsBaseUrl = 'https://multibanco.luanmaju.com';

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
