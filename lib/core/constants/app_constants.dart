class AppConstants {
  AppConstants._();

  // Base URL – ganti dengan URL API atau IP kamu saat tes device / production
  static const String baseUrl = 'http://erp.klinklin.online/api';

  // Timeout dalam milidetik
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;

  // Shared Preferences keys
  static const String tokenKey = 'auth_token';
}
