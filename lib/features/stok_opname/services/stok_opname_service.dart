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
      final response = await _dio.post('/stok-opname/scan-qr', data: {'kode_qr': kodeQr});
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

  static Future<bool> submitItem(dynamic data) async {
    try {
      // Assuming data is FormData for image upload
      final response = await _dio.post('/stok-opname/submit-item', data: data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<List<dynamic>> getConsumables() async {
    try {
      final response = await _dio.get('/stok-opname/consumables');
      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData['success'] == true) {
          return resData['data'];
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> submitConsumable(dynamic data) async {
    try {
      final response = await _dio.post('/stok-opname/submit-consumable', data: data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
