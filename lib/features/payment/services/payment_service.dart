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
    required bool usePph,
    required int totalTagihan,
    required int totalSetelahDiskon,
    required int totalAkhir,
    required dynamic buktiTransfer, // File or List<File>
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) throw Exception('Sesi telah berakhir, silakan login kembali.');

      final List<File> files = [];
      if (buktiTransfer is List<File>) {
        files.addAll(buktiTransfer);
      } else if (buktiTransfer is File) {
        files.add(buktiTransfer);
      }

      final Map<String, dynamic> formMap = {
        'metode_pembayaran': metodePembayaran,
        'diskon_persen': diskonPersen,
        'ppn': ppn,
        'use_ppn': ppn > 0 ? 1 : 0,
        'use_pph': usePph ? 1 : 0,
        'total_tagihan': totalTagihan,
        'total_setelah_diskon': totalSetelahDiskon,
        'total_akhir': totalAkhir,
      };

      if (files.isNotEmpty) {
        final f1 = files[0];
        formMap['bukti_transfer'] = await MultipartFile.fromFile(
          f1.path,
          filename: f1.path.split(r'/').last.split(r'\').last,
        );
      }

      if (files.length > 1) {
        final f2 = files[1];
        formMap['bukti_transfer_2'] = await MultipartFile.fromFile(
          f2.path,
          filename: f2.path.split(r'/').last.split(r'\').last,
        );
      }

      FormData formData = FormData.fromMap(formMap);
      await _dio.post(
        '/pesanan/$orderId/pembayaran',
        data: formData,
        options: Options(
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 120),
        ),
      );
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
