import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../../app/app.dart';
import '../../features/auth/screens/login_screen.dart';
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
    if (err.response?.statusCode == 401) {
      // Token expired / tidak valid → trigger logout & redirect
      _handleUnauthorized();
    }
    return handler.next(err);
  }

  Future<void> _handleUnauthorized() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.tokenKey);
      await prefs.remove('user_name');
      await prefs.remove('user_role');
      
      // Redirect to LoginScreen using global navigator key
      globalNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (_) {}
  }
}
