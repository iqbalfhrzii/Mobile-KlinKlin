import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class OperasionalKantorService {
  static final Dio _dio = ApiClient.instance;

  static Future<List<dynamic>> fetchKantor() async {
    try {
      final response = await _dio.get('/cabangs');
      if (response.statusCode == 200) {
        return response.data['data'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Error fetchKantor: $e');
      rethrow;
    }
  }

  static Future<void> updateKantor(int cabangId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(
        '/operasional/cabangs/$cabangId/kantor',
        data: data,
      );
      if (response.data['status'] != true && response.data['message'] == null) {
        throw Exception('Gagal memperbarui data kantor');
      }
    } catch (e) {
      print('Error updateKantor: $e');
      rethrow;
    }
  }
}
