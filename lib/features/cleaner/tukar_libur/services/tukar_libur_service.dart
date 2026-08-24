import 'package:dio/dio.dart';
import '../../../../core/api/api_client.dart';

class TukarLiburService {
  static final Dio _dio = ApiClient.instance;

  static Future<Map<String, dynamic>> getRekanKerja() async {
    try {
      final response = await _dio.get('/cleaner/rekan-kerja');
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
        return data['data'] as Map<String, dynamic>;
      }
      return {'rekan': [], 'libur_saya': []};
    } catch (e) {
      return {'rekan': [], 'libur_saya': []};
    }
  }

  static Future<List<dynamic>> getRiwayat() async {
    try {
      final response = await _dio.get('/cleaner/tukar-libur');
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        return data['data'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> ajukanTukarLibur({
    required int targetId,
    required String tanggalPengaju,
    required String tanggalTarget,
    required String alasan,
  }) async {
    try {
      final response = await _dio.post('/cleaner/tukar-libur', data: {
        'target_id': targetId,
        'tanggal_pengaju': tanggalPengaju,
        'tanggal_target': tanggalTarget,
        'alasan': alasan,
      });
      return response.data ?? {};
    } catch (e) {
      throw Exception('Gagal mengajukan tukar libur: $e');
    }
  }
}
