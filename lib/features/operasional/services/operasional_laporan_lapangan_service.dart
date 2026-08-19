import '../../../core/api/api_client.dart';
import 'package:dio/dio.dart';

class OperasionalLaporanLapanganService {
  final Dio _apiClient = ApiClient.instance;

  Future<Map<String, dynamic>> getLaporanLapangan({
    String? search,
    String? cabangId,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (cabangId != null && cabangId != 'all') queryParams['cabang_id'] = cabangId;

      final response = await _apiClient.get(
        '/operasional/lapangan',
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

  Future<Map<String, dynamic>> getLaporanLapanganDetail(int id) async {
    try {
      final response = await _apiClient.get('/operasional/lapangan/$id');
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

  Future<Map<String, dynamic>> storeLaporanLapangan(Map<String, dynamic> data, {String? filePath}) async {
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
        '/operasional/lapangan', 
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

  Future<Map<String, dynamic>> updateLaporanLapangan(int id, Map<String, dynamic> data, {String? filePath}) async {
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
        '/operasional/lapangan/$id', 
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

  Future<Map<String, dynamic>> deleteLaporanLapangan(int id) async {
    try {
      final response = await _apiClient.delete('/operasional/lapangan/$id');
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
