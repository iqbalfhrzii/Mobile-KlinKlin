import 'package:dio/dio.dart';
import '../../../../core/api/api_client.dart';

class HrdJadwalLiburService {
  static final Dio _dio = ApiClient.instance;

  static Future<Map<String, dynamic>> getJadwalLibur({
    int? cabangId,
    int? month,
    int? year,
  }) async {
    try {
      final Map<String, dynamic> params = {};
      if (cabangId != null) params['cabang_id'] = cabangId;
      if (month != null) params['month'] = month;
      if (year != null) params['year'] = year;

      final response = await _dio.get(
        '/hrd/jadwal-libur',
        queryParameters: params,
      );

      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }

      return {
        'cabangs': [],
        'selected_cabang': null,
        'cabang_id': cabangId,
        'month': month ?? DateTime.now().month,
        'year': year ?? DateTime.now().year,
        'days_in_month': 30,
        'karyawans': [],
        'jadwal_liburs': {},
        'karyawan_summary': [],
        'stats': {
          'total_libur_biasa': 0,
          'total_tukar_libur': 0,
          'total_cuti': 0,
          'total_cleaner': 0,
        },
      };
    } catch (e) {
      return {
        'cabangs': [],
        'selected_cabang': null,
        'cabang_id': cabangId,
        'month': month ?? DateTime.now().month,
        'year': year ?? DateTime.now().year,
        'days_in_month': 30,
        'karyawans': [],
        'jadwal_liburs': {},
        'karyawan_summary': [],
        'stats': {
          'total_libur_biasa': 0,
          'total_tukar_libur': 0,
          'total_cuti': 0,
          'total_cleaner': 0,
        },
      };
    }
  }

  static Future<Map<String, dynamic>> toggleLibur({
    required int karyawanId,
    required String tanggal,
  }) async {
    try {
      final response = await _dio.post(
        '/hrd/jadwal-libur/toggle',
        data: {
          'karyawan_id': karyawanId,
          'tanggal': tanggal,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'status': true, 'message': 'Jadwal libur berhasil diperbarui'};
    } catch (e) {
      if (e is DioException && e.response?.data is Map) {
        final msg = e.response?.data['message'] ?? 'Gagal memperbarui jadwal libur';
        throw Exception(msg);
      }
      throw Exception('Gagal memperbarui jadwal libur: $e');
    }
  }

  static Future<Map<String, dynamic>> generatePola({
    required int cabangId,
    required int month,
    required int year,
  }) async {
    try {
      final response = await _dio.post(
        '/hrd/jadwal-libur/generate-pola',
        data: {
          'cabang_id': cabangId,
          'month': month,
          'year': year,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'status': true, 'message': 'Berhasil men-generate jadwal libur'};
    } catch (e) {
      if (e is DioException && e.response?.data is Map) {
        final msg = e.response?.data['message'] ?? 'Gagal men-generate pola jadwal libur';
        throw Exception(msg);
      }
      throw Exception('Gagal men-generate pola jadwal libur: $e');
    }
  }
}
