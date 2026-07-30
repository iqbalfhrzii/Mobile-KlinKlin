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
      final response = await _dio.get('/absensi/saya');
      if (response.statusCode == 200) {
        final List data = response.data['data'] ?? [];
        
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
            
            // Try to extract branch info from the absensi record itself if possible
            final c = item['karyawan']?['cabang'] ?? item['cabang'];
            if (c != null) {
              if (branchName == null && c['nama_cabang'] != null) {
                branchName = c['nama_cabang'];
              }
              final lat = c['latitude'] ?? c['lat'];
              final lng = c['longitude'] ?? c['lng'];
              final radius = c['radius_absensi_meter'] ?? c['radius'];
              
              if (lat != null && branchLat == null) branchLat = double.tryParse(lat.toString());
              if (lng != null && branchLng == null) branchLng = double.tryParse(lng.toString());
              if (radius != null && maxRadiusMeter == null) maxRadiusMeter = double.tryParse(radius.toString());
              if (c['jam_masuk'] != null && jamMasuk == null) jamMasuk = c['jam_masuk'].toString();
              if (c['toleransi_telat_menit'] != null && toleransiTelatMenit == null) toleransiTelatMenit = int.tryParse(c['toleransi_telat_menit'].toString());
              if (c['jam_pulang'] != null && jamPulang == null) jamPulang = c['jam_pulang'].toString();
            }
          }
        }

        // Get branch info from /me since absensi list might be empty for today
        try {
          final meResponse = await _dio.get('/me');
          if (meResponse.statusCode == 200) {
            final meData = meResponse.data['data'] ?? {};
            
            // 1. Get branch info directly from /me first
            final cabang1 = meData['cabang'];
            final cabang2 = meData['karyawan']?['cabang'];
            final cabang3 = meData['user']?['cabang'];
            
            final List<dynamic> possibleCabangs = [cabang1, cabang2, cabang3];
            for (var c in possibleCabangs) {
              if (c != null) {
                if (branchName == null && c['nama_cabang'] != null) {
                  branchName = c['nama_cabang'];
                }
                
                final lat = c['latitude'] ?? c['lat'];
                final lng = c['longitude'] ?? c['lng'];
                final radius = c['radius_absensi_meter'] ?? c['radius'];
                
                if (lat != null && branchLat == null) branchLat = double.tryParse(lat.toString());
                if (lng != null && branchLng == null) branchLng = double.tryParse(lng.toString());
                if (radius != null && maxRadiusMeter == null) maxRadiusMeter = double.tryParse(radius.toString());
                if (c['jam_masuk'] != null && jamMasuk == null) jamMasuk = c['jam_masuk'].toString();
                if (c['toleransi_telat_menit'] != null && toleransiTelatMenit == null) toleransiTelatMenit = int.tryParse(c['toleransi_telat_menit'].toString());
                if (c['jam_pulang'] != null && jamPulang == null) jamPulang = c['jam_pulang'].toString();
              }
            }

            // 2. Fallback: If coordinates or schedule are STILL null, try fetching /cabangs
            if (branchLat == null || branchLng == null || jamMasuk == null) {
              var cabangId = meData['cabang_id'] ?? meData['karyawan']?['cabang_id'] ?? meData['user']?['cabang_id'];
              
              if (cabangId == null) {
                final prefs = await SharedPreferences.getInstance();
                cabangId = prefs.getInt('user_cabang_id') ?? prefs.getString('user_cabang_id');
              }
              
              if (cabangId != null) {
                try {
                  // Fetch from /cabangs to guarantee getting the coordinates
                  final cabangsResponse = await _dio.get('/cabangs');
                  if (cabangsResponse.statusCode == 200) {
                    final cabangsList = cabangsResponse.data['data'] as List;
                    final myCabang = cabangsList.firstWhere((c) => c['id'].toString() == cabangId.toString(), orElse: () => null);
                    
                    if (myCabang != null) {
                      branchName = myCabang['nama_cabang'] ?? branchName;
                      
                      final lat = myCabang['latitude'] ?? myCabang['lat'];
                      final lng = myCabang['longitude'] ?? myCabang['lng'];
                      final radius = myCabang['radius_absensi_meter'] ?? myCabang['radius'];
                      
                      if (lat != null && branchLat == null) branchLat = double.tryParse(lat.toString());
                      if (lng != null && branchLng == null) branchLng = double.tryParse(lng.toString());
                      if (radius != null && maxRadiusMeter == null) maxRadiusMeter = double.tryParse(radius.toString());
                      if (myCabang['jam_masuk'] != null && jamMasuk == null) jamMasuk = myCabang['jam_masuk'].toString();
                      if (myCabang['toleransi_telat_menit'] != null && toleransiTelatMenit == null) toleransiTelatMenit = int.tryParse(myCabang['toleransi_telat_menit'].toString());
                      if (myCabang['jam_pulang'] != null && jamPulang == null) jamPulang = myCabang['jam_pulang'].toString();
                    }
                  }
                } catch (_) {}
              }
            }
          }
        } catch (_) {}

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
      }
      throw Exception('Gagal mendapatkan status absensi');
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

  Future<List<AttendanceHistoryItem>> getAllAbsensi({String? date, String? month, String? branch}) async {
    try {
      final Map<String, dynamic> query = {};
      if (date != null && date.isNotEmpty) {
        query['tanggal'] = date;
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
