import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardService {
  final Dio _dio = ApiClient.instance;

  Future<Map<String, dynamic>> fetchCsDashboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cabangId = prefs.getString('user_cabang_id');
      
      final queryParams = <String, dynamic>{};
      if (cabangId != null && cabangId.isNotEmpty && cabangId != '-') {
        queryParams['cabang_id'] = cabangId;
      }
      
      final response = await _dio.get('/dashboard/cs', queryParameters: queryParams);
      if (response.statusCode == 200 && response.data['status'] == true) {
        return response.data['data'];
      }
      return {};
    } catch (e) {
      print('Error fetching CS dashboard: $e');
      return {};
    }
  }
}
