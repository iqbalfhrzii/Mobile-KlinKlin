import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class DesignerService {
  final Dio _apiClient = ApiClient.instance;

  // ================= PERMINTAAN DESIGN =================
  Future<Map<String, dynamic>> fetchPermintaanDesign({
    String? search,
    String? status,
    int page = 1,
    bool all = true,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'all': all ? 'true' : 'false',
      };
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (status != null && status.isNotEmpty && status != 'all' && status != 'Semua Status') {
        queryParams['status'] = status.toLowerCase();
      }

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

  Future<Map<String, dynamic>> updatePermintaanStatus(
    int id, {
    required String status,
    String? catatan,
    String? filePath,
  }) async {
    try {
      final data = <String, dynamic>{
        '_method': 'PUT',
        'status': status,
      };
      if (catatan != null) data['catatan_designer'] = catatan;

      final formData = FormData.fromMap(data);

      if (filePath != null && filePath.isNotEmpty) {
        formData.files.add(
          MapEntry(
            'lampiran_designer',
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

  // ================= ASET SOSMED =================
  Future<Map<String, dynamic>> fetchAsetSosmed({String? search}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _apiClient.get(
        '/designer/aset-sosmed',
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

  Future<Map<String, dynamic>> storeAsetSosmed(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(
        '/designer/aset-sosmed',
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

  Future<Map<String, dynamic>> updateAsetSosmed(int id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.put(
        '/designer/aset-sosmed/$id',
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

  Future<Map<String, dynamic>> deleteAsetSosmed(int id) async {
    try {
      final response = await _apiClient.delete('/designer/aset-sosmed/$id');
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
