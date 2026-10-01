import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../models/pengajuan_fitur_model.dart';

class PengajuanFiturService {
  final Dio _dio = ApiClient.instance;

  Future<Map<String, dynamic>> getPengajuanList({String? kategori, String? status}) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (kategori != null && kategori.isNotEmpty && kategori != 'semua') {
        queryParams['kategori'] = kategori;
      }
      if (status != null && status.isNotEmpty && status != 'semua') {
        queryParams['status'] = status;
      }

      final response = await _dio.get(
        '/pengajuan-fitur',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data['status'] == true) {
        final dataGroups = data['data'] as Map<String, dynamic>? ?? {};
        final antriList = (dataGroups['antri'] as List<dynamic>? ?? [])
            .map((item) => PengajuanFiturModel.fromJson(item as Map<String, dynamic>))
            .toList();

        final prosesList = (dataGroups['proses'] as List<dynamic>? ?? [])
            .map((item) => PengajuanFiturModel.fromJson(item as Map<String, dynamic>))
            .toList();

        final selesaiList = (dataGroups['selesai'] as List<dynamic>? ?? [])
            .map((item) => PengajuanFiturModel.fromJson(item as Map<String, dynamic>))
            .toList();

        final counts = data['counts'] as Map<String, dynamic>? ?? {
          'antri': antriList.length,
          'proses': prosesList.length,
          'selesai': selesaiList.length,
        };

        return {
          'success': true,
          'is_superadmin': data['is_superadmin'] == true,
          'counts': counts,
          'antri': antriList,
          'proses': prosesList,
          'selesai': selesaiList,
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Gagal memuat data pengajuan',
        'is_superadmin': false,
        'counts': {'antri': 0, 'proses': 0, 'selesai': 0},
        'antri': <PengajuanFiturModel>[],
        'proses': <PengajuanFiturModel>[],
        'selesai': <PengajuanFiturModel>[],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan: $e',
        'is_superadmin': false,
        'counts': {'antri': 0, 'proses': 0, 'selesai': 0},
        'antri': <PengajuanFiturModel>[],
        'proses': <PengajuanFiturModel>[],
        'selesai': <PengajuanFiturModel>[],
      };
    }
  }

  Future<Map<String, dynamic>> submitPengajuan({
    required String jenis,
    required String kategori,
    required String kendalaUtama,
    required String deskripsi,
    required File fotoFile,
  }) async {
    try {
      final fileName = fotoFile.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'jenis': jenis,
        'kategori': kategori,
        'kendala_utama': kendalaUtama,
        'deskripsi': deskripsi,
        'foto_halaman': await MultipartFile.fromFile(
          fotoFile.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '/pengajuan-fitur',
        data: formData,
      );

      final data = response.data;
      return {
        'success': data['status'] == true,
        'message': data['message'] ?? 'Pengajuan berhasil dikirim',
      };
    } catch (e) {
      String errorMessage = 'Gagal mengirim pengajuan';
      if (e is DioException && e.response?.data != null) {
        final resData = e.response!.data;
        if (resData is Map && resData['message'] != null) {
          errorMessage = resData['message'].toString();
        }
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  Future<Map<String, dynamic>> updateStatus(int id, String newStatus) async {
    try {
      final response = await _dio.patch(
        '/pengajuan-fitur/$id/status',
        data: {'status': newStatus},
      );

      return {
        'success': response.data['status'] == true,
        'message': response.data['message'] ?? 'Status berhasil diubah',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal mengubah status: $e',
      };
    }
  }
}
