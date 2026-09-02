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
    List<int>? photoBytes,
    String? photoName, {
    String? subType,
  }) async {
    try {
      final map = <String, dynamic>{
        'jenis_pengajuan': type,
        'tanggal_mulai': startDate,
        'tanggal_selesai': endDate,
        'alasan': reason,
      };

      if (subType != null && subType.isNotEmpty) {
        map['tipe_cuti_khusus'] = subType;
      }

      final formData = FormData.fromMap(map);

      if (photoBytes != null && photoBytes.isNotEmpty && photoName != null) {
        formData.files.add(MapEntry(
          'bukti_foto',
          MultipartFile.fromBytes(photoBytes, filename: photoName),
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
