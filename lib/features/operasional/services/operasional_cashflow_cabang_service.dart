import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../../core/api/api_client.dart';
import 'dart:io';

class OperasionalCashflowCabangService {
  static final Dio _dio = ApiClient.instance;

  static Future<Map<String, dynamic>> getCabangs() async {
    try {
      final response = await _dio.get('/operasional/cabangs');
      return response.data;
    } catch (e) {
      print('Error OperasionalCashflowCabangService.getCabangs: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getCashflow({
    int page = 1,
    String? search,
    int? cabangId,
    String? arus,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'page': page,
        'per_page': 20,
      };

      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (cabangId != null) queryParams['cabang_id'] = cabangId;
      if (arus != null && arus.isNotEmpty && arus != 'Semua Arus') {
        queryParams['arus'] = arus;
      }

      final response = await _dio.get(
        '/operasional/cashflow-cabang',
        queryParameters: queryParams,
      );

      return response.data;
    } catch (e) {
      print('Error OperasionalCashflowCabangService.getCashflow: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createCashflow(Map<String, dynamic> data, {File? file}) async {
    try {
      final formData = FormData.fromMap(data);

      if (file != null) {
        String fileName = file.path.split('/').last;
        String ext = fileName.split('.').last.toLowerCase();
        String contentType = 'application/octet-stream';
        
        if (ext == 'jpg' || ext == 'jpeg') contentType = 'image/jpeg';
        else if (ext == 'png') contentType = 'image/png';
        else if (ext == 'pdf') contentType = 'application/pdf';

        formData.files.add(
          MapEntry(
            'bukti',
            await MultipartFile.fromFile(
              file.path,
              filename: fileName,
              contentType: MediaType.parse(contentType),
            ),
          ),
        );
      }

      final response = await _dio.post(
        '/operasional/cashflow-cabang',
        data: formData,
      );

      return response.data;
    } catch (e) {
      print('Error OperasionalCashflowCabangService.createCashflow: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateCashflow(int id, Map<String, dynamic> data, {File? file}) async {
    try {
      final formData = FormData.fromMap(data);

      if (file != null) {
        String fileName = file.path.split('/').last;
        String ext = fileName.split('.').last.toLowerCase();
        String contentType = 'application/octet-stream';
        
        if (ext == 'jpg' || ext == 'jpeg') contentType = 'image/jpeg';
        else if (ext == 'png') contentType = 'image/png';
        else if (ext == 'pdf') contentType = 'application/pdf';

        formData.files.add(
          MapEntry(
            'bukti',
            await MultipartFile.fromFile(
              file.path,
              filename: fileName,
              contentType: MediaType.parse(contentType),
            ),
          ),
        );
      }

      final response = await _dio.post(
        '/operasional/cashflow-cabang/$id',
        data: formData,
      );

      return response.data;
    } catch (e) {
      print('Error OperasionalCashflowCabangService.updateCashflow: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> deleteCashflow(int id) async {
    try {
      final response = await _dio.delete('/operasional/cashflow-cabang/$id');
      return response.data;
    } catch (e) {
      print('Error OperasionalCashflowCabangService.deleteCashflow: $e');
      rethrow;
    }
  }
}
