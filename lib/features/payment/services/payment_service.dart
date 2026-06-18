import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import 'dart:io';

class PaymentService {
  final Dio _dio;

  PaymentService() : _dio = ApiClient.instance;

  Future<void> submitPayment({
    required String orderId,
    required String metodePembayaran,
    required int diskonPersen,
    required int ppn,
    required int totalTagihan,
    required int totalSetelahDiskon,
    required int totalAkhir,
    required File buktiTransfer,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) throw Exception('Sesi telah berakhir, silakan login kembali.');

      String fileName = buktiTransfer.path.split('/').last;

      FormData formData = FormData.fromMap({
        'metode_pembayaran': metodePembayaran,
        'diskon_persen': diskonPersen,
        'ppn': ppn,
        'total_tagihan': totalTagihan,
        'total_setelah_diskon': totalSetelahDiskon,
        'total_akhir': totalAkhir,
        'bukti_transfer': await MultipartFile.fromFile(
          buktiTransfer.path,
          filename: fileName,
        ),
      });

      await _dio.post('/pesanan/$orderId/pembayaran', data: formData);
    } catch (e) {
      if (e is DioException) {
        final data = e.response?.data;
        String errMsg = e.message ?? 'Terjadi kesalahan koneksi';
        if (data is Map<String, dynamic>) {
          errMsg = data['message'] ?? data.toString();
        } else if (data != null) {
          errMsg = data.toString();
        }
        throw Exception(errMsg);
      }
      throw Exception('Gagal mengirim data pembayaran: $e');
    }
  }
}
