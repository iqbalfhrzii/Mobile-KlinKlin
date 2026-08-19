import '../../../core/api/api_client.dart';
import 'package:dio/dio.dart';

class OperasionalPermintaanDesignService {
  final Dio _apiClient = ApiClient.instance;

  Future<Map<String, dynamic>> getPermintaanDesign({
    String? search,
    String? status,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (status != null && status.isNotEmpty && status != 'all') queryParams['status'] = status;

      final response = await _apiClient.get(
        '/operasional/permintaan-design',
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

  Future<Map<String, dynamic>> storePermintaanDesign(Map<String, dynamic> data, {String? filePath}) async {
    try {
      FormData formData = FormData.fromMap(data);

      if (filePath != null && filePath.isNotEmpty) {
        formData.files.add(
          MapEntry(
            'lampiran_pengirim',
            await MultipartFile.fromFile(filePath, filename: filePath.split('/').last.split('\\').last),
          ),
        );
      }

      final response = await _apiClient.post(
        '/operasional/permintaan-design',
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

  Future<Map<String, dynamic>> updatePermintaanDesign(int id, Map<String, dynamic> data, {String? filePath}) async {
    try {
      data['_method'] = 'PUT';
      FormData formData = FormData.fromMap(data);

      if (filePath != null && filePath.isNotEmpty) {
        formData.files.add(
          MapEntry(
            'lampiran_pengirim',
            await MultipartFile.fromFile(filePath, filename: filePath.split('/').last.split('\\').last),
          ),
        );
      }

      final response = await _apiClient.post(
        '/operasional/permintaan-design/$id',
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

  Future<Map<String, dynamic>> deletePermintaanDesign(int id) async {
    try {
      final response = await _apiClient.delete('/operasional/permintaan-design/$id');
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
