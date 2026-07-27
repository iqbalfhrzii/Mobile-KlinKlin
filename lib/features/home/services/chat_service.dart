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
    required int organik,
    required int ads,
    required int lama,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        '/chat-harian',
        data: {
          'tanggal': date.toIso8601String().split('T')[0],
          'chat_organik': organik,
          'chat_ads': ads,
          'chat_lama': lama,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Gagal menyimpan data chat harian');
    }
  }
}
