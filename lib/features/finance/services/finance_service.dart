import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/data/order_model.dart';

class FinanceService {
  final Dio _dio = ApiClient.instance;

  Future<void> approvePembayaran(dynamic pembayaranId, String status, {String? alasan}) async {
    try {
      final data = {
        'status_approval': status,
        if (alasan != null && status == 'rejected') 'alasan_penolakan': alasan,
      };
      await _dio.patch('/finance/pembayaran/$pembayaranId/approval', data: data);
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal memproses approval pembayaran');
      }
      throw Exception('Gagal memproses approval pembayaran: $e');
    }
  }

  Future<void> approvePembatalan(int pembatalanId) async {
    try {
      await _dio.patch('/finance/pembatalan/$pembatalanId/approval');
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal menyetujui pembatalan');
      }
      throw Exception('Gagal menyetujui pembatalan: $e');
    }
  }

  Future<void> approvePengajuanEdit(String identifier, String status, {String? alasan}) async {
    try {
      final data = {
        'status_approval': status,
        if (alasan != null && status == 'rejected') 'alasan_penolakan': alasan,
      };
      await _dio.patch('/finance/pengajuan-edit/$identifier/approval', data: data);
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal memproses approval pengajuan edit');
      }
      throw Exception('Gagal memproses approval pengajuan edit: $e');
    }
  }

  Future<OrderModel> updatePesanan(String pesananId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/finance/pesanan/$pesananId', data: data);
      return OrderModel.fromJson(response.data['data']);
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal memperbarui pesanan oleh Finance');
      }
      throw Exception('Gagal memperbarui pesanan oleh Finance: $e');
    }
  }

  Future<List<OrderModel>> fetchPendingPembayaran({String? search, int? cabangId, String? startDate, String? endDate}) async {
    try {
      final Map<String, dynamic> query = {};
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (cabangId != null) query['cabang_id'] = cabangId;
      if (startDate != null) query['tanggal_mulai'] = startDate;
      if (endDate != null) query['tanggal_selesai'] = endDate;
      
      final response = await _dio.get('/finance/pembayaran/pending', queryParameters: query);
      var responseData = response.data['data'] ?? response.data;
      if (responseData is Map && responseData.containsKey('data') && responseData['data'] is List) {
        responseData = responseData['data'];
      }
      
      final List data = responseData as List;
      return data.map((json) => OrderModel.fromJson(json)).toList();
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil data pembayaran pending');
      }
      throw Exception('Gagal mengambil data pembayaran pending: $e');
    }
  }

  Future<List<OrderModel>> fetchPembatalan({String? statusPesanan}) async {
    try {
      final Map<String, dynamic> query = {};
      if (statusPesanan != null) query['status_pesanan'] = statusPesanan;
      
      final response = await _dio.get('/finance/pembatalan', queryParameters: query);
      var responseData = response.data['data'] ?? response.data;
      if (responseData is Map && responseData.containsKey('data') && responseData['data'] is List) {
        responseData = responseData['data'];
      }
      
      final List data = responseData as List;
      return data.map((json) => OrderModel.fromJson(json)).toList();
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil data pembatalan');
      }
      throw Exception('Gagal mengambil data pembatalan: $e');
    }
  }

  Future<List<OrderModel>> fetchProcessedOrders({String? statusApproval}) async {
    try {
      final Map<String, dynamic> query = {};
      if (statusApproval != null) query['status_approval'] = statusApproval;
      
      final response = await _dio.get('/finance/pesanan/processed', queryParameters: query);
      var responseData = response.data['data'] ?? response.data;
      if (responseData is Map && responseData.containsKey('data') && responseData['data'] is List) {
        responseData = responseData['data'];
      }
      
      final List data = responseData as List;
      return data.map((json) => OrderModel.fromJson(json)).toList();
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil data pesanan diproses');
      }
      throw Exception('Gagal mengambil data pesanan diproses: $e');
    }
  }

  Future<Map<String, dynamic>> getLaporanOmzet({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      // Reusing the same endpoint used by Operasional for Omzet Dashboard
      final response = await _dio.get('/operasional/laporan-omzet', queryParameters: queryParams);
      return response.data;
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil laporan omzet');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<Map<String, dynamic>> fetchAuditPesanan({
    String? search,
    int? cabangId,
    String? statusPesanan,
    String? startDate,
    String? endDate,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
      };
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (cabangId != null) queryParams['cabang_id'] = cabangId;
      if (statusPesanan != null && statusPesanan.isNotEmpty) queryParams['status_pesanan'] = statusPesanan;
      if (startDate != null) queryParams['tanggal_mulai'] = startDate;
      if (endDate != null) queryParams['tanggal_selesai'] = endDate;

      final response = await _dio.get('/finance/audit-pesanan', queryParameters: queryParams);
      final data = response.data['data'];
      final items = (data['data'] as List).map((json) => OrderModel.fromJson(json)).toList();

      return {
        'items': items,
        'current_page': data['current_page'],
        'last_page': data['last_page'],
        'total': data['total'],
      };
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil data audit');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<Map<String, dynamic>> fetchPemasukan({
    String? search,
    int? cabangId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (cabangId != null) queryParams['cabang_id'] = cabangId;
      if (startDate != null) queryParams['tanggal_mulai'] = startDate;
      if (endDate != null) queryParams['tanggal_selesai'] = endDate;

      final response = await _dio.get('/finance/pemasukan', queryParameters: queryParams);
      return response.data['data']; // returns {total: xxx, items: [...]}
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil data pemasukan');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<List<dynamic>> fetchPengeluaran({
    String? search,
    int? cabangId,
    String? kategori,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (cabangId != null) queryParams['cabang_id'] = cabangId;
      if (kategori != null && kategori.isNotEmpty) queryParams['kategori'] = kategori;
      if (startDate != null) queryParams['tanggal_mulai'] = startDate;
      if (endDate != null) queryParams['tanggal_selesai'] = endDate;

      final response = await _dio.get('/finance/pengeluaran', queryParameters: queryParams);
      return response.data['data'];
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil data pengeluaran');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<Map<String, dynamic>> getSpendAds({
    String? periode,
    String? search,
    String? platform,
    int? cabangId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (periode != null && periode.isNotEmpty) queryParams['periode'] = periode;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (platform != null && platform.isNotEmpty) queryParams['platform'] = platform;
      if (cabangId != null) queryParams['cabang_id'] = cabangId;

      final response = await _dio.get('/marketing/spend-ads', queryParameters: queryParams);
      return response.data;
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil data spend ads');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<Map<String, dynamic>> storeSpendAd({
    required int cabangId,
    required String periode,
    required String platform,
    required double nominal,
  }) async {
    try {
      final response = await _dio.post('/marketing/spend-ads', data: {
        'cabang_id': cabangId,
        'periode': periode,
        'platform': platform,
        'nominal': nominal,
      });
      return response.data;
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal menyimpan spend ads');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<Map<String, dynamic>> updateSpendAd({
    required int id,
    int? cabangId,
    String? periode,
    String? platform,
    double? nominal,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (cabangId != null) data['cabang_id'] = cabangId;
      if (periode != null) data['periode'] = periode;
      if (platform != null) data['platform'] = platform;
      if (nominal != null) data['nominal'] = nominal;

      final response = await _dio.put('/marketing/spend-ads/$id', data: data);
      return response.data;
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal memperbarui spend ads');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }

  Future<Map<String, dynamic>> deleteSpendAd(int id) async {
    try {
      final response = await _dio.delete('/marketing/spend-ads/$id');
      return response.data;
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal menghapus spend ads');
      }
      throw Exception('Tidak dapat terhubung ke server');
    }
  }
}
