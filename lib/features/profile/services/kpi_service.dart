import '../../../core/api/api_client.dart';

class KpiService {
  Future<Map<String, dynamic>> getKpiCs({int? bulan, int? tahun}) async {
    final now = DateTime.now();
    final b = bulan ?? now.month;
    final t = tahun ?? now.year;

    try {
      final response = await ApiClient.instance.get('/kpi-cs', queryParameters: {'bulan': b, 'tahun': t});
      return response.data['data'] ?? {};
    } catch (e) {
      throw Exception('Gagal memuat data KPI: $e');
    }
  }
}
