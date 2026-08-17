import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class OperasionalApprovalPengajuanService {
  static final Dio _dio = ApiClient.instance;

  static Future<Map<String, dynamic>> getPengajuan({
    String? status,
    int? cabangId,
    String? search,
    String? startDate,
    String? endDate,
    int page = 1,
  }) async {
    try {
      final Map<String, dynamic> params = {'page': page};
      if (status != null) params['status'] = status;
      if (cabangId != null) params['cabang_id'] = cabangId;
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (startDate != null && startDate.isNotEmpty) params['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty) params['end_date'] = endDate;

      final response = await _dio.get(
        '/api/operasional/approval-pengajuan',
        queryParameters: params,
      );
      
      // Ensure the correct pagination format
      if (response.data != null && response.data['data'] != null) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return {};
    } on DioException catch (e) {
      print('OperasionalApprovalPengajuanService.getPengajuan DioException: $e');
      throw Exception(e.response?.data['message'] ?? 'Gagal mengambil data pengajuan');
    } catch (e) {
      print('OperasionalApprovalPengajuanService.getPengajuan Error: $e');
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  static Future<bool> approvePengajuan({
    required int id,
    required int jumlahDisetujui,
    String? catatanPersetujuan,
  }) async {
    try {
      final response = await _dio.post(
        '/api/operasional/approval-pengajuan/$id/approve',
        data: {
          'jumlah_disetujui': jumlahDisetujui,
          'catatan_persetujuan': catatanPersetujuan,
        },
      );
      return response.data['status'] == true;
    } on DioException catch (e) {
      print('OperasionalApprovalPengajuanService.approvePengajuan DioException: $e');
      throw Exception(e.response?.data['message'] ?? 'Gagal menyetujui pengajuan');
    } catch (e) {
      print('OperasionalApprovalPengajuanService.approvePengajuan Error: $e');
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  static Future<bool> rejectPengajuan({
    required int id,
    required String catatanPersetujuan,
  }) async {
    try {
      final response = await _dio.post(
        '/api/operasional/approval-pengajuan/$id/reject',
        data: {
          'catatan_persetujuan': catatanPersetujuan,
        },
      );
      return response.data['status'] == true;
    } on DioException catch (e) {
      print('OperasionalApprovalPengajuanService.rejectPengajuan DioException: $e');
      throw Exception(e.response?.data['message'] ?? 'Gagal menolak pengajuan');
    } catch (e) {
      print('OperasionalApprovalPengajuanService.rejectPengajuan Error: $e');
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  static Future<List<dynamic>> getCabangs() async {
    try {
      final response = await _dio.get('/api/cabangs');
      if (response.data != null && response.data['data'] != null) {
        return response.data['data'] as List;
      }
      return [];
    } catch (e) {
      print('OperasionalApprovalPengajuanService.getCabangs Error: $e');
      return [];
    }
  }
}
