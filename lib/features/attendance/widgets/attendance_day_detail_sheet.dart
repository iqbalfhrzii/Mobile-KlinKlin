import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/attendance_model.dart';
import 'attendance_selfie_thumbnail.dart';

class AttendanceDayDetailSheet extends StatelessWidget {
  final String employeeName;
  final String? jabatanName;
  final String? cabangName;
  final DateTime? date;
  final String dateStr;
  final String status;
  final AttendanceHistoryItem? checkIn;
  final AttendanceHistoryItem? checkOut;
  final VoidCallback? onOpenFullHistory;

  const AttendanceDayDetailSheet({
    super.key,
    required this.employeeName,
    this.jabatanName,
    this.cabangName,
    this.date,
    required this.dateStr,
    required this.status,
    this.checkIn,
    this.checkOut,
    this.onOpenFullHistory,
  });

  static void show(
    BuildContext context, {
    required String employeeName,
    String? jabatanName,
    String? cabangName,
    DateTime? date,
    required String dateStr,
    required String status,
    AttendanceHistoryItem? checkIn,
    AttendanceHistoryItem? checkOut,
    VoidCallback? onOpenFullHistory,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AttendanceDayDetailSheet(
        employeeName: employeeName,
        jabatanName: jabatanName,
        cabangName: cabangName,
        date: date,
        dateStr: dateStr,
        status: status,
        checkIn: checkIn,
        checkOut: checkOut,
        onOpenFullHistory: onOpenFullHistory,
      ),
    );
  }

  String _formatIndonesianDate(DateTime? dt, String fallbackStr) {
    if (dt != null) {
      const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      const months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      final dayName = days[dt.weekday - 1];
      final monthName = months[dt.month - 1];
      return '$dayName, ${dt.day} $monthName ${dt.year}';
    }
    try {
      final parsed = DateTime.parse(fallbackStr);
      return _formatIndonesianDate(parsed, fallbackStr);
    } catch (_) {
      return fallbackStr;
    }
  }

  String _parseTimeOnly(String? raw, {String fallback = '--:--'}) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    final str = raw.trim();
    if (str.contains('T')) {
      final timePart = str.split('T')[1];
      final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(timePart);
      if (match != null) {
        return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)!}';
      }
    }
    if (str.contains(' ')) {
      final parts = str.split(' ');
      if (parts.length >= 2) {
        final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(parts.last);
        if (match != null) {
          return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)!}';
        }
      }
    }
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(str);
    if (match != null) {
      return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)!}';
    }
    return str.length >= 5 ? str.substring(0, 5) : str;
  }

  @override
  Widget build(BuildContext context) {
    final fullDateText = _formatIndonesianDate(date, dateStr);
    final isAbsent = status == 'Tidak Absen';
    final isHolidayOrLeave = status.contains('Libur') || status.contains('Cuti') || status.contains('Izin');

    Color statusColor = const Color(0xFF059669);
    Color statusBg = const Color(0xFFECFDF5);
    Color statusBorder = const Color(0xFFA7F3D0);

    if (isAbsent) {
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEF2F2);
      statusBorder = const Color(0xFFFECACA);
    } else if (status == 'Telat') {
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFFFBEB);
      statusBorder = const Color(0xFFFDE68A);
    } else if (isHolidayOrLeave) {
      statusColor = const Color(0xFF7C3AED);
      statusBg = const Color(0xFFF5F3FF);
      statusBorder = const Color(0xFFDDD6FE);
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              employeeName,
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: statusBorder),
                            ),
                            child: Text(
                              status,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${jabatanName ?? 'Karyawan'} • ${cabangName ?? 'Cabang'}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.event_note_rounded, size: 13, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text(
                            fullDateText,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Scrollable Body Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner if absent or holiday
                  if (isAbsent) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tidak Melakukan Absensi',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Karyawan tidak memiliki catatan check-in maupun check-out pada hari kerja ini.',
                                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF991B1B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ] else if (isHolidayOrLeave) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: status.contains('Libur') ? const Color(0xFFEFF6FF) : const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: status.contains('Libur') ? const Color(0xFFBFDBFE) : const Color(0xFFDDD6FE),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: status.contains('Libur') ? const Color(0xFFDBEAFE) : const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              status.contains('Libur') ? Icons.beach_access_rounded : Icons.event_available_rounded,
                              color: status.contains('Libur') ? const Color(0xFF2563EB) : const Color(0xFF7C3AED),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  status,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: status.contains('Libur') ? const Color(0xFF2563EB) : const Color(0xFF7C3AED),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  status.contains('Libur')
                                      ? 'Hari libur resmi/mingguan. Karyawan tidak diwajibkan melakukan absensi.'
                                      : 'Pengajuan cuti/izin telah disetujui oleh manajemen HRD.',
                                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF334155)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 1. Absen Masuk (Check-In) Card
                  _buildSessionCard(
                    title: 'Absensi Masuk (Check-In)',
                    isCheckIn: true,
                    item: checkIn,
                    accentColor: const Color(0xFF059669),
                    accentBg: const Color(0xFFECFDF5),
                  ),
                  const SizedBox(height: 14),

                  // 2. Absen Keluar (Check-Out) Card
                  _buildSessionCard(
                    title: 'Absensi Keluar (Check-Out)',
                    isCheckIn: false,
                    item: checkOut,
                    accentColor: const Color(0xFF2563EB),
                    accentBg: const Color(0xFFEFF6FF),
                  ),

                  // Optional Button to Open Full Calendar History
                  if (onOpenFullHistory != null) ...[
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: onOpenFullHistory,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF2563EB)),
                      label: Text(
                        'Buka Riwayat Absensi Bulanan Lengkap',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard({
    required String title,
    required bool isCheckIn,
    required AttendanceHistoryItem? item,
    required Color accentColor,
    required Color accentBg,
  }) {
    final hasRecord = item != null;
    final timeStr = hasRecord ? _parseTimeOnly(item.time) : '--:--';
    final fullTime = hasRecord ? (item.rawWaktuServer ?? item.time) : '-';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: accentBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Icon(isCheckIn ? Icons.login_rounded : Icons.logout_rounded, size: 16, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: accentColor),
                  ),
                ),
                Text(
                  hasRecord ? '$timeStr WIB' : 'Belum Absen',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: hasRecord ? accentColor : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),

          // Content Area
          Padding(
            padding: const EdgeInsets.all(14),
            child: hasRecord
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Details Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(
                              Icons.access_time_rounded,
                              'Waktu Server',
                              fullTime,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.near_me_rounded,
                              'Jarak ke Kantor',
                              '${item.distanceMeter.toStringAsFixed(1)} meter',
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.verified_user_outlined,
                              'Status Data',
                              item.status.toUpperCase(),
                            ),
                            if (item.deviceInfo != null && item.deviceInfo!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                Icons.phone_android_rounded,
                                'Perangkat',
                                item.deviceInfo!,
                              ),
                            ],
                            if (item.latitude != null && item.longitude != null) ...[
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                Icons.pin_drop_outlined,
                                'Koordinat',
                                '${item.latitude!.toStringAsFixed(5)}, ${item.longitude!.toStringAsFixed(5)}',
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Right Column: Selfie Thumbnail Preview
                      const SizedBox(width: 12),
                      Column(
                        children: [
                          AttendanceSelfieThumbnail(
                            attendanceId: item.id,
                            selfieUrl: item.selfieViewUrl ?? '',
                            title: isCheckIn ? 'Foto Selfie Masuk' : 'Foto Selfie Pulang',
                            item: item,
                            badgeLabel: isCheckIn ? 'Masuk' : 'Pulang',
                            accentColor: accentColor,
                            width: 90,
                            height: 110,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ketuk foto zoom',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isCheckIn
                                ? 'Karyawan belum melakukan absen masuk pada tanggal ini.'
                                : 'Karyawan belum melakukan absen keluar pada tanggal ini.',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF475569)),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
