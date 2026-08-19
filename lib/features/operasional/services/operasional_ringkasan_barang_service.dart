import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class OperasionalRingkasanBarangService {
  static final Dio _dio = ApiClient.instance;

  static Future<Map<String, dynamic>> getSummary({int? cabangId, String? search}) async {
    try {
      final Map<String, dynamic> params = {};
      if (cabangId != null) params['cabang_id'] = cabangId;
      if (search != null && search.isNotEmpty) params['search'] = search;

      final response = await _dio.get(
        '/operasional/ringkasan-barang',
        queryParameters: params,
      );
      return response.data['data'] ?? {};
    } on DioException catch (e) {
      print('OperasionalRingkasanBarangService.getSummary DioException: $e');
      throw Exception(e.response?.data['message'] ?? 'Gagal mengambil ringkasan barang');
    } catch (e) {
      print('OperasionalRingkasanBarangService.getSummary Error: $e');
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  static Future<Map<String, dynamic>> getDetailItem(int barangId, {int? cabangId}) async {
    try {
      final Map<String, dynamic> params = {};
      if (cabangId != null) params['cabang_id'] = cabangId;

      final response = await _dio.get(
        '/operasional/ringkasan-barang/$barangId',
        queryParameters: params,
      );
      return response.data['data'] ?? {};
    } on DioException catch (e) {
      print('OperasionalRingkasanBarangService.getDetailItem DioException: $e');
      throw Exception(e.response?.data['message'] ?? 'Gagal mengambil rincian item');
    } catch (e) {
      print('OperasionalRingkasanBarangService.getDetailItem Error: $e');
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  static Future<List<dynamic>> getCabangs() async {
    try {
      final response = await _dio.get('/cabangs');
      return response.data['data'] as List;
    } catch (e) {
      print('OperasionalRingkasanBarangService.getCabangs Error: $e');
      return [];
    }
  }
}
