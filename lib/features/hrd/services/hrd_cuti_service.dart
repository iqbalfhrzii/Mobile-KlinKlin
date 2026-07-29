import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class HrdCutiService {
  final Dio _dio = ApiClient.instance;

  // --- Karyawan Cuti Data ---
  Future<List<Map<String, dynamic>>> fetchKaryawans({
    String? search,
    String? cabangId,
    String? jabatan,
  }) async {
    final response = await _dio.get('/cuti/karyawans', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (cabangId != null && cabangId.isNotEmpty) 'cabang_id': cabangId,
      if (jabatan != null && jabatan.isNotEmpty) 'jabatan': jabatan,
    });
    return List<Map<String, dynamic>>.from(response.data['data']);
  }

  Future<Map<String, dynamic>> fetchRiwayatKaryawan(int karyawanId) async {
    final response = await _dio.get('/cuti/karyawans/$karyawanId/riwayat');
    return response.data['data'];
  }

  Future<void> updateKaryawanCuti(int karyawanId, int jatahCuti, int sisaCuti) async {
    await _dio.put('/cuti/karyawans/$karyawanId', data: {
      'jatah_cuti': jatahCuti,
      'sisa_cuti': sisaCuti,
    });
  }

  // --- Pengajuan Cuti & Izin ---
  Future<Map<String, dynamic>> fetchPengajuan({
    String? status,
    String? search,
    String? cabangId,
  }) async {
    final response = await _dio.get('/cuti/pengajuan', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      if (cabangId != null && cabangId.isNotEmpty) 'cabang_id': cabangId,
    });
    return response.data['data']; // Returns { data: [...], stats: {...} }
  }

  Future<void> approvePengajuan(int pengajuanId) async {
    await _dio.put('/cuti/pengajuan/$pengajuanId/approve');
  }

  Future<void> rejectPengajuan(int pengajuanId, String catatan) async {
    await _dio.put('/cuti/pengajuan/$pengajuanId/reject', data: {
      'catatan_hrd': catatan,
    });
  }

  // --- Pengaturan Cuti ---
  Future<Map<String, dynamic>> fetchPengaturan() async {
    final response = await _dio.get('/cuti/pengaturan');
    return response.data['data'];
  }

  Future<void> updatePengaturan(int defaultJatahCuti, List<String> hariKerja) async {
    await _dio.put('/cuti/pengaturan', data: {
      'default_jatah_cuti': defaultJatahCuti,
      'hari_kerja': hariKerja,
    });
  }
}
