import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class PembelianBhpService {
  final Dio _dio = ApiClient.instance;

  Future<Map<String, dynamic>> getPembelianBhp({
    int? bulan,
    int? tahun,
    int? cabangId,
    String? search,
    int page = 1,
  }) async {
    try {
      final Map<String, dynamic> params = {'page': page};
      if (bulan != null) params['bulan'] = bulan;
      if (tahun != null) params['tahun'] = tahun;
      if (cabangId != null) params['cabang_id'] = cabangId;
      if (search != null && search.isNotEmpty) params['search'] = search;

      final response = await _dio.get(
        '/pembelian-bhp',
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
      throw Exception(e.response?.data['message'] ?? 'Gagal memuat data pembelian BHP');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  Future<Map<String, dynamic>> getPembelianBhpDetail(int id) async {
    try {
      final response = await _dio.get('/pembelian-bhp/$id');
      if (response.data != null && response.data['data'] != null) {
        return response.data['data'];
      }
      return response.data ?? {};
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Gagal memuat detail pembelian BHP');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  Future<Map<String, dynamic>> createPembelianBhp({
    required Map<String, dynamic> data,
    required File photo,
  }) async {
    try {
      final Map<String, dynamic> formMap = Map<String, dynamic>.from(data);

      final fileName = photo.path.split('/').last.split('\\').last;
      formMap['foto_barang'] = await MultipartFile.fromFile(
        photo.path,
        filename: fileName,
      );

      final formData = FormData.fromMap(formMap);

      final response = await _dio.post(
        '/pembelian-bhp',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      return response.data ?? {'status': true, 'message': 'Pembelian BHP berhasil disimpan'};
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? e.response?.data['errors']?.toString() ?? 'Gagal menyimpan pembelian BHP');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  Future<bool> deletePembelianBhp(int id) async {
    try {
      final response = await _dio.delete('/pembelian-bhp/$id');
      return response.data['status'] == true;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Gagal menghapus pembelian BHP');
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
