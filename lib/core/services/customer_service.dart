import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../data/customer_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerService {
  static final Dio _dio = ApiClient.instance;

  static Future<List<CustomerModel>> getCustomers() async {
    try {
      final response = await _dio.get('/pelanggans');
      final data = response.data['data'] as List;
      return data.map((e) => CustomerModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Gagal memuat data pelanggan');
    }
  }

  static Future<CustomerModel> addCustomer(Map<String, dynamic> data) async {
    try {
      // API requires cabang_id, so we pull it from shared preferences or default to 1
      final prefs = await SharedPreferences.getInstance();
      final branchStr = prefs.getString('user_branch'); // Actually we just default to 1 since we don't have branch id saved.
      // Override or add cabang_id
      data['cabang_id'] = 1; // Assuming default branch ID = 1 for now

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
