import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class MasterBarangService {
  static final _dio = ApiClient.instance;

  // ==============================
  // Cabang
  // ==============================
  static Future<List<dynamic>> getCabang() async {
    try {
      final response = await _dio.get('/operasional/cabang');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data['data'] != null) {
          return data['data'];
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

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

  static Future<bool> updateKategori(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/master-barang/kategori/$id', data: data);
      if (response.statusCode == 200) {
        return response.data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteKategori(int id) async {
    try {
      final response = await _dio.delete('/master-barang/kategori/$id');
      if (response.statusCode == 200) {
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
  static Future<List<dynamic>> getBarang({int? kategoriId}) async {
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

  static Future<bool> updateBarang(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/master-barang/barang/$id', data: data);
      if (response.statusCode == 200) {
        return response.data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteBarang(int id) async {
    try {
      final response = await _dio.delete('/master-barang/barang/$id');
      if (response.statusCode == 200) {
        return response.data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
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

  static Future<Map<String, dynamic>> addItemFisikWithFile({
    required int barangId,
    required int cabangId,
    required int jumlahTambah,
    String? photoPath,
  }) async {
    try {
      final Map<String, dynamic> map = {
        'barang_id': barangId,
        'cabang_id': cabangId,
        'jumlah_tambah': jumlahTambah,
      };

      if (photoPath != null && photoPath.isNotEmpty) {
        map['foto'] = await MultipartFile.fromFile(
          photoPath,
          filename: photoPath.split('/').last.split('\\').last,
        );
      }

      final formData = FormData.fromMap(map);
      final response = await _dio.post(
        '/master-barang/item-fisik',
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': response.data['success'] == true,
          'message': response.data['message'] ?? 'Item fisik berhasil ditambahkan',
          'data': response.data['data'],
        };
      }
      return {'success': false, 'message': response.data['message'] ?? 'Gagal menambahkan item fisik'};
    } catch (e) {
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        return {'success': false, 'message': data['message'] ?? 'Gagal: ${e.message}'};
      }
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  static Future<bool> updateItemFisik(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/master-barang/item-fisik/$id', data: data);
      if (response.statusCode == 200) {
        return response.data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteItemFisik(int id) async {
    try {
      final response = await _dio.delete('/master-barang/item-fisik/$id');
      if (response.statusCode == 200) {
        return response.data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
