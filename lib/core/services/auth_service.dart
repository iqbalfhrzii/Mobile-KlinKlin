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

      final data = response.data;
      if (data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['token']);
        // Save user data (safely handle if value is Map/Object)
        String extractStr(dynamic val, [String mapKey = 'nama']) {
          if (val == null) return '';
          if (val is Map) return val[mapKey]?.toString() ?? val.toString();
          return val.toString();
        }

        await prefs.setString(
          'user_name',
          extractStr(data['data']['nama']) == ''
              ? 'Customer Service'
              : extractStr(data['data']['nama']),
        );
        await prefs.setString('user_email', extractStr(data['data']['email']));
        await prefs.setString(
          'user_role',
          extractStr(data['data']['jabatan'], 'nama_jabatan') == ''
              ? 'Customer Service'
              : extractStr(data['data']['jabatan'], 'nama_jabatan'),
        );
        await prefs.setString(
          'user_branch',
          extractStr(data['data']['cabang'], 'nama_cabang') == ''
              ? '-'
              : extractStr(data['data']['cabang'], 'nama_cabang'),
        );
        await prefs.setString(
          'user_id',
          'KLK-CS-0${data['data']['id'] ?? '0'}',
        );
        if (data['data']['id'] != null) {
          await prefs.setString('karyawan_id', data['data']['id'].toString());
        }
        if (data['data']['cabang_id'] != null) {
          await prefs.setInt(
            'user_cabang_id',
            int.tryParse(data['data']['cabang_id'].toString()) ?? 1,
          );
        } else if (data['data']['cabang'] != null &&
            data['data']['cabang'] is Map &&
            data['data']['cabang']['id'] != null) {
          await prefs.setInt(
            'user_cabang_id',
            int.tryParse(data['data']['cabang']['id'].toString()) ?? 1,
          );
        }
      }

      return data;
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Gagal login');
      }
      throw Exception('Tidak dapat terhubung ke server');
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
    String? id = prefs.getString('karyawan_id');
    if (id == null) {
      // Fallback: extract from user_id which is stored as KLK-CS-0{id}
      final userIdStr = prefs.getString('user_id');
      if (userIdStr != null && userIdStr.startsWith('KLK-CS-0')) {
        id = userIdStr.replaceFirst('KLK-CS-0', '');
      }
    }

    if (id == null || id.isEmpty) {
      throw Exception('ID Karyawan tidak ditemukan, silakan login ulang.');
    }

    Response res;
    try {
      res = await _dio.get('/karyawans/$id');
    } catch (e) {
      throw Exception('Gagal mengambil data profil terbaru.');
    }
    final meData = res.data['data'] ?? res.data;

    final mapData = <String, dynamic>{
      'cabang_id':
          meData['cabang_id'] ??
          (meData['cabang'] is Map ? meData['cabang']['id'] : null),
      'jabatan_id':
          meData['jabatan_id'] ??
          (meData['jabatan'] is Map ? meData['jabatan']['id'] : null),
      'nama': name,
      'email': meData['email'],
      'no_wa': meData['no_wa'] ?? '',
      'status': meData['status'] ?? 'aktif',
    };

    try {
      if (photoPath != null && photoPath.isNotEmpty) {
        mapData['_method'] = 'PUT';
        mapData['foto_profil_file'] = await MultipartFile.fromFile(
          photoPath,
          filename: photoPath.split('/').last,
        );
        final formData = FormData.fromMap(mapData);
        await _dio.post('/karyawans/$id', data: formData);
      } else {
        mapData['foto_profil'] = meData['foto_profil'];
        await _dio.put('/karyawans/$id', data: mapData);
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

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') != null;
  }
}
