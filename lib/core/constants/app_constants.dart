class AppConstants {
  AppConstants._();

  // Base URL – ganti dengan URL API kamu saat production
  static const String baseUrl = 'https://jsonplaceholder.typicode.com';

  // Timeout dalam milidetik
  static const int connectTimeout = 10000;
  static const int receiveTimeout = 10000;

  // Shared Preferences keys
  static const String tokenKey = 'auth_token';
}
