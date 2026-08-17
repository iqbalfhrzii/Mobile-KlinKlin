import '../../../core/api/api_client.dart';
import 'package:dio/dio.dart';

class OperasionalStrategiRapatService {
  final Dio _apiClient = ApiClient.instance;

  Future<Map<String, dynamic>> getStrategiRapat({
    String? search,
    String? cabangId,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (cabangId != null && cabangId != 'all') queryParams['cabang_id'] = cabangId;

      final response = await _apiClient.get(
        '/operasional/strategi-rapat',
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

  Future<Map<String, dynamic>> getStrategiRapatDetail(int id) async {
    try {
      final response = await _apiClient.get('/operasional/strategi-rapat/$id');
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

  Future<Map<String, dynamic>> storeStrategiRapat(Map<String, dynamic> data, {String? filePath}) async {
    try {
      FormData formData = FormData.fromMap(data);
      
      if (filePath != null && filePath.isNotEmpty) {
        formData.files.add(
          MapEntry(
            'file_lampiran',
            await MultipartFile.fromFile(filePath, filename: filePath.split('/').last),
          ),
        );
      }

      final response = await _apiClient.post(
        '/operasional/strategi-rapat', 
        data: formData,
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

  Future<Map<String, dynamic>> updateStrategiRapat(int id, Map<String, dynamic> data, {String? filePath}) async {
    try {
      data['_method'] = 'PUT'; // Laravel requires this for multipart/form-data PUT requests
      FormData formData = FormData.fromMap(data);
      
      if (filePath != null && filePath.isNotEmpty) {
        formData.files.add(
          MapEntry(
            'file_lampiran',
            await MultipartFile.fromFile(filePath, filename: filePath.split('/').last),
          ),
        );
      }

      final response = await _apiClient.post(
        '/operasional/strategi-rapat/$id', 
        data: formData,
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

  Future<Map<String, dynamic>> deleteStrategiRapat(int id) async {
    try {
      final response = await _apiClient.delete('/operasional/strategi-rapat/$id');
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
