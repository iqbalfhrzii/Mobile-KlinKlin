import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Interceptor untuk inject JWT token dan handle error global.
class ApiInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Ambil token dari local storage (graceful — lanjut meski gagal)
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);

      // Inject Bearer token jika ada
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      // SharedPreferences gagal (PlatformException) → lanjut tanpa token
      debugPrint('[ApiInterceptor] SharedPreferences error: $e');
    }

    options.headers['Accept'] = 'application/json';
    options.headers['Content-Type'] = 'application/json';

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.response?.statusCode) {
      case 401:
        // Token expired / tidak valid → bisa trigger logout
        // TODO: Tambahkan logic redirect ke halaman login
        break;
      case 403:
        // Forbidden
        break;
      case 500:
        // Server error
        break;
    }
    return handler.next(err);
  }
}
