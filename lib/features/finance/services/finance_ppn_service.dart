import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class FinancePpnService {
  final Dio _dio = ApiClient.instance;

  Future<List<Map<String, dynamic>>> fetchCabangPpnSettings() async {
    try {
      final response = await _dio.get('/finance/pengaturan-ppn');
      if (response.data != null && response.data['data'] != null) {
        final List list = response.data['data'];
        return list.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Gagal memuat pengaturan PPN cabang: $e');
    }
  }

  Future<bool> saveCabangPpnSettings(Map<int, bool> settings) async {
    try {
      final payload = {
        'settings': settings.map((key, value) => MapEntry(key.toString(), value)),
      };
      final response = await _dio.post('/finance/pengaturan-ppn', data: payload);
      return response.data?['status'] == true;
    } catch (e) {
      throw Exception('Gagal menyimpan pengaturan PPN cabang: $e');
    }
  }
}
