import '../../../core/api/api_client.dart';

class MasterBarangService {
  static final _dio = ApiClient.instance;

  // ==============================
  // Kategori Barang
  // ==============================
  static Future<List<dynamic>> getKategori() async {
    try {
      final response = await _dio.get('/api/master-barang/kategori');
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
  // Data Barang
  // ==============================
  static Future<List<dynamic>> getBarang({int? kategoriId}) async {
    try {
      String url = '/api/master-barang/barang';
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
      String url = '/api/master-barang/item-fisik';
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
}
