import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class UangKasService {
  final Dio _dio = ApiClient.instance;

  // ===================== CASHFLOW CABANG =====================

  Future<Map<String, dynamic>> getCashflow({
    int page = 1,
    String? search,
    int? cabangId,
    String? arus,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'page': page,
      };

      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (cabangId != null) queryParams['cabang_id'] = cabangId;
      if (arus != null && arus.isNotEmpty && arus != 'Semua Arus' && arus != 'Semua') {
        queryParams['arus'] = arus;
      }

      final response = await _dio.get(
        '/operasional/cashflow-cabang',
        queryParameters: queryParams,
      );

      return response.data ?? {'data': []};
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Gagal memuat data cashflow cabang');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  Future<Map<String, dynamic>> createCashflow(Map<String, dynamic> data, {File? file}) async {
    try {
      final formData = FormData.fromMap(data);

      if (file != null) {
        String fileName = file.path.split('/').last.split('\\').last;
        formData.files.add(
          MapEntry(
            'bukti',
            await MultipartFile.fromFile(
              file.path,
              filename: fileName,
            ),
          ),
        );
      }

      final response = await _dio.post(
        '/operasional/cashflow-cabang',
        data: formData,
      );

      return response.data ?? {'status': true, 'message': 'Data cashflow berhasil disimpan'};
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Gagal menyimpan data cashflow');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  Future<Map<String, dynamic>> updateCashflow(int id, Map<String, dynamic> data, {File? file}) async {
    try {
      final formData = FormData.fromMap(data);

      if (file != null) {
        String fileName = file.path.split('/').last.split('\\').last;
        formData.files.add(
          MapEntry(
            'bukti',
            await MultipartFile.fromFile(
              file.path,
              filename: fileName,
            ),
          ),
        );
      }

      final response = await _dio.post(
        '/operasional/cashflow-cabang/$id',
        data: formData,
      );

      return response.data ?? {'status': true, 'message': 'Data cashflow berhasil diperbarui'};
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Gagal memperbarui data cashflow');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  Future<bool> deleteCashflow(int id) async {
    try {
      final response = await _dio.delete('/operasional/cashflow-cabang/$id');
      return response.data['success'] == true || response.data['status'] == true;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Gagal menghapus data cashflow');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  // ===================== PENGAJUAN UANG KAS =====================

  Future<Map<String, dynamic>> getPengajuanKas({
    int page = 1,
    String? search,
    int? cabangId,
    String? status,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'page': page,
      };

      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (cabangId != null) queryParams['cabang_id'] = cabangId;
      if (status != null && status.isNotEmpty && status != 'Semua Status' && status != 'Semua') {
        queryParams['status'] = status.toLowerCase();
      }

      final response = await _dio.get(
        '/pengajuan-kas',
        queryParameters: queryParams,
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
      throw Exception(e.response?.data['message'] ?? 'Gagal memuat data pengajuan uang kas');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  Future<Map<String, dynamic>> createPengajuanKas(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        '/pengajuan-kas',
        data: data,
      );
      return response.data ?? {'status': true, 'message': 'Pengajuan kas berhasil disimpan'};
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Gagal menyimpan pengajuan kas');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  Future<Map<String, dynamic>> updatePengajuanKas(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(
        '/pengajuan-kas/$id',
        data: data,
      );
      return response.data ?? {'status': true, 'message': 'Pengajuan kas berhasil diperbarui'};
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Gagal memperbarui pengajuan kas');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  Future<bool> deletePengajuanKas(int id) async {
    try {
      final response = await _dio.delete('/pengajuan-kas/$id');
      return response.data['status'] == true;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Gagal menghapus pengajuan kas');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  // ===================== CABANGS =====================

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
