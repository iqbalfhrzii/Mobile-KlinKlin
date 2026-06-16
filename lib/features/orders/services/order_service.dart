import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/data/order_model.dart';

class OrderService {
  final Dio _dio = ApiClient.instance;

  /// Get all orders
  Future<List<OrderModel>> fetchOrders({
    String? statusPesanan,
    int? cabangId,
    String? chatDari,
    String? tipeCustomer,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (statusPesanan != null && statusPesanan != 'Semua') {
        // Map back to API expected string if needed, but the UI might pass raw names
        queryParams['status_pesanan'] = statusPesanan;
      }
      if (cabangId != null) queryParams['cabang_id'] = cabangId;
      if (chatDari != null) queryParams['chat_dari'] = chatDari;
      if (tipeCustomer != null) queryParams['tipe_customer'] = tipeCustomer;

      final response = await _dio.get('/pesanan', queryParameters: queryParams);
      var responseData = response.data['data'] ?? response.data;
      
      // Jika responseData berupa Map (biasanya karena Pagination Laravel), ambil field 'data' di dalamnya
      if (responseData is Map && responseData.containsKey('data') && responseData['data'] is List) {
        responseData = responseData['data'];
      }
      
      final List data = responseData as List;
      return data.map((json) => OrderModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Gagal mengambil data pesanan: $e');
    }
  }

  /// Get single order details
  Future<OrderModel> fetchOrderDetail(String id) async {
    try {
      final response = await _dio.get('/pesanan/$id');
      final data = response.data['data'] ?? response.data;
      return OrderModel.fromJson(data);
    } catch (e) {
      throw Exception('Gagal mengambil detail pesanan: $e');
    }
  }

  /// Update order
  Future<void> updateOrder(String id, OrderDraft draft) async {
    try {
      await _dio.put('/pesanan/$id', data: draft.toJson());
    } catch (e) {
      throw Exception('Gagal menyimpan perubahan pesanan: $e');
    }
  }

  /// Create order
  Future<void> createOrder(OrderDraft draft) async {
    try {
      await _dio.post('/pesanan', data: draft.toJson());
    } catch (e) {
      throw Exception('Gagal membuat pesanan baru: $e');
    }
  }
}
