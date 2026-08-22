import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class OperasionalPengumumanService {
  final Dio _dio = ApiClient.instance;

  Future<Map<String, dynamic>> getPengumuman({
    String tab = 'diterima',
    String? search,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'tab': tab,
        'page': page,
      };
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final res = await _dio.get(
        '/operasional/pengumuman',
        queryParameters: queryParams,
      );

      return {
        'status': true,
        'data': res.data['data'] ?? res.data,
      };
    } on DioException catch (e) {
      return {
        'status': false,
        'message': e.response?.data['message'] ?? e.message ?? 'Gagal memuat pengumuman',
      };
    } catch (e) {
      return {
        'status': false,
        'message': 'Terjadi kesalahan: $e',
      };
    }
  }

  Future<Map<String, dynamic>> getFormOptions() async {
    try {
      final res = await _dio.get('/operasional/pengumuman/form-options');
      return {
        'status': true,
        'data': res.data['data'] ?? res.data,
      };
    } on DioException catch (e) {
      return {
        'status': false,
        'message': e.response?.data['message'] ?? e.message ?? 'Gagal memuat opsi form',
      };
    } catch (e) {
      return {
        'status': false,
        'message': 'Terjadi kesalahan: $e',
      };
    }
  }

  Future<Map<String, dynamic>> getDetail(int id) async {
    try {
      final res = await _dio.get('/operasional/pengumuman/$id');
      return {
        'status': true,
        'data': res.data['data'] ?? res.data,
      };
    } on DioException catch (e) {
      return {
        'status': false,
        'message': e.response?.data['message'] ?? e.message ?? 'Gagal memuat detail pengumuman',
      };
    } catch (e) {
      return {
        'status': false,
        'message': 'Terjadi kesalahan: $e',
      };
    }
  }

  Future<Map<String, dynamic>> markAsRead(int id) async {
    try {
      final res = await _dio.post('/operasional/pengumuman/$id/mark-as-read');
      return {
        'status': true,
        'message': res.data['message'] ?? 'Pengumuman ditandai sudah dibaca',
      };
    } on DioException catch (e) {
      return {
        'status': false,
        'message': e.response?.data['message'] ?? e.message ?? 'Gagal menandai pengumuman',
      };
    } catch (e) {
      return {
        'status': false,
        'message': 'Terjadi kesalahan: $e',
      };
    }
  }

  Future<Map<String, dynamic>> storePengumuman(
    Map<String, dynamic> data, {
    String? filePath,
  }) async {
    try {
      final map = Map<String, dynamic>.from(data);

      if (filePath != null && filePath.isNotEmpty) {
        map['file'] = await MultipartFile.fromFile(
          filePath,
          filename: filePath.split('/').last.split('\\').last,
        );
      }

      final formData = FormData.fromMap(map);

      final res = await _dio.post(
        '/operasional/pengumuman',
        data: formData,
      );

      return {
        'status': true,
        'message': res.data['message'] ?? 'Pengumuman berhasil dibuat',
        'data': res.data['data'] ?? res.data,
      };
    } on DioException catch (e) {
      return {
        'status': false,
        'message': e.response?.data['message'] ?? e.message ?? 'Gagal membuat pengumuman',
      };
    } catch (e) {
      return {
        'status': false,
        'message': 'Terjadi kesalahan: $e',
      };
    }
  }
}
