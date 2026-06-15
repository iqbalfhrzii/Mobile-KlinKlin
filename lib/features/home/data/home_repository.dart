import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

/// Repository untuk fitur Home.
/// Ambil data dari API dan return hasilnya.
class HomeRepository {
  final Dio _dio = DioClient.instance.dio;

  /// Contoh: fetch list posts dari API
  /// Ganti endpoint ini dengan endpoint dari API kamu
  Future<List<Map<String, dynamic>>> fetchPosts() async {
    try {
      final response = await _dio.get('/posts');
      final List data = response.data;
      return data.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return Exception('Koneksi timeout. Cek jaringan internet kamu.');
    }
    if (e.response != null) {
      return Exception('Error ${e.response?.statusCode}: ${e.response?.statusMessage}');
    }
    return Exception('Terjadi kesalahan. Coba lagi.');
  }
}
