import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../data/attendance_model.dart';
import '../services/attendance_service.dart';
import 'selfie_viewer_screen.dart';

class AdminAttendanceDetailScreen extends StatefulWidget {
  final GroupedAttendanceItem item;
  final bool showPhoto;

  const AdminAttendanceDetailScreen({
    super.key,
    required this.item,
    this.showPhoto = true,
  });

  @override
  State<AdminAttendanceDetailScreen> createState() => _AdminAttendanceDetailScreenState();
}

class _AdminAttendanceDetailScreenState extends State<AdminAttendanceDetailScreen> {
  String? _token;
  bool _isTokenLoaded = false;

  bool _isLoadingStats = true;
  int _tepatWaktu = 0;
  int _telat = 0;
  int _plgCepat = 0;
  int _tdkAbsen = 0;
  List<dynamic> _monthlyHistory = [];


  @override
  void initState() {
    super.initState();
    _loadToken();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final date = DateTime.parse(widget.item.tanggal);
      final currentMonth = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final history = await AttendanceService().getAllAbsensi(
        karyawanId: widget.item.karyawanId,
        month: currentMonth,
      );
      
      // Group by date to calculate Tdk Absen correctly
      final Map<String, List<AttendanceHistoryItem>> grouped = {};
      for (var item in history) {
        if (item.tanggal == null) continue;
        if (!grouped.containsKey(item.tanggal)) grouped[item.tanggal!] = [];
        grouped[item.tanggal!]!.add(item);
      }
      
      int tepat = 0;
      int tlt = 0;
      int plgCepat = 0;
      int tdkAbsn = 0;
      
      // Calculate workdays passed in this month up to the selected date
      int workdaysPassed = 0;
      for (int i = 1; i <= date.day; i++) {
        final d = DateTime(date.year, date.month, i);
        if (d.weekday != DateTime.sunday) {
          workdaysPassed++;
        }
      }

      int presentDays = 0;
      
      grouped.forEach((dateStr, items) {
        final masuk = items.where((i) => i.type == 'check_in' || i.type == 'masuk').firstOrNull;
        final keluar = items.where((i) => i.type == 'check_out' || i.type == 'pulang').firstOrNull;
        
        if (masuk != null) {
          presentDays++;
          bool isLate = false;
          if (masuk.time.contains(' ')) {
            final tParts = masuk.time.split(' ').last.split(':');
            if (tParts.length >= 2) {
              final h = int.tryParse(tParts[0]) ?? 0;
              final m = int.tryParse(tParts[1]) ?? 0;
              if (h > 8 || (h == 8 && m > 15)) isLate = true;
            }
          }
          if (isLate) {
            tlt++;
          } else {
            tepat++;
          }
        }
        
        if (keluar != null) {
          bool isEarly = false;
          if (keluar.time.contains(' ')) {
            final tParts = keluar.time.split(' ').last.split(':');
            if (tParts.length >= 2) {
              final h = int.tryParse(tParts[0]) ?? 0;
              if (h < 17) isEarly = true;
            }
          }
          if (isEarly) plgCepat++;
        }
      });
      
      tdkAbsn = (workdaysPassed - presentDays);
      if (tdkAbsn < 0) tdkAbsn = 0;

      if (mounted) {
        setState(() {
          _tepatWaktu = tepat;
          _telat = tlt;
          _plgCepat = plgCepat;
          _tdkAbsen = tdkAbsn;
          _monthlyHistory = history;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _token = prefs.getString('auth_token');
        _isTokenLoaded = true;
      });
    }
  }

  String _formatIndonesianDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      final months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      final dayName = days[dt.weekday - 1];
      final monthName = months[dt.month - 1];
      return '$dayName, ${dt.day} $monthName ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasCheckIn = widget.item.checkIn != null;
    final bool hasCheckOut = widget.item.checkOut != null;
    final String cabangName = widget.item.cabangName ?? 'SURABAYA';

    String statusLabel = 'Tidak Absen';
    Color statusColor = const Color(0xFFC62828);
    Color statusBg = const Color(0xFFFFEBEE);

    if (hasCheckIn && hasCheckOut) {
      statusLabel = 'Hadir Lengkap';
      statusColor = const Color(0xFF2E7D32);
      statusBg = const Color(0xFFE8F5E9);
    } else if (hasCheckIn && !hasCheckOut) {
      final timeStr = widget.item.checkIn!.time;
      bool isLate = false;
      if (timeStr.contains(' ')) {
        final tParts = timeStr.split(' ').last.split(':');
        if (tParts.length >= 2) {
          final h = int.tryParse(tParts[0]) ?? 0;
          final m = int.tryParse(tParts[1]) ?? 0;
          if (h > 8 || (h == 8 && m > 15)) isLate = true;
        }
      }
      if (isLate) {
        statusLabel = 'Terlambat';
        statusColor = const Color(0xFFF57F17);
        statusBg = const Color(0xFFFFF8E1);
      } else {
        statusLabel = 'Absen Masuk';
        statusColor = const Color(0xFF1565C0);
        statusBg = const Color(0xFFE3F2FD);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header Bar
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(16, 52, 20, 24),
            child: Row(
              children: [
                HeaderBackButton(onTap: () => Navigator.pop(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail Absensi Hari Ini',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.item.namaCleaner} · ${_formatIndonesianDate(widget.item.tanggal)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- 1. Cleaner & Status Overview Card ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1D4ED8).withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.person_outline_rounded, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                                      const SizedBox(width: 4),
                                      Text('Nama Cleaner', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.item.namaCleaner,
                                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.2)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.storefront_rounded, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                                      const SizedBox(width: 4),
                                      Text('Cabang', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    cabangName,
                                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_month_rounded, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                                      const SizedBox(width: 4),
                                      Text('Tanggal Absen', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatIndonesianDate(widget.item.tanggal),
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.fact_check_outlined, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                                      const SizedBox(width: 4),
                                      Text('Status Kehadiran', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.1),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- 2. Full Width Aturan Cabang SURABAYA ---
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Bar
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Aturan Jam Operasional ${cabangName.toUpperCase()}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              _buildRuleRow('Jam Masuk Standard', '08:00', hint: '(+15 mnt toleransi)', icon: Icons.login_rounded, iconColor: const Color(0xFF22C55E)),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                              ),
                              _buildRuleRow('Batas Terlambat', '08:15', hint: '(lewat ini = telat)', isOrange: true, icon: Icons.warning_amber_rounded, iconColor: const Color(0xFFF59E0B)),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                              ),
                              _buildRuleRow('Jam Pulang Standard', '17:00', icon: Icons.logout_rounded, iconColor: const Color(0xFF3B82F6)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),


                  // --- 3. Stats Boxes ---
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatBox('TEPAT WAKTU', _tepatWaktu.toString(), const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatBox('TELAT', _telat.toString(), const Color(0xFFF57F17), const Color(0xFFFFF8E1)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatBox('PLG CEPAT', _plgCepat.toString(), const Color(0xFF1565C0), const Color(0xFFE3F2FD)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatBox('TDK ABSEN', _tdkAbsen.toString(), const Color(0xFFC62828), const Color(0xFFFFEBEE)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- 3. Section Title ---
                  Text(
                    'Detail Absensi Masuk & Keluar',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- 4. Absensi Masuk Card ---
                  _buildAttendanceDetailCard(
                    title: 'Absensi Masuk (Check-In)',
                    icon: Icons.login_rounded,
                    headerBg: const Color(0xFFE8F5E9),
                    headerColor: const Color(0xFF2E7D32),
                    itemData: widget.item.checkIn,
                    emptyMessage: 'Cleaner belum melakukan absen masuk pada tanggal ini.',
                  ),
                  const SizedBox(height: 16),

                  // --- 5. Absensi Keluar Card ---
                  _buildAttendanceDetailCard(
                    title: 'Absensi Keluar (Check-Out)',
                    icon: Icons.logout_rounded,
                    headerBg: const Color(0xFFE3F2FD),
                    headerColor: const Color(0xFF1565C0),
                    itemData: widget.item.checkOut,
                    emptyMessage: 'Cleaner belum melakukan absen keluar pada tanggal ini.',
                  ),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        'Riwayat Absen Bulan Ini',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!_isLoadingStats)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                          child: Text('${_monthlyHistory.length} log', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildMonthlyHistory(),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleRow(String label, String value, {String? hint, bool isOrange = false, IconData? icon, Color? iconColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: iconColor ?? AppColors.textMuted),
              const SizedBox(width: 8),
            ],
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark)),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hint != null) ...[
              Text(
                hint,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isOrange ? const Color(0xFFF59E0B).withValues(alpha: 0.8) : Colors.grey.shade500,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOrange ? const Color(0xFFFFFBEB) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isOrange ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
              ),
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isOrange ? const Color(0xFFD97706) : AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttendanceDetailCard({
    required String title,
    required IconData icon,
    required Color headerBg,
    required Color headerColor,
    required AttendanceHistoryItem? itemData,
    required String emptyMessage,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: headerColor),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: headerColor,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: itemData == null
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.event_busy_rounded, size: 36, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          emptyMessage,
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailField(
                              'Waktu Absen',
                              itemData.time,
                              Icons.access_time_rounded,
                              AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDetailField(
                              'Jarak ke Kantor',
                              '${itemData.distanceMeter.toStringAsFixed(1)} meter',
                              Icons.location_on_rounded,
                              itemData.distanceMeter <= 50.0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Status Verification
                      Row(
                        children: [
                          Text('Status Verifikasi: ', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              (itemData.status.isEmpty ? 'DITERIMA' : itemData.status).toUpperCase(),
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Photo Section
                      Text(
                        'Foto Selfie Kehadiran:',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 8),

                      if (widget.showPhoto && itemData.selfieViewUrl != null && itemData.selfieViewUrl!.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SelfieViewerScreen(
                                  attendanceId: itemData.id,
                                  initialUrl: itemData.selfieViewUrl!,
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: _isTokenLoaded
                                      ? Image.network(
                                          itemData.selfieViewUrl!,
                                          headers: _token != null ? {'Authorization': 'Bearer $_token'} : null,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: Colors.grey.shade100,
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.no_photography_rounded, size: 40, color: Colors.grey.shade400),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Foto selfie tidak dapat ditampilkan',
                                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        )
                                      : const Center(child: CircularProgressIndicator()),
                                ),
                                Container(
                                  margin: const EdgeInsets.all(12),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Ketuk untuk perbesar',
                                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.no_photography_rounded, size: 20, color: Colors.grey.shade400),
                              const SizedBox(width: 10),
                              Text(
                                'Tidak ada foto selfie recorded.',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }


  Widget _buildMonthlyHistory() {
    if (_isLoadingStats) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(),
      ));
    }
    if (_monthlyHistory.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text('Belum ada riwayat bulan ini.', style: GoogleFonts.inter(color: AppColors.textMuted)),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _monthlyHistory.length,
      separatorBuilder: (_, __) => const Divider(height: 1),

      itemBuilder: (context, index) {
        final item = _monthlyHistory[index];
        final bool isMasuk = true; // API returns grouped data, we can just display it simply. Wait, the detailBulanan returns per day.
        final jamMasuk = item['jam_masuk'];
        final jamKeluar = item['jam_keluar'];
        final status = item['status'] ?? 'Tidak Absen';
        
        String timeDisplay = 'Tidak absen';
        if (jamMasuk != null && jamKeluar != null) {
            timeDisplay = '$jamMasuk - $jamKeluar';
        } else if (jamMasuk != null) {
            timeDisplay = '$jamMasuk - ?';
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: status == 'Tidak Absen' ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              status == 'Tidak Absen' ? Icons.event_busy_rounded : Icons.calendar_today_rounded,
              size: 18,
              color: status == 'Tidak Absen' ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
            ),
          ),
          title: Text(
            item['tanggal'] != null ? _formatIndonesianDate(item['tanggal']) : 'Tanggal tidak diketahui',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Jam: $timeDisplay',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
          ),
        );
      },

    );
  }

  Widget _buildDetailField(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          _isLoadingStats 
              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color))
              : Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}
