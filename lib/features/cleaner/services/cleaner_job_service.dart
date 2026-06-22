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
      throw Exception(response.data['message'] ?? 'Gagal mengambil data jobs');
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil data jobs');
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
        return response.data['data'];
      }
      throw Exception(response.data['message'] ?? 'Gagal mengambil detail job');
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil detail job');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<void> startJob(int pesananCleanerId) async {
    final cleanerId = await _getCleanerId();
    if (cleanerId == null) throw Exception('Cleaner ID tidak ditemukan');

    try {
      final response = await _dio.post('/cleaner/jobs/$pesananCleanerId/start', queryParameters: {
        'cleaner_id': cleanerId,
      });

      if (response.data['status'] != true) {
        throw Exception(response.data['message'] ?? 'Gagal memulai job');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Gagal memulai job');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<void> finishJob(int pesananCleanerId) async {
    final cleanerId = await _getCleanerId();
    if (cleanerId == null) throw Exception('Cleaner ID tidak ditemukan');

    try {
      final response = await _dio.post('/cleaner/jobs/$pesananCleanerId/finish', queryParameters: {
        'cleaner_id': cleanerId,
      });

      if (response.data['status'] != true) {
        throw Exception(response.data['message'] ?? 'Gagal menyelesaikan job');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Gagal menyelesaikan job');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }
}
