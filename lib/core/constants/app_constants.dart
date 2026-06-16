class AppConstants {
  AppConstants._();

  // Base URL – ganti dengan URL API atau IP kamu saat tes device / production
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  // Timeout dalam milidetik
  static const int connectTimeout = 10000;
  static const int receiveTimeout = 10000;

  // Shared Preferences keys
  static const String tokenKey = 'auth_token';
}
