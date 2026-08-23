import '../../../core/api/api_client.dart';
import 'package:dio/dio.dart';

class OperasionalQuotationService {
  final Dio _apiClient = ApiClient.instance;

  String _extractErrorMessage(dynamic e) {
    if (e is DioException) {
      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map) {
          if (data['errors'] != null && data['errors'] is Map) {
            final Map errMap = data['errors'];
            final List<String> messages = [];
            errMap.forEach((key, value) {
              if (value is List) {
                messages.add('$key: ${value.join(", ")}');
              } else {
                messages.add('$key: $value');
              }
            });
            if (messages.isNotEmpty) {
              return messages.join('\n');
            }
          }
          if (data['message'] != null && data['message'].toString().isNotEmpty) {
            return data['message'].toString();
          }
          if (data['error'] != null && data['error'].toString().isNotEmpty) {
            return data['error'].toString();
          }
        } else if (data is String && data.isNotEmpty) {
          return data;
        }
      }
      if (e.message != null && e.message!.isNotEmpty) {
        return e.message!;
      }
    }
    return e.toString().replaceAll('Exception: ', '');
  }

  Future<Map<String, dynamic>> getQuotations({
    String? search,
    String? status,
    int? cabangId,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (cabangId != null) queryParams['cabang_id'] = cabangId;

      final response = await _apiClient.get(
        '/operasional/quotation',
        queryParameters: queryParams,
      );
      
      return response.data;
    } catch (e) {
      return {
        'status': false,
        'message': _extractErrorMessage(e),
      };
    }
  }

  Future<List<dynamic>> getCabangs() async {
    try {
      final response = await _apiClient.get('/cabangs');
      if (response.data is List) {
        return response.data;
      } else if (response.data['data'] is List) {
        return response.data['data'];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> approveQuotation(int id, {String? notes}) async {
    try {
      final response = await _apiClient.post(
        '/operasional/quotation/$id/approve',
        data: {'catatan_persetujuan': notes},
      );
      return response.data;
    } catch (e) {
      return {
        'status': false,
        'message': _extractErrorMessage(e),
      };
    }
  }

  Future<Map<String, dynamic>> rejectQuotation(int id, {String? notes}) async {
    try {
      final response = await _apiClient.post(
        '/operasional/quotation/$id/reject',
        data: {'catatan_persetujuan': notes},
      );
      return response.data;
    } catch (e) {
      return {
        'status': false,
        'message': _extractErrorMessage(e),
      };
    }
  }

  Future<Map<String, dynamic>> getQuotationDetail(int id) async {
    try {
      final response = await _apiClient.get('/operasional/quotation/$id');
      return response.data;
    } catch (e) {
      return {
        'status': false,
        'message': _extractErrorMessage(e),
      };
    }
  }

  Future<Map<String, dynamic>> storeQuotation(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post('/operasional/quotation', data: data);
      return response.data;
    } catch (e) {
      return {
        'status': false,
        'message': _extractErrorMessage(e),
      };
    }
  }

  Future<Map<String, dynamic>> updateQuotation(int id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.put('/operasional/quotation/$id', data: data);
      return response.data;
    } catch (e) {
      return {
        'status': false,
        'message': _extractErrorMessage(e),
      };
    }
  }

  Future<Map<String, dynamic>> deleteQuotation(int id) async {
    try {
      final response = await _apiClient.delete('/operasional/quotation/$id');
      return response.data;
    } catch (e) {
      return {
        'status': false,
        'message': _extractErrorMessage(e),
      };
    }
  }
}
