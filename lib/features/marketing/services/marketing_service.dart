import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class MarketingService {
  final Dio _apiClient = ApiClient.instance;

  // ================= SPEND ADS =================
  Future<Map<String, dynamic>> fetchSpendAds({
    String? platform,
    String? periode,
    String? search,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page};
      if (platform != null && platform.isNotEmpty && platform != 'all') queryParams['platform'] = platform;
      if (periode != null && periode.isNotEmpty) queryParams['periode'] = periode;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _apiClient.get(
        '/marketing/spend-ads',
        queryParameters: queryParams,
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'status': false,
        'message': e.response?.data['message'] ?? e.message,
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> storeSpendAd(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(
        '/marketing/spend-ads',
        data: data,
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'status': false,
        'message': e.response?.data['message'] ?? e.message,
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> updateSpendAd(int id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.put(
        '/marketing/spend-ads/$id',
        data: data,
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'status': false,
        'message': e.response?.data['message'] ?? e.message,
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> deleteSpendAd(int id) async {
    try {
      final response = await _apiClient.delete('/marketing/spend-ads/$id');
      return response.data;
    } on DioException catch (e) {
      return {
        'status': false,
        'message': e.response?.data['message'] ?? e.message,
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString(),
      };
    }
  }

  // ================= MARKETING PROGRESS =================
  Future<Map<String, dynamic>> fetchProgress({
    int? tahun,
    String? search,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (tahun != null) queryParams['tahun'] = tahun;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (status != null && status.isNotEmpty && status != 'all') queryParams['status'] = status;

      final response = await _apiClient.get(
        '/marketing/progress',
        queryParameters: queryParams,
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'status': false,
        'message': e.response?.data['message'] ?? e.message,
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> storeProgress(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(
        '/marketing/progress',
        data: data,
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'status': false,
        'message': e.response?.data['message'] ?? e.message,
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> updateProgress(int id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.put(
        '/marketing/progress/$id',
        data: data,
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'status': false,
        'message': e.response?.data['message'] ?? e.message,
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> deleteProgress(int id) async {
    try {
      final response = await _apiClient.delete('/marketing/progress/$id');
      return response.data;
    } on DioException catch (e) {
      return {
        'status': false,
        'message': e.response?.data['message'] ?? e.message,
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString(),
      };
    }
  }

  // ================= CABANG HELPER =================
  Future<List<dynamic>> fetchCabangs() async {
    try {
      final response = await _apiClient.get('/operasional/cabangs');
      if (response.data is Map && response.data['data'] is List) {
        return response.data['data'];
      } else if (response.data is List) {
        return response.data;
      }
      return [];
    } catch (_) {
      try {
        final res = await _apiClient.get('/cabangs');
        if (res.data is Map && res.data['data'] is List) {
          return res.data['data'];
        } else if (res.data is List) {
          return res.data;
        }
      } catch (_) {}
      return [];
    }
  }
}
