import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class OperasionalService {
  final Dio _dio = ApiClient.instance;

  Future<Map<String, dynamic>> getLaporanOmzet({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final response = await _dio.get('/operasional/laporan-omzet', queryParameters: queryParams);
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil laporan omzet');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<Map<String, dynamic>> getReportKpi({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final response = await _dio.get('/operasional/report-kpi', queryParameters: queryParams);
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil report KPI');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<Map<String, dynamic>> getKpiCs({
    int? bulan,
    int? tahun,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (bulan != null) queryParams['bulan'] = bulan;
      if (tahun != null) queryParams['tahun'] = tahun;

      final response = await _dio.get('/operasional/kpi-cs', queryParameters: queryParams);
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil data KPI CS');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<Map<String, dynamic>> updateKpiCs(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/operasional/kpi-cs/update', data: data);
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Gagal menyimpan data KPI CS');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<Map<String, dynamic>> getDataChat({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final response = await _dio.get('/operasional/data-chat', queryParameters: queryParams);
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil Data Chat');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<Map<String, dynamic>> getCabangs() async {
    try {
      final response = await _dio.get('/operasional/cabangs');
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil data cabang');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<Map<String, dynamic>> updateKantor(int cabangId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/operasional/cabangs/$cabangId/kantor', data: data);
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Gagal memperbarui kantor');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<Map<String, dynamic>> updateTargetOmzet(int cabangId, double targetOmzet) async {
    try {
      final response = await _dio.put('/operasional/cabangs/$cabangId/target-omzet', data: {
        'target_omzet': targetOmzet
      });
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Gagal memperbarui target omzet');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<Map<String, dynamic>> getSemuaOrder({
    String? search,
    int? cabangId,
    String? status,
    String? periode,
    String? startDate,
    String? endDate,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (cabangId != null) queryParams['cabang_id'] = cabangId;
      if (status != null && status.isNotEmpty) queryParams['status_order_utama'] = status;
      if (startDate != null && startDate.isNotEmpty) queryParams['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty) queryParams['end_date'] = endDate;
      if (periode != null && periode.isNotEmpty) queryParams['periode'] = periode;

      final response = await _dio.get('/pesanan', queryParameters: queryParams);
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil data order');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }
}
