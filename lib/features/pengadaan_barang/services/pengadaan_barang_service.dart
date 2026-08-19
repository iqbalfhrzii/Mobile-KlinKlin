import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class PengadaanBarangService {
  final Dio _dio = ApiClient.instance;

  Future<Map<String, dynamic>> getPengajuan({
    String? status,
    int? cabangId,
    String? search,
    String? jenis,
    String? urgensi,
    String? startDate,
    String? endDate,
    int page = 1,
  }) async {
    try {
      final Map<String, dynamic> params = {'page': page};
      if (status != null && status.isNotEmpty && status.toLowerCase() != 'semua') {
        params['status'] = status.toLowerCase();
      }
      if (cabangId != null) params['cabang_id'] = cabangId;
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (jenis != null && jenis.isNotEmpty && jenis.toLowerCase() != 'semua') {
        params['jenis'] = jenis;
      }
      if (urgensi != null && urgensi.isNotEmpty && urgensi.toLowerCase() != 'semua') {
        params['urgensi'] = urgensi;
      }
      if (startDate != null && startDate.isNotEmpty) params['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty) params['end_date'] = endDate;

      final response = await _dio.get(
        '/operasional/approval-pengajuan',
        queryParameters: params,
      );

      if (response.data != null && response.data['data'] != null) {
        if (response.data['data'] is Map<String, dynamic>) {
          return response.data['data'] as Map<String, dynamic>;
        } else if (response.data['data'] is List) {
          return {'data': response.data['data'], 'current_page': 1, 'last_page': 1};
        }
      }
      return {'data': []};
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Gagal memuat data pengajuan');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  Future<Map<String, dynamic>> getPengajuanDetail(int id) async {
    try {
      final response = await _dio.get('/operasional/approval-pengajuan/$id');
      if (response.data != null && response.data['data'] != null) {
        return response.data['data'];
      }
      return response.data ?? {};
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Gagal memuat detail pengajuan');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  Future<Map<String, dynamic>> createPengajuan({
    required Map<String, dynamic> data,
    required List<File?> photos,
  }) async {
    try {
      final Map<String, dynamic> formMap = Map<String, dynamic>.from(data);

      for (int i = 0; i < photos.length && i < 5; i++) {
        final photo = photos[i];
        if (photo != null) {
          final fileName = photo.path.split('/').last.split('\\').last;
          formMap['foto_${i + 1}'] = await MultipartFile.fromFile(
            photo.path,
            filename: fileName,
          );
        }
      }

      final formData = FormData.fromMap(formMap);

      final response = await _dio.post(
        '/operasional/approval-pengajuan',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      return response.data ?? {'status': true, 'message': 'Pengajuan berhasil disimpan'};
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? e.response?.data['errors']?.toString() ?? 'Gagal menyimpan pengajuan');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  Future<bool> deletePengajuan(int id) async {
    try {
      final response = await _dio.delete('/operasional/approval-pengajuan/$id');
      return response.data['status'] == true;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Gagal menghapus pengajuan');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  Future<List<dynamic>> getCabangs() async {
    try {
      final response = await _dio.get('/cabangs');
      if (response.data != null && response.data['data'] != null) {
        return response.data['data'] as List;
      } else if (response.data is List) {
        return response.data as List;
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
