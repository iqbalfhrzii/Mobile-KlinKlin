import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';

class CsIzinTukarLiburService {
  final Dio _dio = ApiClient.instance;

  /// Fetch list of approved / rejected cuti & izin for CS's branch
  Future<List<Map<String, dynamic>>> fetchCutiIzin({
    String? status,
    String? bulan,
    String? search,
    int? cabangId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final effectiveCabangId = cabangId ?? prefs.getInt('user_cabang_id');

      final Map<String, dynamic> params = {};
      if (status != null && status.isNotEmpty && status != 'semua' && status != 'all') {
        params['status'] = status;
      }
      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
        params['bulan'] = bulan;
      }
      if (search != null && search.trim().isNotEmpty) {
        params['search'] = search.trim();
      }
      if (effectiveCabangId != null) {
        params['cabang_id'] = effectiveCabangId;
      }

      final response = await _dio.get(
        '/cs/izin-tukar-libur/cuti-izin',
        queryParameters: params,
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        return List<Map<String, dynamic>>.from(
          (data['data'] as List).map((item) => item as Map<String, dynamic>),
        );
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetch list of approved tukar libur for CS's branch
  Future<List<Map<String, dynamic>>> fetchTukarLibur({
    String? bulan,
    String? search,
    int? cabangId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final effectiveCabangId = cabangId ?? prefs.getInt('user_cabang_id');

      final Map<String, dynamic> params = {};
      if (bulan != null && bulan.isNotEmpty && bulan != 'semua') {
        params['bulan'] = bulan;
      }
      if (search != null && search.trim().isNotEmpty) {
        params['search'] = search.trim();
      }
      if (effectiveCabangId != null) {
        params['cabang_id'] = effectiveCabangId;
      }

      final response = await _dio.get(
        '/cs/izin-tukar-libur/tukar-libur',
        queryParameters: params,
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        return List<Map<String, dynamic>>.from(
          (data['data'] as List).map((item) => item as Map<String, dynamic>),
        );
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetch summary of absent/swapped cleaners today
  Future<Map<String, dynamic>> fetchSummaryToday({int? cabangId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final effectiveCabangId = cabangId ?? prefs.getInt('user_cabang_id');

      final Map<String, dynamic> params = {};
      if (effectiveCabangId != null) {
        params['cabang_id'] = effectiveCabangId;
      }

      final response = await _dio.get(
        '/cs/izin-tukar-libur/summary-today',
        queryParameters: params,
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
        return data['data'] as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      return {};
    }
  }
}
