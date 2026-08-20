import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/api/api_client.dart';

class OperasionalTagihanService {
  static final Dio _dio = ApiClient.instance;

  static Future<List<dynamic>> getCabangs() async {
    try {
      final response = await _dio.get('/cabangs');
      if (response.data != null && response.data['data'] != null) {
        return response.data['data'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('Error getCabangs: $e');
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
      
      if (response.data != null && response.data['data'] != null) {
        return response.data['data'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('Error getTagihanBulanan: $e');
      rethrow;
    }
  }

  static Future<void> createTagihan(Map<String, dynamic> data) async {
    try {
      final Map<String, dynamic> map = Map.from(data);
      if (map['bukti_bayar'] != null && map['bukti_bayar'] is String && (map['bukti_bayar'] as String).isNotEmpty) {
        map['bukti_bayar'] = await MultipartFile.fromFile(map['bukti_bayar']);
      }
      final formData = FormData.fromMap(map);
      final response = await _dio.post(
        '/operasional/tagihan-bulanan',
        data: formData,
      );
      if (response.statusCode != 200 && response.statusCode != 201 && response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Gagal membuat tagihan');
      }
    } catch (e) {
      debugPrint('Error createTagihan: $e');
      rethrow;
    }
  }

  static Future<void> updateTagihan(int id, Map<String, dynamic> data) async {
    try {
      final Map<String, dynamic> map = Map.from(data);
      map['_method'] = 'PUT'; // Laravel spoofing method
      if (map['bukti_bayar'] != null && map['bukti_bayar'] is String && (map['bukti_bayar'] as String).isNotEmpty) {
        map['bukti_bayar'] = await MultipartFile.fromFile(map['bukti_bayar']);
      }
      final formData = FormData.fromMap(map);
      final response = await _dio.post(
        '/operasional/tagihan-bulanan/$id',
        data: formData,
      );
      if (response.statusCode != 200 && response.statusCode != 201 && response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Gagal memperbarui tagihan');
      }
    } catch (e) {
      debugPrint('Error updateTagihan: $e');
      rethrow;
    }
  }

  static Future<void> deleteTagihan(int id) async {
    try {
      final response = await _dio.delete('/operasional/tagihan-bulanan/$id');
      if (response.statusCode != 200 && response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Gagal menghapus tagihan');
      }
    } catch (e) {
      debugPrint('Error deleteTagihan: $e');
      rethrow;
    }
  }
}
