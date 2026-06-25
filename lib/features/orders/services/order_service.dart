import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../core/data/order_model.dart';
import 'dart:io';

class OrderService {
  final Dio _dio = ApiClient.instance;

  /// Get all orders
  Future<List<OrderModel>> fetchOrders({
    String? statusPesanan,
    int? cabangId,
    String? chatDari,
    String? tipeCustomer,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (statusPesanan != null && statusPesanan != 'Semua') {
        // Map back to API expected string if needed, but the UI might pass raw names
        queryParams['status_pesanan'] = statusPesanan;
      }
      if (cabangId != null) queryParams['cabang_id'] = cabangId;
      if (chatDari != null) queryParams['chat_dari'] = chatDari;
      if (tipeCustomer != null) queryParams['tipe_customer'] = tipeCustomer;

      final response = await _dio.get('/pesanan', queryParameters: queryParams);
      var responseData = response.data['data'] ?? response.data;
      
      // Jika responseData berupa Map (biasanya karena Pagination Laravel), ambil field 'data' di dalamnya
      if (responseData is Map && responseData.containsKey('data') && responseData['data'] is List) {
        responseData = responseData['data'];
      }
      
      final List data = responseData as List;
      return data.map((json) => OrderModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Gagal mengambil data pesanan: $e');
    }
  }

  /// Get single order details
  Future<OrderModel> fetchOrderDetail(String id) async {
    try {
      final response = await _dio.get('/pesanan/$id');
      final data = response.data['data'] ?? response.data;
      return OrderModel.fromJson(data);
    } catch (e) {
      throw Exception('Gagal mengambil detail pesanan: $e');
    }
  }

  /// Update order
  Future<void> updateOrder(String id, OrderDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cabangId = prefs.getInt('user_cabang_id') ?? 1;
      final csIdStr = prefs.getString('user_id');
      final csId = (csIdStr != null) ? (int.tryParse(csIdStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1) : 1;

      final data = draft.toJson();
      data['cabang_id'] = cabangId;
      data['cs_id'] = csId;

      await _dio.put('/pesanan/$id', data: data);
    } catch (e) {
      if (e is DioException) {
        throw Exception('Gagal menyimpan perubahan: ${e.response?.data}');
      }
      throw Exception('Gagal menyimpan perubahan pesanan: $e');
    }
  }

  /// Create order
  Future<void> createOrder(OrderDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cabangId = prefs.getInt('user_cabang_id') ?? 1;
      final csIdStr = prefs.getString('user_id');
      final csId = (csIdStr != null) ? (int.tryParse(csIdStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1) : 1;

      final data = draft.toJson();
      data['cabang_id'] = cabangId;
      data['cs_id'] = csId;

      await _dio.post('/pesanan', data: data);
    } catch (e) {
      if (e is DioException) {
        throw Exception('Gagal membuat pesanan: ${e.response?.data}');
      }
      throw Exception('Gagal membuat pesanan baru: $e');
    }
  }

  /// Assign cleaner
  Future<void> assignCleaner(String id, List<String> cleanerIds) async {
    try {
      // convert to int if required by API, but usually API handles string ids or we map them:
      final cIds = cleanerIds.map((e) => int.tryParse(e) ?? e).toList();
      await _dio.post('/pesanan/$id/assign-cleaner', data: {
        'cleaner_ids': cIds,
      });
    } catch (e) {
      if (e is DioException) {
        final resData = e.response?.data;
        if (resData is Map && resData.containsKey('message')) {
          throw Exception('${resData['message']}');
        }
      }
      throw Exception('Gagal menugaskan cleaner: $e');
    }
  }

  /// Mengalokasikan bonus layanan ke cleaner
  Future<void> allocateBonusLayanan(String id, List<Map<String, dynamic>> items) async {
    try {
      await _dio.post('/pesanan/$id/bonus-layanan', data: {
        'items': items,
      });
    } catch (e) {
      if (e is DioException) {
        throw Exception('Gagal mengalokasikan bonus: ${e.response?.data['message'] ?? e.response?.data}');
      }
      throw Exception('Gagal mengalokasikan bonus: $e');
    }
  }

  /// Tambah Bonus Manual / Non-Layanan ke Cleaner
  Future<void> addManualBonus(String pesananId, String pesananCleanerId, int nominal, String keterangan) async {
    try {
      final response = await _dio.post('/pesanan/$pesananId/bonus-manual', data: {
        'items': [
          {
            'pesanan_cleaner_id': int.tryParse(pesananCleanerId) ?? pesananCleanerId,
            'nominal': nominal,
            if (keterangan.isNotEmpty) 'keterangan': keterangan,
          }
        ]
      });
      if (response.data is Map && response.data['status'] == false) {
        throw Exception(response.data['message'] ?? 'Gagal memproses bonus dari server');
      }
    } catch (e) {
      if (e is DioException) {
        final resData = e.response?.data;
        String errMsg = 'Terjadi kesalahan sistem';
        if (resData is Map && resData.containsKey('message')) {
          errMsg = resData['message'].toString();
        } else if (resData != null) {
          errMsg = 'Status ${e.response?.statusCode}: format response tidak dikenali';
        } else {
          errMsg = e.message ?? 'Unknown DioException';
        }
        throw Exception('Gagal menambah bonus: $errMsg');
      }
      throw Exception('Gagal menambah bonus: $e');
    }
  }

  /// Fetch Tarif Bonus untuk Cabang tertentu
  Future<List<Map<String, dynamic>>> fetchTarifBonus(String cabangId) async {
    try {
      final response = await _dio.get('/cabangs/$cabangId/tarif-bonus');
      if (response.data is Map && response.data['data'] != null) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      throw Exception('Gagal memuat tarif bonus: $e');
    }
  }

  /// Tambah Bonus berdasarkan Jenis Bonus (menggunakan tarif bonus cabang)
  Future<void> storeManualBonus(String pesananCleanerId, int jenisBonusId, int nominal, String keterangan) async {
    try {
      final response = await _dio.post('/pesanan-cleaners/$pesananCleanerId/bonus', data: {
        'jenis_bonus_id': jenisBonusId,
        'nominal': nominal,
        if (keterangan.isNotEmpty) 'keterangan': keterangan,
      });
      if (response.data is Map && response.data['status'] == false) {
        throw Exception(response.data['message'] ?? 'Gagal menyimpan bonus');
      }
    } catch (e) {
      if (e is DioException) {
        final resData = e.response?.data;
        String errMsg = 'Terjadi kesalahan sistem';
        if (resData is Map && resData.containsKey('message')) {
          errMsg = resData['message'].toString();
        } else if (resData != null) {
          errMsg = 'Status ${e.response?.statusCode}: format response tidak dikenali';
        } else {
          errMsg = e.message ?? 'Unknown DioException';
        }
        throw Exception('Gagal menyimpan bonus: $errMsg');
      }
      throw Exception('Gagal menyimpan bonus: $e');
    }
  }

  /// Fetch Layanan
  Future<List<Map<String, dynamic>>> fetchLayanan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cabangId = prefs.getInt('user_cabang_id');
      final response = await _dio.get('/layanans', queryParameters: {
        if (cabangId != null) 'cabang_id': cabangId,
        'status': 'aktif'
      });
      var responseData = response.data['data'] ?? response.data;
      if (responseData is Map && responseData.containsKey('data')) {
        responseData = responseData['data'];
      }
      return List<Map<String, dynamic>>.from(responseData);
    } catch (e) {
      throw Exception('Gagal mengambil layanan: $e');
    }
  }

  /// Fetch cleaners
  Future<List<Map<String, dynamic>>> fetchAvailableCleaners({String? tanggal, String? waktu}) async {
    try {
      final response = await _dio.get('/karyawans'); 
      var responseData = response.data['data'] ?? response.data;
      if (responseData is Map && responseData.containsKey('data')) {
        responseData = responseData['data'];
      }
      
      if (responseData is List) {
        final cleaners = responseData.where((e) {
          final jab = e['jabatan']?['nama_jabatan']?.toString().toLowerCase() ?? '';
          return jab.contains('cleaner') || e['jabatan_id'] == 3;
        }).map((e) => {
          'id': e['id'].toString(),
          'name': e['nama'] ?? e['nama_karyawan'] ?? '-',
          'status_pengerjaan': 'free',
          'rating': 5.0,
          'orders': 0,
        }).toList();

        if (tanggal != null && waktu != null) {
          String fWaktu = waktu;
          if (fWaktu.contains(':')) {
            final tParts = fWaktu.split(':');
            if (tParts.length >= 2) fWaktu = '${tParts[0].padLeft(2, '0')}:${tParts[1].padLeft(2, '0')}';
          }

          final futures = cleaners.map((c) async {
            try {
              final jobRes = await _dio.get('/cleaner/jobs', queryParameters: {'cleaner_id': c['id']});
              final jobs = jobRes.data['data'] ?? [];
              if (jobs is List) {
                for (var job in jobs) {
                  final pesanan = job['pesanan'];
                  if (pesanan != null && pesanan['details'] != null && pesanan['details'] is List) {
                    for (var detail in pesanan['details']) {
                      if (detail['tanggal_pengerjaan'] == tanggal) {
                        c['status_pengerjaan'] = job['status_pengerjaan']?.toString() ?? 'free';
                        break;
                      }
                    }
                  }
                  if (c['status_pengerjaan'] != 'free') break;
                }
              }
            } catch (e) {
              // Ignore failure for individual cleaner
            }
          });
          await Future.wait(futures);
        }

        return cleaners;
      }
      return [];
    } catch (e) {
      throw Exception('Gagal memuat cleaner: $e');
    }
  }

  /// Notify assigned cleaners
  Future<void> notifyCleaner(String id) async {
    try {
      await _dio.post('/pesanan/$id/notify-cleaner');
    } catch (e) {
      throw Exception('Gagal mengirim notifikasi ke cleaner: $e');
    }
  }

  /// Batalkan pesanan
  Future<void> cancelOrder(String id, String reason, File proof) async {
    try {
      String fileName = proof.path.split('/').last;
      FormData formData = FormData.fromMap({
        'alasan_cancel': reason,
        'bukti_cancel': await MultipartFile.fromFile(proof.path, filename: fileName),
      });

      final response = await _dio.post('/pesanan/$id/pembatalan', data: formData);
      if (response.data is Map && response.data['status'] == false) {
        throw Exception(response.data['message'] ?? 'Gagal membatalkan pesanan');
      }
    } catch (e) {
      if (e is DioException) {
        final data = e.response?.data;
        String errMsg = e.message ?? 'Terjadi kesalahan koneksi';
        if (data is Map<String, dynamic>) {
          errMsg = data['message'] ?? data.toString();
        } else if (data != null) {
          errMsg = data.toString();
        }
        throw Exception(errMsg);
      }
      throw Exception('Gagal membatalkan pesanan: $e');
    }
  }
}
