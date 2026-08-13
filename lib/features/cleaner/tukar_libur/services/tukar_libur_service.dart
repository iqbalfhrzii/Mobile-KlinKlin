import '../../../../core/network/dio_client.dart';

class TukarLiburService {
  static final _dio = DioClient.instance.dio;

  static Future<Map<String, dynamic>> getRekanKerja() async {
    try {
      final response = await _dio.get('/cleaner/rekan-kerja');
      return response.data['data'];
    } catch (e) {
      throw Exception('Gagal memuat daftar rekan kerja');
    }
  }

  static Future<List<dynamic>> getRiwayat() async {
    try {
      final response = await _dio.get('/cleaner/tukar-libur');
      return response.data['data'];
    } catch (e) {
      throw Exception('Gagal memuat riwayat tukar libur');
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
      return response.data;
    } catch (e) {
      throw Exception('Gagal mengajukan tukar libur');
    }
  }
}
