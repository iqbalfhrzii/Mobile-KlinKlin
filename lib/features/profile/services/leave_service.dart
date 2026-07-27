import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class LeaveService {
  Future<Map<String, dynamic>> getLeaveHistory() async {
    try {
      final response = await ApiClient.instance.get('/karyawan/pengajuan');
      return response.data;
    } catch (e) {
      throw Exception('Gagal memuat riwayat pengajuan: $e');
    }
  }

  Future<Map<String, dynamic>> getLeaveQuota() async {
    try {
      final response = await ApiClient.instance.get('/karyawan/cuti/sisa');
      return response.data;
    } catch (e) {
      throw Exception('Gagal memuat sisa cuti: $e');
    }
  }

  Future<Map<String, dynamic>> submitLeaveRequest(
    String type,
    String startDate,
    String endDate,
    String reason,
    String? photoPath,
  ) async {
    try {
      final formData = FormData.fromMap({
        'jenis_pengajuan': type,
        'tanggal_mulai': startDate,
        'tanggal_selesai': endDate,
        'alasan': reason,
      });

      if (photoPath != null && photoPath.isNotEmpty) {
        formData.files.add(MapEntry(
          'bukti_foto',
          await MultipartFile.fromFile(photoPath),
        ));
      }

      final response = await ApiClient.instance.post(
        '/karyawan/pengajuan',
        data: formData,
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Gagal mengirim pengajuan');
    }
  }
}
