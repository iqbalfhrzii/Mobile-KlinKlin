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

  AttendanceStatus({
    required this.hasCheckedIn,
    required this.hasCheckedOut,
    this.checkInTime,
    this.checkOutTime,
    this.branchName,
    this.branchLat,
    this.branchLng,
    this.maxRadiusMeter,
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
    );
  }
}

class AttendanceHistoryItem {
  final int id;
  final String? namaCleaner;
  final String? cabangName;
  final String type; // 'check_in' or 'check_out'
  final String time;
  final String status;
  final double distanceMeter;
  final String? selfieViewUrl;
  final int? karyawanId;
  final String? tanggal;

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
  });

  factory AttendanceHistoryItem.fromJson(Map<String, dynamic> json) {
    String? cName;
    if (json['cabang_name'] != null) {
      cName = json['cabang_name'].toString();
    } else if (json['cabang'] is Map && json['cabang']['nama_cabang'] != null) {
      cName = json['cabang']['nama_cabang'].toString();
    } else if (json['karyawan'] is Map && json['karyawan']['cabang'] is Map) {
      cName = json['karyawan']['cabang']['nama_cabang']?.toString();
    }

    return AttendanceHistoryItem(
      id: json['id'] ?? 0,
      namaCleaner: json['nama_cleaner'] ?? (json['karyawan'] != null ? json['karyawan']['nama'] : null),
      cabangName: cName,
      type: json['tipe'] ?? json['type'] ?? 'unknown',
      time: _formatTime(json['waktu_server'] ?? json['created_at'] ?? ''),
      status: json['status'] ?? 'unknown',
      distanceMeter: json['jarak_ke_cabang_meter'] != null 
          ? double.tryParse(json['jarak_ke_cabang_meter'].toString()) ?? 0.0 
          : (json['distance_meter'] != null ? double.tryParse(json['distance_meter'].toString()) ?? 0.0 : 0.0),
      selfieViewUrl: json['selfie_view_url'] ?? '${AppConstants.baseUrl}/absensi/${json['id'] ?? 0}/selfie',
      karyawanId: json['karyawan_id'],
      tanggal: json['tanggal'],
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

  GroupedAttendanceItem({
    required this.tanggal,
    required this.karyawanId,
    required this.namaCleaner,
    this.cabangName,
    this.checkIn,
    this.checkOut,
  });
}
