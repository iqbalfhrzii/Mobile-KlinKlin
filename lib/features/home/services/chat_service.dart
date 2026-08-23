import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class ChatService {
  final Dio _dio = ApiClient.instance;

  Future<List<dynamic>> getChatHarian({int? limit, String? periode}) async {
    try {
      final Map<String, dynamic> params = {};
      if (limit != null) params['limit'] = limit;
      if (periode != null && periode != 'semua') params['periode'] = periode;

      final response = await _dio.get('/chat-harian', queryParameters: params);
      final raw = response.data;
      if (raw is Map && raw['data'] is List) {
        return raw['data'] as List<dynamic>;
      } else if (raw is List) {
        return raw;
      }
      return [];
    } catch (e) {
      throw Exception('Gagal memuat data chat harian: $e');
    }
  }

  Future<Map<String, dynamic>> submitChatHarian({
    int? id,
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
      final data = {
        if (id != null) 'id': id,
        'tanggal': "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
        'cust_baru_organik': custBaruOrganik,
        'cust_baru_iklan': custBaruIklan,
        'cust_lama': custLama,
        'closing_cust_baru_organik': closingOrganik,
        'closing_cust_baru_iklan': closingIklan,
        'closing_cust_lama': closingLama,
        'jumlah_orderan': jumlahOrderan,
        'telp': telp,
      };

      final response = await _dio.post('/chat-harian', data: data);
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Gagal menyimpan data chat harian');
    }
  }

  Future<Map<String, dynamic>> updateChatHarian(
    int id, {
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
      final response = await _dio.put(
        '/chat-harian/$id',
        data: {
          'tanggal': "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
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
      throw Exception(e.response?.data['message'] ?? 'Gagal memperbarui data chat harian');
    }
  }

  Future<void> deleteChatHarian(int id) async {
    try {
      await _dio.delete('/chat-harian/$id');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Gagal menghapus data chat harian');
    }
  }
}
