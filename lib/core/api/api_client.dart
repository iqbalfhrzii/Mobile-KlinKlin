import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/app.dart';
import '../../features/auth/screens/login_screen.dart';

class ApiClient {
  // Gunakan IP teman Anda (192.168.1.18) sebagai base URL
  static const String baseUrl = 'http://erp.klinklin.online/api';

  static final Dio _dio =
      Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final prefs = await SharedPreferences.getInstance();
              final token = prefs.getString('auth_token');
              if (token != null) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              return handler.next(options);
            },
            onError: (error, handler) async {
              if (error.response?.statusCode == 401) {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('auth_token');
                  await prefs.remove('user_name');
                  await prefs.remove('user_role');

                  globalNavigatorKey.currentState?.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                } catch (_) {}
              }
              return handler.next(error);
            },
          ),
        );

  static Dio get instance => _dio;
}
