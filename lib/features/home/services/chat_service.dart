import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class ChatService {
  Future<List<dynamic>> getChatHarian({int limit = 7}) async {
    try {
      final response = await ApiClient.instance.get('/chat-harian', queryParameters: {'limit': limit});
      return response.data['data'] ?? [];
    } catch (e) {
      throw Exception('Gagal memuat data chat harian: $e');
    }
  }

  Future<Map<String, dynamic>> submitChatHarian({
    required DateTime date,
    required int custBaruOrganik,
    required int custBaruIklan,
    required int custLama,
    required int closingOrganik,
    required int closingIklan,
    required int closingLama,
    required int jumlahOrderan,
    required int telp,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        '/chat-harian',
        data: {
          'tanggal': date.toIso8601String().split('T')[0],
          'cust_baru_organik': custBaruOrganik,
          'cust_baru_iklan': custBaruIklan,
          'cust_lama': custLama,
          'closing_cust_baru_organik': closingOrganik,
          'closing_cust_baru_iklan': closingIklan,
          'closing_cust_lama': closingLama,
          'jumlah_orderan': jumlahOrderan,
          'telp': telp,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Gagal menyimpan data chat harian');
    }
  }
}
