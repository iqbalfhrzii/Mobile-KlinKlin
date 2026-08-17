import '../../../core/api/api_client.dart';
import 'package:dio/dio.dart';

class OperasionalDataKecelakaanService {
  final Dio _apiClient = ApiClient.instance;

  Future<Map<String, dynamic>> getDataKecelakaan({
    String? search,
    String? cabangId,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (cabangId != null && cabangId != 'all') queryParams['cabang_id'] = cabangId;

      final response = await _apiClient.get(
        '/operasional/data-kecelakaan',
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

  Future<Map<String, dynamic>> getDataKecelakaanDetail(int id) async {
    try {
      final response = await _apiClient.get('/operasional/data-kecelakaan/$id');
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

  Future<Map<String, dynamic>> storeDataKecelakaan(Map<String, dynamic> data, {String? filePath}) async {
    try {
      FormData formData = FormData.fromMap(data);
      
      if (filePath != null && filePath.isNotEmpty) {
        formData.files.add(
          MapEntry(
            'file_foto',
            await MultipartFile.fromFile(filePath, filename: filePath.split('/').last),
          ),
        );
      }

      final response = await _apiClient.post(
        '/operasional/data-kecelakaan', 
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

  Future<Map<String, dynamic>> updateDataKecelakaan(int id, Map<String, dynamic> data, {String? filePath}) async {
    try {
      data['_method'] = 'PUT'; // Laravel requires this for multipart/form-data PUT requests
      FormData formData = FormData.fromMap(data);
      
      if (filePath != null && filePath.isNotEmpty) {
        formData.files.add(
          MapEntry(
            'file_foto',
            await MultipartFile.fromFile(filePath, filename: filePath.split('/').last),
          ),
        );
      }

      final response = await _apiClient.post(
        '/operasional/data-kecelakaan/$id', 
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

  Future<Map<String, dynamic>> deleteDataKecelakaan(int id) async {
    try {
      final response = await _apiClient.delete('/operasional/data-kecelakaan/$id');
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
