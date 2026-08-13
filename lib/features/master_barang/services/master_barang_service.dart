import '../../../core/api/api_client.dart';

class MasterBarangService {
  static final _dio = ApiClient.instance;

  // ==============================
  // Kategori Barang
  // ==============================
  static Future<List<dynamic>> getKategori() async {
    try {
      final response = await _dio.get('/master-barang/kategori');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> addKategori(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/master-barang/kategori', data: data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ==============================
  // Data Barang
  // ==============================

  static Future<List<dynamic>> getBarang() async {
    try {
      final response = await _dio.get('/master-barang/barang');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> addBarang(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/master-barang/barang', data: data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<List<dynamic>> getBarangFiltered({int? kategoriId}) async {
    try {
      String url = '/master-barang/barang';
      if (kategoriId != null) {
        url += '?kategori_id=$kategoriId';
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
      return [];
    }
  }

  // ==============================
  // Item Fisik
  // ==============================
  static Future<List<dynamic>> getItemFisik({int? cabangId}) async {
    try {
      String url = '/master-barang/item-fisik';
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
      return [];
    }
  }

  static Future<bool> addItemFisik(dynamic formData) async {
    try {
      final response = await _dio.post(
        '/master-barang/item-fisik',
        data: formData,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
