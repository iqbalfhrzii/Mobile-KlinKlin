import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';

class AuthService {
  static final Dio _dio = ApiClient.instance;
  static final ValueNotifier<int> profileUpdateNotifier = ValueNotifier(0);

  /// Returns token and user data if successful
  static Future<Map<String, dynamic>> login(String email, String pin) async {
    try {
      final response = await _dio.post(
        '/login',
        data: {'email': email, 'pin': pin},
      );

      dynamic rawData = response.data;
      if (rawData is String) {
        try {
          rawData = jsonDecode(rawData);
        } catch (_) {}
      }

      if (rawData is! Map) {
        throw Exception('Respon server tidak valid');
      }

      final Map<String, dynamic> data = Map<String, dynamic>.from(rawData);

      if (data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['token'].toString());
        
        // Save user data (safely handle if value is Map/Object)
        String extractStr(dynamic val, [String mapKey = 'nama']) {
          if (val == null) return '';
          if (val is Map) return val[mapKey]?.toString() ?? '';
          return val.toString();
        }

        final dynamic userData = data['data'];
        if (userData is Map) {
          final nama = extractStr(userData['nama']);
          await prefs.setString(
            'user_name',
            nama.isEmpty ? 'Customer Service' : nama,
          );
          await prefs.setString('user_email', extractStr(userData['email']));
          
          final jabatan = extractStr(userData['jabatan'], 'nama_jabatan');
          await prefs.setString(
            'user_role',
            jabatan.isEmpty ? 'Customer Service' : jabatan,
          );

          final cabang = extractStr(userData['cabang'], 'nama_cabang');
          await prefs.setString(
            'user_branch',
            cabang.isEmpty ? '-' : cabang,
          );

          final userId = userData['id']?.toString() ?? '0';
          await prefs.setString('user_id', 'KLK-CS-0$userId');
          await prefs.setString('karyawan_id', userId);

          if (userData['cabang_id'] != null) {
            await prefs.setInt(
              'user_cabang_id',
              int.tryParse(userData['cabang_id'].toString()) ?? 1,
            );
          } else if (userData['cabang'] != null &&
              userData['cabang'] is Map &&
              userData['cabang']['id'] != null) {
            await prefs.setInt(
              'user_cabang_id',
              int.tryParse(userData['cabang']['id'].toString()) ?? 1,
            );
          }
        }
      }

      return data;
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        dynamic errData = e.response?.data;
        if (errData is String) {
          try {
            errData = jsonDecode(errData);
          } catch (_) {}
        }
        if (errData is Map) {
          if (errData['errors'] != null && errData['errors'] is Map) {
            final errorsMap = errData['errors'] as Map;
            if (errorsMap.isNotEmpty) {
              final firstVal = errorsMap.values.first;
              if (firstVal is List && firstVal.isNotEmpty) {
                throw Exception(firstVal.first.toString());
              } else if (firstVal != null) {
                throw Exception(firstVal.toString());
              }
            }
          }
          final msg = errData['message'] ?? errData['error'];
          if (msg != null && msg.toString().trim().isNotEmpty) {
            throw Exception(msg.toString());
          }
        } else if (errData is String && errData.trim().isNotEmpty) {
          final trimmed = errData.trim();
          if (trimmed.contains('<html') || trimmed.contains('<!DOCTYPE')) {
            throw Exception('Terjadi kesalahan koneksi ke server (${e.response?.statusCode ?? 500})');
          }
          throw Exception(trimmed);
        }
        throw Exception('Gagal login (Status ${e.response?.statusCode})');
      }
      throw Exception('Tidak dapat terhubung ke server');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(e.toString());
    }
  }

  static Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await _dio.get('/me');
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await logout(); // Clear token if unauthorized
      }
      throw Exception('Gagal memuat profil');
    }
  }

  static Future<void> logout() async {
    try {
      await _dio.post('/logout');
    } catch (_) {
      // Ignore if logout API fails
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_photo');
  }

  static Future<void> updateProfile(String name, String? photoPath) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      if (photoPath != null && photoPath.isNotEmpty) {
        final formData = FormData.fromMap({
          'foto_profil': await MultipartFile.fromFile(
            photoPath,
            filename: photoPath.split('/').last,
          )
        });
        await _dio.post('/me/foto-profil', data: formData);
      }
      
      // Update local storage
      await prefs.setString('user_name', name);
      if (photoPath != null && photoPath.isNotEmpty) {
        await prefs.setString('user_photo', photoPath);
      }
      profileUpdateNotifier.value++;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Gagal memperbarui profil',
      );
    }
  }

  static Future<void> changePin(String oldPin, String newPin) async {
    try {
      final response = await _dio.post(
        '/change-pin',
        data: {
          'pin_lama': oldPin,
          'pin_baru': newPin,
          'pin_baru_confirmation': newPin,
        },
      );
      // Sukses
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final message = e.response?.data['message'] ?? 'Gagal mengubah PIN';
        throw Exception(message);
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  static Future<void> updateFcmToken(String fcmToken) async {
    try {
      await _dio.post(
        '/cleaner/fcm-token',
        data: {'fcm_token': fcmToken},
      );
    } catch (e) {
      debugPrint('Failed to update FCM token: $e');
    }
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') != null;
  }
}
