import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/data/order_model.dart';

class FinanceService {
  final Dio _dio = ApiClient.instance;

  Future<void> approvePembayaran(int pembayaranId, String status, {String? alasan}) async {
    try {
      final data = {
        'status_approval': status,
        if (alasan != null && status == 'rejected') 'alasan_penolakan': alasan,
      };
      await _dio.patch('/finance/pembayaran/$pembayaranId/approval', data: data);
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal memproses approval pembayaran');
      }
      throw Exception('Gagal memproses approval pembayaran: $e');
    }
  }

  Future<void> approvePembatalan(int pembatalanId) async {
    try {
      await _dio.patch('/finance/pembatalan/$pembatalanId/approval');
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal menyetujui pembatalan');
      }
      throw Exception('Gagal menyetujui pembatalan: $e');
    }
  }

  Future<List<OrderModel>> fetchPembatalan({String? statusPesanan}) async {
    try {
      final Map<String, dynamic> query = {};
      if (statusPesanan != null) query['status_pesanan'] = statusPesanan;
      
      final response = await _dio.get('/finance/pembatalan', queryParameters: query);
      var responseData = response.data['data'] ?? response.data;
      if (responseData is Map && responseData.containsKey('data') && responseData['data'] is List) {
        responseData = responseData['data'];
      }
      
      final List data = responseData as List;
      return data.map((json) => OrderModel.fromJson(json)).toList();
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil data pembatalan');
      }
      throw Exception('Gagal mengambil data pembatalan: $e');
    }
  }

  Future<List<OrderModel>> fetchProcessedOrders({String? statusApproval}) async {
    try {
      final Map<String, dynamic> query = {};
      if (statusApproval != null) query['status_approval'] = statusApproval;
      
      final response = await _dio.get('/finance/pesanan/processed', queryParameters: query);
      var responseData = response.data['data'] ?? response.data;
      if (responseData is Map && responseData.containsKey('data') && responseData['data'] is List) {
        responseData = responseData['data'];
      }
      
      final List data = responseData as List;
      return data.map((json) => OrderModel.fromJson(json)).toList();
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil data pesanan diproses');
      }
      throw Exception('Gagal mengambil data pesanan diproses: $e');
    }
  }
}
