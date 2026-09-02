import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../core/data/order_model.dart';
import 'dart:io';

class OrderService {
  final Dio _dio = ApiClient.instance;

  static List<OrderModel> _cachedOrders = [];
  static DateTime? _lastFetchTime;

  static List<OrderModel> get cachedOrders => List.unmodifiable(_cachedOrders);

  /// Get all orders
  Future<List<OrderModel>> fetchOrders({
    String? statusPesanan,
    int? cabangId,
    String? chatDari,
    String? tipeCustomer,
    String? startDate,
    String? endDate,
    bool fetchAllPages = false,
    int perPage = 50,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('user_role')?.toLowerCase() ?? '';
      
      if (cabangId == null && (role.contains('cs') || role.contains('customer service'))) {
        cabangId = prefs.getInt('user_cabang_id');
      }

      final Map<String, dynamic> queryParams = {
        'per_page': perPage,
      };
      if (statusPesanan != null && statusPesanan != 'Semua') {
        queryParams['status_pesanan'] = statusPesanan;
      }
      if (cabangId != null) queryParams['cabang_id'] = cabangId;
      if (chatDari != null) queryParams['chat_dari'] = chatDari;
      if (tipeCustomer != null) queryParams['tipe_customer'] = tipeCustomer;
      if (startDate != null && startDate.isNotEmpty) queryParams['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty) queryParams['end_date'] = endDate;

      final List<dynamic> allRawOrders = [];
      int lastPage = 1;
      final Map<String, dynamic> firstParams = Map<String, dynamic>.from(queryParams);
      if (fetchAllPages) {
        firstParams['page'] = 1;
      }

      final response = await _dio.get('/pesanan', queryParameters: firstParams);
      final rawBody = response.data;
      var responseData = rawBody['data'] ?? rawBody;

      if (responseData is Map && responseData.containsKey('data') && responseData['data'] is List) {
        final List pageItems = responseData['data'] as List;
        allRawOrders.addAll(pageItems);
        lastPage = responseData['last_page'] is int ? responseData['last_page'] : 1;

        if (fetchAllPages && lastPage > 1) {
          final targetLastPage = lastPage > 3 ? 3 : lastPage;
          final futures = <Future<Response>>[];
          for (int p = 2; p <= targetLastPage; p++) {
            final pParams = Map<String, dynamic>.from(queryParams);
            pParams['page'] = p;
            futures.add(_dio.get('/pesanan', queryParameters: pParams));
          }
          final pageResponses = await Future.wait(futures);
          for (final pageRes in pageResponses) {
            final pBody = pageRes.data;
            final pData = pBody['data'] ?? pBody;
            if (pData is Map && pData.containsKey('data') && pData['data'] is List) {
              allRawOrders.addAll(pData['data'] as List);
            } else if (pData is List) {
              allRawOrders.addAll(pData);
            }
          }
        }
      } else if (responseData is List) {
        allRawOrders.addAll(responseData);
      }

      final List<OrderModel> orders = [];
      for (final item in allRawOrders) {
        if (item is Map) {
          try {
            orders.add(OrderModel.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {
            // Ignore single malformed historical order
          }
        }
      }

      if (orders.isNotEmpty && statusPesanan == null && chatDari == null && tipeCustomer == null) {
        _cachedOrders = orders;
        _lastFetchTime = DateTime.now();
      }

      return orders;
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengambil data pesanan');
      }
      throw Exception('Gagal mengambil data pesanan: $e');
    }
  }

  /// Toggle status bonus (pending <-> selesai)
  Future<void> toggleStatusBonus(String id) async {
    try {
      await _dio.post('/pesanan/$id/toggle-status-bonus');
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengubah status bonus');
      }
      throw Exception('Gagal mengubah status bonus: $e');
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

  Future<void> updateOrder(String id, OrderDraft draft, {int? originalCabangId, int? originalCsId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      int cabangId = originalCabangId ?? (prefs.getInt('user_cabang_id') ?? 1);
      int csId = originalCsId ?? 1;
      
      if (originalCsId == null) {
        final csIdStr = prefs.getString('user_id');
        csId = (csIdStr != null) ? (int.tryParse(csIdStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1) : 1;
      }

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
  Future<String> createOrder(OrderDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cabangId = prefs.getInt('user_cabang_id') ?? 1;
      final csIdStr = prefs.getString('user_id');
      final csId = (csIdStr != null) ? (int.tryParse(csIdStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1) : 1;

      final data = draft.toJson();
      data['cabang_id'] = cabangId;
      data['cs_id'] = csId;

      final res = await _dio.post('/pesanan', data: data);
      final resData = res.data['data'] ?? res.data;
      return resData['id'].toString();
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

  /// Mengajukan edit layanan ke Finance
  Future<void> submitPengajuanEdit(String id, String keterangan) async {
    try {
      final response = await _dio.post('/pesanan/$id/pengajuan-edit', data: {
        'keterangan': keterangan,
      });
      if (response.data is Map && response.data['status'] == false) {
        throw Exception(response.data['message'] ?? 'Gagal mengajukan edit');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengajukan edit: ${e.message}');
      }
      throw Exception('Gagal mengajukan edit: $e');
    }
  }

  /// Mengubah status utama pesanan secara manual (override)
  Future<void> updateStatusUtamaRaw(String id, String statusUtama) async {
    try {
      final response = await _dio.patch('/pesanan/$id/status-utama', data: {
        'status_utama_raw': statusUtama,
      });
      if (response.data is Map && response.data['status'] == false) {
        throw Exception(response.data['message'] ?? 'Gagal mengubah status utama');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Gagal mengubah status utama: ${e.message}');
      }
      throw Exception('Gagal mengubah status utama: $e');
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

  /// Update Bonus Manual
  Future<void> updateManualBonus(String bonusId, int nominal, String keterangan) async {
    try {
      final response = await _dio.patch('/bonus-cleaners/$bonusId', data: {
        'nominal': nominal,
        if (keterangan.isNotEmpty) 'keterangan': keterangan,
      });
      if (response.data is Map && response.data['status'] == false) {
        throw Exception(response.data['message'] ?? 'Gagal mengubah bonus');
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
        throw Exception('Gagal mengubah bonus: $errMsg');
      }
      throw Exception('Gagal mengubah bonus: $e');
    }
  }

  /// Toggle Show WA
  Future<void> toggleWa(String pesananCleanerId) async {
    try {
      final response = await _dio.patch('/pesanan-cleaners/$pesananCleanerId/toggle-wa');
      if (response.data is Map && response.data['status'] == false) {
        throw Exception(response.data['message'] ?? 'Gagal mengubah status WA');
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
        throw Exception('Gagal mengubah status WA: $errMsg');
      }
      throw Exception('Gagal mengubah status WA: $e');
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

  /// Fetch cleaners with availability and leave status
  Future<List<Map<String, dynamic>>> fetchAvailableCleaners({String? tanggal, String? waktu, int? cabangId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final effectiveCabangId = cabangId ?? prefs.getInt('user_cabang_id');

      // 1. Try dedicated availability endpoint first
      try {
        final response = await _dio.get('/cleaners/available', queryParameters: {
          if (tanggal != null && tanggal.isNotEmpty) 'tanggal': tanggal,
          if (effectiveCabangId != null && effectiveCabangId > 0) 'cabang_id': effectiveCabangId,
        });
        var responseData = response.data['data'] ?? response.data;
        if (responseData is Map && responseData.containsKey('data')) {
          responseData = responseData['data'];
        }
        if (responseData is List && responseData.isNotEmpty) {
          return List<Map<String, dynamic>>.from(
            responseData.map((e) {
              final map = Map<String, dynamic>.from(e as Map);
              map['id'] = map['id'].toString();
              map['name'] = map['name'] ?? map['nama'] ?? '-';
              map['status_label'] = map['status_label'] ?? 'Tersedia (Bebas)';
              map['status_type'] = map['status_type'] ?? 'tersedia';
              map['is_disabled'] = map['is_disabled'] ?? false;
              map['badge_color'] = map['badge_color'] ?? '#10B981';
              return map;
            }),
          );
        }
      } catch (_) {
        // Fallback to /karyawans
      }

      // 2. Fallback
      final response = await _dio.get('/karyawans', queryParameters: {
        if (effectiveCabangId != null && effectiveCabangId > 0) 'cabang_id': effectiveCabangId,
      }); 
      var responseData = response.data['data'] ?? response.data;
      if (responseData is Map && responseData.containsKey('data')) {
        responseData = responseData['data'];
      }
      
      if (responseData is List) {
        final cleaners = responseData.where((e) {
          final jab = e['jabatan']?['nama_jabatan']?.toString().toLowerCase() ?? '';
          return jab.contains('cleaner') || e['jabatan_id'] == 3;
        }).map((e) {
          final isAktif = e['status'] == 'aktif';
          return {
            'id': e['id'].toString(),
            'name': e['nama'] ?? e['nama_karyawan'] ?? '-',
            'status_label': isAktif ? 'Tersedia (Bebas)' : 'Nonaktif',
            'status_type': isAktif ? 'tersedia' : 'nonaktif',
            'is_disabled': !isAktif,
            'badge_color': isAktif ? '#10B981' : '#EF4444',
            'rating': 5.0,
            'orders': 0,
            'foto_profil': e['foto_profil'] ?? e['foto'] ?? e['foto_url'] ?? e['foto_profil_url'] ?? e['profile_photo_url'] ?? (e['user'] != null && e['user'] is Map ? (e['user']['foto_profil'] ?? e['user']['foto_url'] ?? e['user']['foto'] ?? e['user']['profile_photo_url']) : null),
          };
        }).toList();

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
      final response = await _dio.post('/pesanan/$id/notify-cleaner');
      if (response.data is Map && response.data['status'] == false) {
        throw Exception(response.data['message'] ?? 'Gagal mengirim notifikasi');
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

  /// Hapus pesanan secara permanen
  Future<bool> deleteOrder(String id) async {
    try {
      final response = await _dio.delete('/pesanan/$id');
      if (response.data is Map && response.data['status'] == false) {
        throw Exception(response.data['message'] ?? 'Gagal menghapus pesanan');
      }
      return true;
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
      throw Exception('Gagal menghapus pesanan: $e');
    }
  }
}
