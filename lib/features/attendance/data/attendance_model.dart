import '../../../../core/constants/app_constants.dart';

class AttendanceStatus {
  final bool hasCheckedIn;
  final bool hasCheckedOut;
  final String? checkInTime;
  final String? checkOutTime;
  final String? branchName;
  final double? branchLat;
  final double? branchLng;
  final double? maxRadiusMeter;
  final String? jamMasuk;
  final int? toleransiTelatMenit;
  final String? jamPulang;

  AttendanceStatus({
    required this.hasCheckedIn,
    required this.hasCheckedOut,
    this.checkInTime,
    this.checkOutTime,
    this.branchName,
    this.branchLat,
    this.branchLng,
    this.maxRadiusMeter,
    this.jamMasuk,
    this.toleransiTelatMenit,
    this.jamPulang,
  });

  factory AttendanceStatus.fromJson(Map<String, dynamic> json) {
    return AttendanceStatus(
      hasCheckedIn: json['has_checked_in'] ?? false,
      hasCheckedOut: json['has_checked_out'] ?? false,
      checkInTime: json['check_in_time'],
      checkOutTime: json['check_out_time'],
      branchName: json['branch_name'],
      branchLat: json['branch_lat'] != null ? double.tryParse(json['branch_lat'].toString()) : null,
      branchLng: json['branch_lng'] != null ? double.tryParse(json['branch_lng'].toString()) : null,
      maxRadiusMeter: json['max_radius_meter'] != null ? double.tryParse(json['max_radius_meter'].toString()) : 50.0,
      jamMasuk: json['jam_masuk'],
      toleransiTelatMenit: json['toleransi_telat_menit'] != null ? int.tryParse(json['toleransi_telat_menit'].toString()) : null,
      jamPulang: json['jam_pulang'],
    );
  }
}

class AttendanceHistoryItem {
  final int id;
  final String? namaCleaner;
  final String? cabangName;
  final String type; // 'check_in' or 'check_out' / 'masuk' or 'pulang'
  final String time;
  final String status;
  final double distanceMeter;
  final String? selfieViewUrl;
  final int? karyawanId;
  final String? tanggal;
  final double? latitude;
  final double? longitude;
  final String? rawWaktuServer;
  final String? deviceInfo;
  final String? catatan;

  AttendanceHistoryItem({
    required this.id,
    this.namaCleaner,
    this.cabangName,
    required this.type,
    required this.time,
    required this.status,
    required this.distanceMeter,
    this.selfieViewUrl,
    this.karyawanId,
    this.tanggal,
    this.latitude,
    this.longitude,
    this.rawWaktuServer,
    this.deviceInfo,
    this.catatan,
  });

  bool get isCheckIn {
    final t = type.toLowerCase();
    return t == 'check_in' || t == 'masuk';
  }

  bool get isCheckOut {
    final t = type.toLowerCase();
    return t == 'check_out' || t == 'pulang';
  }

  factory AttendanceHistoryItem.fromJson(Map<String, dynamic> json) {
    String? cName;
    if (json['cabang_name'] != null) {
      cName = json['cabang_name'].toString();
    } else if (json['cabang'] is Map && json['cabang']['nama_cabang'] != null) {
      cName = json['cabang']['nama_cabang'].toString();
    } else if (json['karyawan'] is Map && json['karyawan']['cabang'] is Map) {
      cName = json['karyawan']['cabang']['nama_cabang']?.toString();
    }

    final rawTanggal = json['tanggal']?.toString();
    final normalizedTanggal = rawTanggal != null && rawTanggal.length >= 10
        ? rawTanggal.substring(0, 10)
        : rawTanggal;

    final rawServer = json['waktu_server'] ?? json['created_at'] ?? '';

    return AttendanceHistoryItem(
      id: json['id'] ?? 0,
      namaCleaner: json['nama_cleaner'] ?? (json['karyawan'] != null ? json['karyawan']['nama'] : null),
      cabangName: cName,
      type: json['tipe'] ?? json['type'] ?? 'unknown',
      time: _formatTime(rawServer.toString()),
      status: json['status'] ?? 'unknown',
      distanceMeter: json['jarak_ke_cabang_meter'] != null 
          ? double.tryParse(json['jarak_ke_cabang_meter'].toString()) ?? 0.0 
          : (json['distance_meter'] != null ? double.tryParse(json['distance_meter'].toString()) ?? 0.0 : 0.0),
      selfieViewUrl: json['selfie_view_url'] ?? '${AppConstants.baseUrl}/absensi/${json['id'] ?? 0}/selfie',
      karyawanId: json['karyawan_id'],
      tanggal: normalizedTanggal,
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      rawWaktuServer: rawServer.toString().isNotEmpty ? rawServer.toString() : null,
      deviceInfo: json['device_info']?.toString(),
      catatan: json['alasan_penolakan']?.toString() ?? json['catatan']?.toString(),
    );
  }

  static String _formatTime(String timeStr) {
    if (timeStr.isEmpty) return timeStr;
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return timeStr;
    }
  }
}

class GroupedAttendanceItem {
  final String tanggal;
  final int karyawanId;
  final String namaCleaner;
  final String? cabangName;
  final AttendanceHistoryItem? checkIn;
  final AttendanceHistoryItem? checkOut;
  final String? status;

  GroupedAttendanceItem({
    required this.tanggal,
    required this.karyawanId,
    required this.namaCleaner,
    this.cabangName,
    this.checkIn,
    this.checkOut,
    this.status,
  });
}
