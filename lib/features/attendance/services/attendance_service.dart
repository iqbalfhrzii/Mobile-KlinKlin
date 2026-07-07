import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
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

        // Get branch info from /me since absensi list might be empty for today
        try {
          final meResponse = await _dio.get('/me');
          if (meResponse.statusCode == 200) {
            final meData = meResponse.data['data'] ?? {};
            if (meData['cabang'] != null) {
              branchName = meData['cabang']['nama_cabang'];
              branchLat = meData['cabang']['latitude'] != null ? double.tryParse(meData['cabang']['latitude'].toString()) : null;
              branchLng = meData['cabang']['longitude'] != null ? double.tryParse(meData['cabang']['longitude'].toString()) : null;
              maxRadiusMeter = meData['cabang']['radius_absensi_meter'] != null ? double.tryParse(meData['cabang']['radius_absensi_meter'].toString()) : 50.0;
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
      if (date != null) query['date'] = date;
      if (month != null) query['month'] = month;

      final response = await _dio.get('/absensi/history', queryParameters: query);
      if (response.statusCode == 200) {
        final List data = response.data['data'] ?? [];
        return data.map((item) => AttendanceHistoryItem.fromJson(item)).toList();
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
      if (date != null) query['date'] = date;
      if (month != null) query['month'] = month;
      if (branch != null) query['branch'] = branch;

      final response = await _dio.get('/absensi/riwayat', queryParameters: query);
      if (response.statusCode == 200) {
        final List data = response.data['data'] ?? [];
        return data.map((item) => AttendanceHistoryItem.fromJson(item)).toList();
      }
      throw Exception('Gagal mendapatkan daftar absensi');
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
