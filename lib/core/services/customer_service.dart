import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../data/customer_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerService {
  static final Dio _dio = ApiClient.instance;

  static Future<List<CustomerModel>> getCustomers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cabangId = prefs.getInt('user_cabang_id');

      final response = await _dio.get('/pelanggans', queryParameters: cabangId != null ? {'cabang_id': cabangId} : null);
      var data = response.data['data'] as List;
      
      // Local fallback filter if API doesn't support query params
      if (cabangId != null) {
        data = data.where((e) {
          final cid = e['cabang_id'];
          if (cid == null) return true; // If no cabang_id in data, include it to be safe
          return cid.toString() == cabangId.toString();
        }).toList();
      }

      return data.map((e) => CustomerModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Gagal memuat data pelanggan');
    }
  }

  static Future<CustomerModel> addCustomer(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cabangId = prefs.getInt('user_cabang_id') ?? 1;
      data['cabang_id'] = cabangId;

      final response = await _dio.post('/pelanggans', data: data);
      return CustomerModel.fromJson(response.data['data']);
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final message = e.response?.data['message'] ?? 'Gagal menambah pelanggan';
        throw Exception(message);
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  static Future<CustomerModel> updateCustomer(String id, Map<String, dynamic> data) async {
    try {
      final realId = id.replaceAll('PLG-', '');
      final response = await _dio.put('/pelanggans/$realId', data: data);
      return CustomerModel.fromJson(response.data['data']);
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final message = e.response?.data['message'] ?? 'Gagal memperbarui pelanggan';
        throw Exception(message);
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  static Future<CustomerModel> updateCustomerStatus(String id, String newStatus, Map<String, dynamic> existingData) async {
    try {
      final payload = Map<String, dynamic>.from(existingData);
      payload['status'] = newStatus;
      final realId = id.replaceAll('PLG-', '');
      final response = await _dio.put('/pelanggans/$realId', data: payload);
      return CustomerModel.fromJson(response.data['data']);
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengubah status pelanggan');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }
}
