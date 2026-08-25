import 'package:dio/dio.dart';
import '../../../../core/api/api_client.dart';

class HrdTukarLiburService {
  static final Dio _dio = ApiClient.instance;

  static Future<Map<String, dynamic>> getPengajuanTukarLibur({
    int? cabangId,
    String? bulan,
    String? status,
    String? search,
  }) async {
    try {
      final Map<String, dynamic> params = {};
      if (cabangId != null) params['cabang_id'] = cabangId;
      if (bulan != null && bulan.isNotEmpty) params['bulan'] = bulan;
      if (status != null && status.isNotEmpty && status != 'all' && status != 'semua') {
        params['status'] = status;
      }
      if (search != null && search.trim().isNotEmpty) {
        params['search'] = search.trim();
      }

      final response = await _dio.get(
        '/hrd/tukar-libur',
        queryParameters: params,
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
        return data['data'] as Map<String, dynamic>;
      }

      return {
        'pending': [],
        'riwayat': [],
        'all': [],
        'stats': {
          'total_pending': 0,
          'total_approved': 0,
          'total_rejected': 0,
          'total': 0,
        }
      };
    } catch (e) {
      return {
        'pending': [],
        'riwayat': [],
        'all': [],
        'stats': {
          'total_pending': 0,
          'total_approved': 0,
          'total_rejected': 0,
          'total': 0,
        }
      };
    }
  }

  static Future<Map<String, dynamic>> approve(int id) async {
    try {
      final response = await _dio.post('/hrd/tukar-libur/$id/approve');
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'status': true, 'message': 'Pengajuan berhasil disetujui'};
    } catch (e) {
      if (e is DioException && e.response?.data is Map) {
        final msg = e.response?.data['message'] ?? 'Gagal menyetujui pengajuan';
        throw Exception(msg);
      }
      throw Exception('Gagal menyetujui pengajuan: $e');
    }
  }

  static Future<Map<String, dynamic>> reject(int id) async {
    try {
      final response = await _dio.post('/hrd/tukar-libur/$id/reject');
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'status': true, 'message': 'Pengajuan berhasil ditolak'};
    } catch (e) {
      if (e is DioException && e.response?.data is Map) {
        final msg = e.response?.data['message'] ?? 'Gagal menolak pengajuan';
        throw Exception(msg);
      }
      throw Exception('Gagal menolak pengajuan: $e');
    }
  }
}
