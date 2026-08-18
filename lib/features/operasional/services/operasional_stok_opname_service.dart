import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class OperasionalStokOpnameService {
  static final Dio _dio = ApiClient.instance;

  static Future<List<dynamic>> getCabangs() async {
    try {
      final response = await _dio.get('/cabangs');
      if (response.data != null && response.data['data'] != null) {
        return response.data['data'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Error getCabangs in StokOpname: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getSessions({
    int? cabangId,
    String? periodeBulan, // Format: YYYY-MM
    String? tipeSesi,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (cabangId != null) queryParams['cabang_id'] = cabangId;
      if (periodeBulan != null && periodeBulan.isNotEmpty) queryParams['periode_bulan'] = periodeBulan;
      if (tipeSesi != null && tipeSesi.isNotEmpty) queryParams['tipe_sesi'] = tipeSesi;

      final response = await _dio.get(
        '/stok-opname',
        queryParameters: queryParams,
      );
      
      if (response.data != null && response.data['data'] != null) {
        return response.data['data'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Error getSessions: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getSessionDetails(int id) async {
    try {
      final response = await _dio.get('/stok-opname/$id');
      if (response.data != null && response.data['data'] != null) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getSessionDetails: $e');
      rethrow;
    }
  }
}
