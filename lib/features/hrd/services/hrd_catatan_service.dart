import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/data/hrd_models.dart';

class HrdCatatanService {
  final Dio _dio = ApiClient.instance;

  Future<Map<String, dynamic>> fetchCatatan({
    String? jenis,
    String? search,
    int? karyawanId,
    dynamic cabangId,
    int page = 1,
    int perPage = 15,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (jenis != null && jenis.isNotEmpty) query['jenis'] = jenis;
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (karyawanId != null) query['karyawan_id'] = karyawanId;
    if (cabangId != null && cabangId.toString() != 'all') query['cabang_id'] = cabangId;

    final response = await _dio.get('/hrd/catatan', queryParameters: query);
    final dataWrapper = response.data['data'];
    List rawList = [];
    int total = 0;
    int lastPage = 1;
    int currentPage = 1;

    if (dataWrapper is Map<String, dynamic>) {
      rawList = dataWrapper['data'] as List? ?? [];
      total = int.tryParse(dataWrapper['total']?.toString() ?? '0') ?? 0;
      lastPage = int.tryParse(dataWrapper['last_page']?.toString() ?? '1') ?? 1;
      currentPage = int.tryParse(dataWrapper['current_page']?.toString() ?? '1') ?? 1;
    } else if (dataWrapper is List) {
      rawList = dataWrapper;
      total = rawList.length;
    }

    final items = rawList.map((e) => CatatanHrdModel.fromJson(e as Map<String, dynamic>)).toList();
    return {
      'items': items,
      'total': total,
      'last_page': lastPage,
      'current_page': currentPage,
    };
  }

  Future<CatatanHrdModel> createCatatan(Map<String, dynamic> data) async {
    final response = await _dio.post('/hrd/catatan', data: data);
    return CatatanHrdModel.fromJson(response.data['data']);
  }

  Future<CatatanHrdModel> updateCatatan(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/hrd/catatan/$id', data: data);
    return CatatanHrdModel.fromJson(response.data['data']);
  }

  Future<void> deleteCatatan(int id) async {
    await _dio.delete('/hrd/catatan/$id');
  }

  Future<List<Map<String, dynamic>>> fetchIzinSakit(int karyawanId) async {
    try {
      final response = await _dio.get('/hrd/catatan/izin-sakit/$karyawanId');
      final data = response.data['data'] as List? ?? [];
      return data.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }
}
