import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class OperasionalTagihanService {
  static final Dio _dio = ApiClient.instance;

  static Future<List<dynamic>> getCabangs() async {
    try {
      final response = await _dio.get('/cabangs');
      if (response.data['success'] == true) {
        return response.data['data'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Error getCabangs: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getTagihanBulanan({
    int? cabangId,
    String? periode,
    String? statusBayar,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (cabangId != null) queryParams['cabang_id'] = cabangId;
      if (periode != null && periode.isNotEmpty) queryParams['periode'] = periode;
      if (statusBayar != null && statusBayar != 'all') queryParams['status_bayar'] = statusBayar;

      final response = await _dio.get(
        '/operasional/tagihan-bulanan',
        queryParameters: queryParams,
      );
      
      if (response.data['success'] == true) {
        return response.data['data'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Error getTagihanBulanan: $e');
      rethrow;
    }
  }

  static Future<void> createTagihan(Map<String, dynamic> data) async {
    try {
      final formData = FormData.fromMap(data);
      final response = await _dio.post(
        '/operasional/tagihan-bulanan',
        data: formData,
      );
      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Gagal membuat tagihan');
      }
    } catch (e) {
      print('Error createTagihan: $e');
      rethrow;
    }
  }

  static Future<void> updateTagihan(int id, Map<String, dynamic> data) async {
    try {
      // Dio doesn't support Multipart form data via PUT natively with php easily, 
      // so we use POST with an identifier if needed, or just POST to the update endpoint.
      data['_method'] = 'PUT'; // Laravel spoofing method
      final formData = FormData.fromMap(data);
      final response = await _dio.post(
        '/operasional/tagihan-bulanan/$id',
        data: formData,
      );
      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Gagal memperbarui tagihan');
      }
    } catch (e) {
      print('Error updateTagihan: $e');
      rethrow;
    }
  }

  static Future<void> deleteTagihan(int id) async {
    try {
      final response = await _dio.delete('/operasional/tagihan-bulanan/$id');
      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Gagal menghapus tagihan');
      }
    } catch (e) {
      print('Error deleteTagihan: $e');
      rethrow;
    }
  }
}
