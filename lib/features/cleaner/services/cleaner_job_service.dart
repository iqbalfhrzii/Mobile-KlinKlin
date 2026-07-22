import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';

class CleanerJobService {
  final Dio _dio = ApiClient.instance;

  Future<String?> _getCleanerId() async {
    final prefs = await SharedPreferences.getInstance();
    // In auth_service.dart, we stored karyawan_id if data.id exists
    return prefs.getString('karyawan_id');
  }

  Future<List<dynamic>> fetchJobs() async {
    final cleanerId = await _getCleanerId();
    if (cleanerId == null) throw Exception('Cleaner ID tidak ditemukan');

    try {
      final response = await _dio.get('/cleaner/jobs', queryParameters: {
        'cleaner_id': cleanerId,
      });

      if (response.data['status'] == true) {
        return response.data['data'] as List<dynamic>;
      }
      throw Exception(response.data['message'] ?? 'Gagal mengambil data job');
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil data job');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<Map<String, dynamic>> fetchJobDetail(int pesananCleanerId) async {
    final cleanerId = await _getCleanerId();
    if (cleanerId == null) throw Exception('Cleaner ID tidak ditemukan');

    try {
      final response = await _dio.get('/cleaner/jobs/$pesananCleanerId', queryParameters: {
        'cleaner_id': cleanerId,
      });

      if (response.data['status'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
      throw Exception(response.data['message'] ?? 'Gagal mengambil detail job');
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil detail job');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<void> startJob(int pesananCleanerId, List<File> photos) async {
    final cleanerId = await _getCleanerId();
    if (cleanerId == null) throw Exception('Cleaner ID tidak ditemukan');

    try {
      final List<MultipartFile> files = [];
      for (var f in photos) {
        files.add(await MultipartFile.fromFile(
          f.path,
          filename: f.path.split('/').last,
        ));
      }

      final formData = FormData.fromMap({
        'foto[]': files,
      });

      final response = await _dio.post(
        '/cleaner/jobs/$pesananCleanerId/start',
        queryParameters: {'cleaner_id': cleanerId},
        data: formData,
      );

      if (response.data['status'] != true) {
        throw Exception(response.data['message'] ?? 'Gagal memulai job');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final data = e.response?.data;
        if (data is Map) {
          if (data['errors'] != null) {
            final errs = data['errors'];
            if (errs is Map && errs['foto'] != null) {
              final fotoErrs = errs['foto'];
              if (fotoErrs is List) {
                throw Exception(fotoErrs.join(', '));
              }
              throw Exception(fotoErrs.toString());
            } else if (errs is List) {
              throw Exception(errs.join(', '));
            } else if (errs is Map) {
              final messages = errs.values.expand((v) => v is List ? v : [v.toString()]).join(', ');
              throw Exception(messages);
            }
          }
          if (data['message'] != null) {
            throw Exception(data['message'].toString());
          }
        }
        throw Exception(e.response?.data?.toString() ?? 'Gagal memulai job');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<void> finishJob(int pesananCleanerId, List<File> photos) async {
    final cleanerId = await _getCleanerId();
    if (cleanerId == null) throw Exception('Cleaner ID tidak ditemukan');

    try {
      final List<MultipartFile> files = [];
      for (var f in photos) {
        files.add(await MultipartFile.fromFile(
          f.path,
          filename: f.path.split('/').last,
        ));
      }

      final formData = FormData.fromMap({
        'foto[]': files,
      });

      final response = await _dio.post(
        '/cleaner/jobs/$pesananCleanerId/finish',
        queryParameters: {'cleaner_id': cleanerId},
        data: formData,
      );

      if (response.data['status'] != true) {
        throw Exception(response.data['message'] ?? 'Gagal menyelesaikan job');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final data = e.response?.data;
        if (data is Map) {
          if (data['errors'] != null) {
            final errs = data['errors'];
            if (errs is Map && errs['foto'] != null) {
              final fotoErrs = errs['foto'];
              if (fotoErrs is List) {
                throw Exception(fotoErrs.join(', '));
              }
              throw Exception(fotoErrs.toString());
            } else if (errs is List) {
              throw Exception(errs.join(', '));
            } else if (errs is Map) {
              final messages = errs.values.expand((v) => v is List ? v : [v.toString()]).join(', ');
              throw Exception(messages);
            }
          }
          if (data['message'] != null) {
            throw Exception(data['message'].toString());
          }
        }
        throw Exception(e.response?.data?.toString() ?? 'Gagal menyelesaikan job');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<Map<String, dynamic>> fetchHistory({int? month, int? year}) async {
    final cleanerId = await _getCleanerId();
    if (cleanerId == null) throw Exception('Cleaner ID tidak ditemukan');

    try {
      final response = await _dio.get('/cleaner/jobs/history', queryParameters: {
        'cleaner_id': cleanerId,
        if (month != null) 'month': month,
        if (year != null) 'year': year,
      });

      if (response.data['status'] == true) {
        return response.data['data'];
      }
      throw Exception(response.data['message'] ?? 'Gagal mengambil riwayat pekerjaan');
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil riwayat pekerjaan');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }
}
