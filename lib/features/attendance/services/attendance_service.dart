import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/dio_client.dart';
import '../data/attendance_model.dart';

class AttendanceService {
  final Dio _dio = DioClient.instance.dio;

  Future<AttendanceStatus> getTodayStatus() async {
    try {
      bool hasCheckedIn = false;
      bool hasCheckedOut = false;
      String? checkInTime;
      String? checkOutTime;
      String? branchName;
      double? branchLat;
      double? branchLng;
      double? maxRadiusMeter;
      String? jamMasuk;
      int? toleransiTelatMenit;
      String? jamPulang;

      final prefs = await SharedPreferences.getInstance();

      // 1. Fetch user profile from /me FIRST to determine active branch accurately
      try {
        final meResponse = await _dio.get('/me');
        if (meResponse.statusCode == 200) {
          final meData = meResponse.data['data'] ?? {};
          final c = meData['cabang'] ?? meData['karyawan']?['cabang'] ?? meData['user']?['cabang'];
          
          if (c is Map) {
            if (c['nama_cabang'] != null && c['nama_cabang'].toString().isNotEmpty) {
              branchName = c['nama_cabang'].toString();
              await prefs.setString('user_branch', branchName);
              await prefs.setString('user_cabang_name', branchName);
            }

            final lat = c['latitude'] ?? c['lat'];
            final lng = c['longitude'] ?? c['lng'];
            final radius = c['radius_absensi_meter'] ?? c['radius'];

            if (lat != null) branchLat = double.tryParse(lat.toString());
            if (lng != null) branchLng = double.tryParse(lng.toString());
            if (radius != null) maxRadiusMeter = double.tryParse(radius.toString());
            if (c['jam_masuk'] != null) jamMasuk = c['jam_masuk'].toString();
            if (c['toleransi_telat_menit'] != null) toleransiTelatMenit = int.tryParse(c['toleransi_telat_menit'].toString());
            if (c['jam_pulang'] != null) jamPulang = c['jam_pulang'].toString();

            if (c['id'] != null) {
              final parsedId = int.tryParse(c['id'].toString());
              if (parsedId != null) {
                await prefs.setInt('user_cabang_id', parsedId);
              }
            }
          }

          // If coordinates or branch details are missing, fetch from /cabangs for this specific cabang_id
          if (branchLat == null || branchLng == null || maxRadiusMeter == null || jamMasuk == null) {
            final dynamic cabangId = meData['cabang_id'] ??
                meData['karyawan']?['cabang_id'] ??
                (c is Map ? c['id'] : null) ??
                prefs.getInt('user_cabang_id');

            if (cabangId != null) {
              try {
                final cabangsResponse = await _dio.get('/cabangs');
                if (cabangsResponse.statusCode == 200) {
                  final cabangsList = cabangsResponse.data['data'] as List;
                  final myCabang = cabangsList.firstWhere(
                    (cb) => cb['id'].toString() == cabangId.toString(),
                    orElse: () => null,
                  );

                  if (myCabang != null) {
                    branchName = myCabang['nama_cabang']?.toString() ?? branchName;
                    final lat = myCabang['latitude'] ?? myCabang['lat'];
                    final lng = myCabang['longitude'] ?? myCabang['lng'];
                    final radius = myCabang['radius_absensi_meter'] ?? myCabang['radius'];

                    if (lat != null) branchLat = double.tryParse(lat.toString());
                    if (lng != null) branchLng = double.tryParse(lng.toString());
                    if (radius != null) maxRadiusMeter = double.tryParse(radius.toString());
                    if (myCabang['jam_masuk'] != null) jamMasuk = myCabang['jam_masuk'].toString();
                    if (myCabang['toleransi_telat_menit'] != null) toleransiTelatMenit = int.tryParse(myCabang['toleransi_telat_menit'].toString());
                    if (myCabang['jam_pulang'] != null) jamPulang = myCabang['jam_pulang'].toString();

                    if (branchName != null) {
                      await prefs.setString('user_branch', branchName);
                      await prefs.setString('user_cabang_name', branchName);
                    }
                  }
                }
              } catch (_) {}
            }
          }
        }
      } catch (_) {}

      // 2. Fetch today's attendance status from /absensi/saya
      try {
        final response = await _dio.get('/absensi/saya');
        if (response.statusCode == 200) {
          final List data = response.data['data'] ?? [];
          final now = DateTime.now();
          final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

          for (var item in data) {
            if (item['tanggal'] == todayStr) {
              if (item['tipe'] == 'masuk') {
                hasCheckedIn = true;
                checkInTime = item['waktu_server'];
              } else if (item['tipe'] == 'pulang') {
                hasCheckedOut = true;
                checkOutTime = item['waktu_server'];
              }
            }
          }
        }
      } catch (_) {}

      // Fallback branchName from preferences if still null
      branchName ??= prefs.getString('user_cabang_name') ?? prefs.getString('user_branch') ?? 'Kantor Cabang';

      return AttendanceStatus(
        hasCheckedIn: hasCheckedIn,
        hasCheckedOut: hasCheckedOut,
        checkInTime: checkInTime,
        checkOutTime: checkOutTime,
        branchName: branchName,
        branchLat: branchLat,
        branchLng: branchLng,
        maxRadiusMeter: maxRadiusMeter,
        jamMasuk: jamMasuk,
        toleransiTelatMenit: toleransiTelatMenit,
        jamPulang: jamPulang,
      );
    } catch (e) {
      throw Exception('Terjadi kesalahan jaringan atau server: $e');
    }
  }

  Future<List<AttendanceHistoryItem>> getHistory({String? date, String? month}) async {
    try {
      final Map<String, dynamic> query = {};
      if (date != null) query['tanggal'] = date;
      if (month != null) query['bulan'] = month;

      // Some backend APIs might not support filtering by month on the /saya endpoint
      // We'll fetch all and filter locally if needed, or just rely on what the API returns.
      final response = await _dio.get('/absensi/saya');
      if (response.statusCode == 200) {
        final List data = response.data['data'] ?? [];
        var history = data.map((item) => AttendanceHistoryItem.fromJson(item)).toList();
        
        // Filter locally by month if provided since we removed it from query params
        if (month != null) {
          history = history.where((item) => item.tanggal != null && item.tanggal!.startsWith(month)).toList();
        }
        
        return history;
      }
      throw Exception('Gagal mendapatkan riwayat absensi');
    } catch (e) {
      throw Exception('Terjadi kesalahan saat memuat riwayat: $e');
    }
  }

  Future<List<String>> getMyJadwalLiburs() async {
    try {
      final response = await _dio.get('/cleaner/rekan-kerja');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? {};
        final List liburSaya = data['libur_saya'] ?? [];
        return liburSaya
            .map((e) => e['tanggal']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getMyLeaves() async {
    try {
      final response = await _dio.get('/karyawan/pengajuan');
      if (response.statusCode == 200) {
        final List data = response.data['data'] ?? [];
        return data.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Future<String> getDeviceInfo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return '${androidInfo.brand} ${androidInfo.model}';
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      return '${iosInfo.name} ${iosInfo.systemName} ${iosInfo.systemVersion}';
    }
    return 'Unknown Device';
  }

  Future<void> submitAttendance({
    required bool isCheckIn,
    required File photoFile,
    required double latitude,
    required double longitude,
    required double accuracy,
    required bool isMockLocation,
  }) async {
    try {
      String device = await getDeviceInfo();
      String endpoint = isCheckIn ? '/absensi/check-in' : '/absensi/check-out';

      FormData formData = FormData.fromMap({
        'latitude': latitude,
        'longitude': longitude,
        'akurasi_meter': accuracy,
        'is_mock_location': isMockLocation ? 1 : 0,
        'device_info': device,
        'selfie': await MultipartFile.fromFile(photoFile.path, filename: 'selfie_${DateTime.now().millisecondsSinceEpoch}.jpg'),
      });

      final response = await _dio.post(endpoint, data: formData);
      if (response.statusCode != 200 && response.statusCode != 201) {
        final message = response.data['message'] ?? 'Gagal memproses absensi';
        throw Exception(message);
      }
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Terjadi kesalahan pada server';
      throw Exception(message);
    } catch (e) {
      throw Exception('Gagal mengirim absensi: $e');
    }
  }


  Future<Map<String, dynamic>> getDetailBulanan({required int karyawanId, String? month}) async {
    try {
      final Map<String, dynamic> query = {};
      if (month != null && month.isNotEmpty) {
        if (month.contains('-')) {
          final parts = month.split('-');
          if (parts.length >= 2) {
            final y = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1]);
            if (y != null) query['tahun'] = y;
            if (m != null) query['bulan'] = m;
          }
        }
      }

      final response = await _dio.get(
        '/absensi/detail-bulanan/$karyawanId',
        queryParameters: query,
      );
      if (response.statusCode == 200) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<List<AttendanceHistoryItem>> getAllAbsensi({String? date, String? month, String? branch, int? karyawanId}) async {
    try {
      final Map<String, dynamic> query = {};
      if (date != null && date.isNotEmpty) {
        query['tanggal'] = date;
      }
      if (karyawanId != null) {
        query['karyawan_id'] = karyawanId;
      }
      if (month != null && month.isNotEmpty) {
        if (month.contains('-')) {
          final parts = month.split('-');
          if (parts.length >= 2) {
            final y = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1]);
            if (y != null) query['tahun'] = y;
            if (m != null) query['bulan'] = m;
          }
        } else {
          final m = int.tryParse(month);
          if (m != null) query['bulan'] = m;
        }
      }
      if (branch != null && branch.isNotEmpty) {
        final bId = int.tryParse(branch);
        if (bId != null) query['cabang_id'] = bId;
      }

      final allItems = <AttendanceHistoryItem>[];
      int currentPage = 1;
      int lastPage = 1;

      do {
        final currentQuery = Map<String, dynamic>.from(query);
        currentQuery['page'] = currentPage;

        final response = await _dio.get('/absensi/riwayat', queryParameters: currentQuery);
        if (response.statusCode == 200) {
          final resData = response.data['data'];
          if (resData is Map) {
            final itemsList = resData['data'] as List? ?? [];
            allItems.addAll(itemsList.map((item) => AttendanceHistoryItem.fromJson(item)));
            lastPage = resData['last_page'] ?? 1;
          } else if (resData is List) {
            allItems.addAll(resData.map((item) => AttendanceHistoryItem.fromJson(item)));
            break;
          } else {
            break;
          }
        } else {
          break;
        }
        currentPage++;
      } while (currentPage <= lastPage);

      return allItems;
    } catch (e) {
      throw Exception('Terjadi kesalahan saat memuat absensi: $e');
    }
  }

  Future<AttendanceHistoryItem> getDetailAbsensi(int id) async {
    try {
      final response = await _dio.get('/absensi/$id');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? {};
        return AttendanceHistoryItem.fromJson(data);
      }
      throw Exception('Gagal mendapatkan detail absensi');
    } catch (e) {
      throw Exception('Terjadi kesalahan saat memuat detail: $e');
    }
  }
}
