import '../../../core/api/api_client.dart';
import 'package:dio/dio.dart';

class OperasionalQuotationService {
  final Dio _apiClient = ApiClient.instance;

  Future<Map<String, dynamic>> getQuotations({
    String? search,
    String? status,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;

      final response = await _apiClient.get(
        '/operasional/quotation',
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

  Future<Map<String, dynamic>> getQuotationDetail(int id) async {
    try {
      final response = await _apiClient.get('/operasional/quotation/$id');
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

  Future<Map<String, dynamic>> storeQuotation(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post('/operasional/quotation', data: data);
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

  Future<Map<String, dynamic>> updateQuotation(int id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post('/operasional/quotation/$id', data: data); // Laravel handles PUT via POST with _method=PUT or just PUT
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

  Future<Map<String, dynamic>> deleteQuotation(int id) async {
    try {
      final response = await _apiClient.delete('/operasional/quotation/$id');
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
}
