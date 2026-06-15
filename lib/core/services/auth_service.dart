import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';

class AuthService {
  static final Dio _dio = ApiClient.instance;

  /// Returns token and user data if successful
  static Future<Map<String, dynamic>> login(String email, String pin) async {
    try {
      final response = await _dio.post('/login', data: {
        'email': email,
        'pin': pin,
      });
      
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

        await prefs.setString('user_name', extractStr(data['data']['nama']) == '' ? 'Customer Service' : extractStr(data['data']['nama']));
        await prefs.setString('user_email', extractStr(data['data']['email']));
        await prefs.setString('user_role', extractStr(data['data']['jabatan'], 'nama_jabatan') == '' ? 'Customer Service' : extractStr(data['data']['jabatan'], 'nama_jabatan'));
        await prefs.setString('user_branch', extractStr(data['data']['cabang'], 'nama_cabang') == '' ? '-' : extractStr(data['data']['cabang'], 'nama_cabang'));
        await prefs.setString('user_id', 'KLK-CS-0${data['data']['id'] ?? '0'}');
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
  }

  static Future<void> changePin(String oldPin, String newPin) async {
    try {
      final response = await _dio.post('/change-pin', data: {
        'pin_lama': oldPin,
        'pin_baru': newPin,
        'pin_baru_confirmation': newPin,
      });
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
