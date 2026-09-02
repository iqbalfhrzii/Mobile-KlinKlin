import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardService {
  final Dio _dio = ApiClient.instance;

  Future<Map<String, dynamic>> fetchCsDashboard({
    String? periode,
    String? tanggalMulai,
    String? tanggalSelesai,
    int? cabangId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userCabangId = cabangId ?? prefs.getInt('user_cabang_id') ?? prefs.getString('user_cabang_id');
      
      final queryParams = <String, dynamic>{};
      if (userCabangId != null && userCabangId.toString().isNotEmpty && userCabangId.toString() != '-') {
        queryParams['cabang_id'] = userCabangId.toString();
      }
      if (periode != null) {
        queryParams['periode'] = periode;
      }
      if (tanggalMulai != null) {
        queryParams['tanggal_mulai'] = tanggalMulai;
      }
      if (tanggalSelesai != null) {
        queryParams['tanggal_selesai'] = tanggalSelesai;
      }
      
      final response = await _dio.get('/dashboard/cs', queryParameters: queryParams);
      if (response.statusCode == 200 && response.data['status'] == true) {
        final data = response.data['data'];
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
      }
      return {};
    } catch (e) {
      return {};
    }
  }
}
