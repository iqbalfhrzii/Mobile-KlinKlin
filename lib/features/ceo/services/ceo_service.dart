import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class CeoService {
  final Dio _dio = ApiClient.instance;

  Future<Map<String, dynamic>> getLaporanOmzet({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final response = await _dio.get('/operasional/laporan-omzet', queryParameters: queryParams);
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil laporan omzet');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<Map<String, dynamic>> getReportKpi({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final response = await _dio.get('/operasional/report-kpi', queryParameters: queryParams);
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil report KPI');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<Map<String, dynamic>> getSpendAds({
    String? periode,
    String? search,
    String? platform,
    int? cabangId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (periode != null && periode.isNotEmpty) queryParams['periode'] = periode;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (platform != null && platform.isNotEmpty && platform != 'all') queryParams['platform'] = platform;
      if (cabangId != null) queryParams['cabang_id'] = cabangId;

      final response = await _dio.get('/marketing/spend-ads', queryParameters: queryParams);
      if (response.data is Map<String, dynamic>) {
        return response.data;
      }
      return {'status': true, 'data': response.data};
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        return e.response!.data;
      }
      return {
        'status': false,
        'message': e.response?.data?['message'] ?? e.message ?? 'Gagal mengambil data spend ads',
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> getGrafik({
    int? year,
    String? filterWaktu,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (year != null) queryParams['year'] = year;
      if (filterWaktu != null) queryParams['filter_waktu'] = filterWaktu;
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final response = await _dio.get('/owner/grafik', queryParameters: queryParams);
      if (response.data is Map<String, dynamic>) {
        return response.data;
      }
      return {'status': true, 'data': response.data};
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        return e.response!.data;
      }
      return {
        'status': false,
        'message': e.response?.data?['message'] ?? e.message ?? 'Gagal memuat grafik',
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> getDataChat({String? periode, int? cabangId}) async {
    final queryParams = <String, dynamic>{};
    if (periode != null && periode.isNotEmpty) queryParams['periode'] = periode;
    if (cabangId != null) queryParams['cabang_id'] = cabangId;

    try {
      final response = await _dio.get('/owner/data-chat', queryParameters: queryParams);
      return response.data;
    } on DioException catch (e) {
      try {
        final res = await _dio.get('/operasional/data-chat', queryParameters: queryParams);
        return res.data;
      } catch (_) {}
      if (e.response != null && e.response?.data != null) {
        return e.response!.data;
      }
      return {
        'status': false,
        'message': e.message ?? 'Gagal memuat data chat',
      };
    }
  }

  Future<List<dynamic>> fetchCabangs() async {
    try {
      final response = await _dio.get('/operasional/cabangs');
      if (response.data is Map && response.data['data'] is List) {
        return response.data['data'];
      } else if (response.data is List) {
        return response.data;
      }
      return [];
    } catch (_) {
      try {
        final res = await _dio.get('/cabangs');
        if (res.data is Map && res.data['data'] is List) {
          return res.data['data'];
        }
      } catch (_) {}
      return [];
    }
  }
}
