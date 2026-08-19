import '../../../core/api/api_client.dart';

class StokOpnameService {
  static final _dio = ApiClient.instance;

  static Future<List<dynamic>> getSessions({int? cabangId}) async {
    try {
      String url = '/stok-opname';
      if (cabangId != null) {
        url += '?cabang_id=$cabangId';
      }
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return data['data'] ?? [];
        } else if (data['data'] is List) {
          return data['data'];
        }
      }
      return [];
    } catch (e) {
      throw Exception('getSessions error: $e');
    }
  }

  static Future<Map<String, dynamic>?> startSession(Map<String, dynamic> requestData) async {
    try {
      final response = await _dio.post('/stok-opname/start', data: requestData);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = response.data;
        if (resData['success'] == true) {
          return resData['data'];
        }
      }
      return null;
    } catch (e) {
      throw Exception('startSession error: $e');
    }
  }

  static Future<Map<String, dynamic>?> getSessionDetails(int id) async {
    try {
      final response = await _dio.get('/stok-opname/$id');
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData['success'] == true) {
          return resData['data'];
        }
      }
      return null;
    } catch (e) {
      throw Exception('getSessionDetails error: $e');
    }
  }

  static Future<Map<String, dynamic>?> scanQr(String kodeQr) async {
    try {
      final response = await _dio.post('/stok-opname/scan', data: {'kode_qr': kodeQr});
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData['success'] == true) {
          return resData['data'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> submitItem(dynamic data) async {
    try {
      final response = await _dio.post('/stok-opname/item', data: data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': response.data['success'] == true, 'message': response.data['message'] ?? 'Berhasil'};
      }
      return {'success': false, 'message': response.data['message'] ?? 'Gagal menyimpan item'};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  static Future<Map<String, dynamic>> submitBhpOpname(dynamic data) async {
    try {
      // Endpoint /stok-opname/consumable or direct multipart submit
      final response = await _dio.post('/stok-opname/consumable', data: data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': response.data['success'] == true, 'message': response.data['message'] ?? 'Berhasil'};
      }
      return {'success': false, 'message': response.data['message'] ?? 'Gagal menyimpan opname BHP'};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  static Future<List<dynamic>> getBhps({int? bulan, int? tahun, int? cabangId}) async {
    try {
      final Map<String, dynamic> params = {};
      if (bulan != null) params['bulan'] = bulan;
      if (tahun != null) params['tahun'] = tahun;
      if (cabangId != null) params['cabang_id'] = cabangId;

      final response = await _dio.get('/pembelian-bhp', queryParameters: params);
      if (response.data != null && response.data['data'] != null) {
        if (response.data['data'] is Map<String, dynamic> && response.data['data']['data'] is List) {
          return response.data['data']['data'] as List;
        } else if (response.data['data'] is List) {
          return response.data['data'] as List;
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
