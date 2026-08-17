import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../../core/api/api_client.dart';
import 'dart:io';

class OperasionalPurchaseOrderService {
  static final Dio _dio = ApiClient.instance;

  static Future<Map<String, dynamic>> getPurchaseOrders({
    int page = 1,
    String? search,
    int? cabangId,
    String? status,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'page': page,
        'per_page': 20,
      };

      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (cabangId != null) queryParams['cabang_id'] = cabangId;
      if (status != null && status.isNotEmpty && status != 'Semua Status') {
        queryParams['status'] = status;
      }

      final response = await _dio.get(
        '/operasional/purchase-orders',
        queryParameters: queryParams,
      );

      return response.data;
    } catch (e) {
      print('Error OperasionalPurchaseOrderService.getPurchaseOrders: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createPurchaseOrder(Map<String, dynamic> data, {File? file}) async {
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
            'file_po',
            await MultipartFile.fromFile(
              file.path,
              filename: fileName,
              contentType: MediaType.parse(contentType),
            ),
          ),
        );
      }

      final response = await _dio.post(
        '/operasional/purchase-orders',
        data: formData,
      );

      return response.data;
    } catch (e) {
      print('Error OperasionalPurchaseOrderService.createPurchaseOrder: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updatePurchaseOrder(int id, Map<String, dynamic> data, {File? file}) async {
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
            'file_po',
            await MultipartFile.fromFile(
              file.path,
              filename: fileName,
              contentType: MediaType.parse(contentType),
            ),
          ),
        );
      }

      // We use POST to allow laravel multipart file upload with method spoofing in query params or we can use POST directly since our route accepts POST for updates.
      final response = await _dio.post(
        '/operasional/purchase-orders/$id',
        data: formData,
      );

      return response.data;
    } catch (e) {
      print('Error OperasionalPurchaseOrderService.updatePurchaseOrder: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> deletePurchaseOrder(int id) async {
    try {
      final response = await _dio.delete('/operasional/purchase-orders/$id');
      return response.data;
    } catch (e) {
      print('Error OperasionalPurchaseOrderService.deletePurchaseOrder: $e');
      rethrow;
    }
  }
}
