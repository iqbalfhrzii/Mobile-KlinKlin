import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class KontenMarketingService {
  final Dio _dio = ApiClient.instance;

  /// Get list of marketing contents with filtering by type (story, promo, follow_up)
  Future<Map<String, dynamic>> getContents({
    String type = 'story',
    String? search,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'type': type,
        'page': page,
      };
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _dio.get(
        '/konten-marketing',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        return {
          'status': true,
          'data': response.data['data'],
          'message': response.data['message'],
        };
      }
      return {
        'status': false,
        'message': response.data?['message'] ?? 'Gagal memuat konten marketing',
      };
    } catch (e) {
      return {
        'status': false,
        'message': 'Terjadi kesalahan: $e',
      };
    }
  }

  /// Upload new marketing content (e.g. from Designer / Admin)
  Future<Map<String, dynamic>> uploadContent(
    Map<String, dynamic> data, {
    String? filePath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'title': data['title'],
        'description': data['description'] ?? '',
        'type': data['type'] ?? 'story',
      });

      if (filePath != null && filePath.isNotEmpty) {
        final fileName = filePath.split('/').last.split('\\').last;
        formData.files.add(
          MapEntry(
            'file',
            await MultipartFile.fromFile(
              filePath,
              filename: fileName,
            ),
          ),
        );
      }

      final response = await _dio.post(
        '/konten-marketing',
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'status': true,
          'data': response.data['data'],
          'message': response.data['message'] ?? 'Konten berhasil diunggah',
        };
      }
      return {
        'status': false,
        'message': response.data?['message'] ?? 'Gagal mengunggah konten',
      };
    } catch (e) {
      return {
        'status': false,
        'message': 'Terjadi kesalahan saat mengunggah: $e',
      };
    }
  }

  /// Delete marketing content
  Future<Map<String, dynamic>> deleteContent(int id) async {
    try {
      final response = await _dio.delete('/konten-marketing/$id');
      if (response.statusCode == 200) {
        return {
          'status': true,
          'message': response.data?['message'] ?? 'Konten berhasil dihapus',
        };
      }
      return {
        'status': false,
        'message': response.data?['message'] ?? 'Gagal menghapus konten',
      };
    } catch (e) {
      return {
        'status': false,
        'message': 'Terjadi kesalahan saat menghapus: $e',
      };
    }
  }
}
