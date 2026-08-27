import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class LaporKecelakaanService {
  final Dio _dio = ApiClient.instance;

  Future<Map<String, dynamic>> submitLaporan({
    required int cabangId,
    required String tanggal,
    required String jam,
    required String namaPelapor,
    required String namaKorban,
    required String lokasi,
    required String saksi,
    required List<String> peristiwaList,
    String? peristiwaLainnya,
    required List<String> akibatList,
    required String kronologi,
    File? fotoFile,
  }) async {
    try {
      // Build peristiwa string
      final List<String> combinedPeristiwa = List<String>.from(peristiwaList);
      if (peristiwaLainnya != null && peristiwaLainnya.trim().isNotEmpty) {
        combinedPeristiwa.add('Lainnya: ${peristiwaLainnya.trim()}');
      }
      final String peristiwaStr = combinedPeristiwa.join('; ');
      final String akibatStr = akibatList.join(', ');

      final Map<String, dynamic> data = {
        'cabang_id': cabangId,
        'tanggal': tanggal,
        'jam': jam,
        'nama_pelapor': namaPelapor,
        'nama_karyawan': namaKorban,
        'lokasi': lokasi,
        'saksi': saksi,
        'peristiwa': peristiwaStr,
        'penyebab': peristiwaStr, // Also save to penyebab for backwards compatibility
        'akibat': akibatStr,
        'kronologi': kronologi,
        'tingkat': 'Sedang', // Default severity classification
      };

      final FormData formData = FormData.fromMap(data);

      if (fotoFile != null && await fotoFile.exists()) {
        final String fileName = fotoFile.path.split(Platform.pathSeparator).last;
        formData.files.add(
          MapEntry(
            'file_foto',
            await MultipartFile.fromFile(
              fotoFile.path,
              filename: fileName,
            ),
          ),
        );
      }

      final response = await _dio.post(
        '/operasional/kecelakaan',
        data: formData,
      );

      return {
        'status': response.data['status'] ?? true,
        'message': response.data['message'] ?? 'Laporan kecelakaan berhasil dikirim',
        'data': response.data['data'],
      };
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Terjadi kesalahan saat mengirim laporan';
      return {
        'status': false,
        'message': msg,
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> getRiwayatLaporan({int page = 1, int? cabangId}) async {
    try {
      final Map<String, dynamic> queryParams = {'page': page};
      if (cabangId != null) {
        queryParams['cabang_id'] = cabangId;
      }
      final response = await _dio.get(
        '/operasional/kecelakaan',
        queryParameters: queryParams,
      );
      return response.data;
    } catch (e) {
      return {
        'status': false,
        'message': e.toString(),
      };
    }
  }
}
