import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../data/attendance_model.dart';
import '../services/attendance_service.dart';
import '../widgets/attendance_selfie_thumbnail.dart';
import '../../../../core/utils/timezone_helper.dart';

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
  final AttendanceService _service = AttendanceService();

  late DateTime _selectedMonth;
  late String _inspectedDateStr;
  late GroupedAttendanceItem _currentDayItem;

  bool _isLoadingHistory = true;
  List<GroupedAttendanceItem> _monthlyHistory = [];
  String _activeFilter = 'semua'; // 'semua', 'hadir', 'keluar', 'telat', 'tidak_absen', 'libur_cuti'

  int _statAbsenMasuk = 0;
  int _statAbsenKeluar = 0;
  int _statTelat = 0;
  int _statTidakAbsen = 0;
  int _statIzinCutiLibur = 0;

  final String _jamMasukStandard = '08:00';
  final String _jamPulangStandard = '17:00';
  final int _toleransiTelatMenit = 15;

  String get _tzLabel => TimezoneHelper.getTimezoneLabel(widget.item.cabangName);

  @override
  void initState() {
    super.initState();
    _currentDayItem = widget.item;
    _inspectedDateStr = widget.item.tanggal;

    try {
      _selectedMonth = DateTime.parse(widget.item.tanggal);
    } catch (_) {
      _selectedMonth = DateTime.now();
    }

    _loadMonthlyAttendance();
  }

  Future<void> _loadMonthlyAttendance() async {
    setState(() => _isLoadingHistory = true);
    try {
      final monthStr = DateFormat('yyyy-MM').format(_selectedMonth);
      
      // Fetch attendance records from backend
      final historyList = await _service.getAllAbsensi(
        karyawanId: widget.item.karyawanId,
        month: monthStr,
      );

      final grouped = <String, GroupedAttendanceItem>{};
      for (var item in historyList) {
        if (item.tanggal == null) continue;
        final rawKey = item.tanggal!;
        final key = rawKey.length >= 10 ? rawKey.substring(0, 10) : rawKey;

        if (!grouped.containsKey(key)) {
          grouped[key] = GroupedAttendanceItem(
            tanggal: key,
            karyawanId: widget.item.karyawanId,
            namaCleaner: widget.item.namaCleaner,
            cabangName: widget.item.cabangName,
          );
        }

        final type = item.type.toLowerCase();
        if (type == 'check_in' || type == 'masuk') {
          grouped[key] = GroupedAttendanceItem(
            tanggal: key,
            karyawanId: widget.item.karyawanId,
            namaCleaner: widget.item.namaCleaner,
            cabangName: widget.item.cabangName,
            checkIn: item,
            checkOut: grouped[key]!.checkOut,
          );
        } else if (type == 'check_out' || type == 'pulang') {
          grouped[key] = GroupedAttendanceItem(
            tanggal: key,
            karyawanId: widget.item.karyawanId,
            namaCleaner: widget.item.namaCleaner,
            cabangName: widget.item.cabangName,
            checkIn: grouped[key]!.checkIn,
            checkOut: item,
          );
        }
      }

      // If initial item was passed, ensure it is in grouped map
      if (widget.item.checkIn != null || widget.item.checkOut != null) {
        final rawInit = widget.item.tanggal;
        final key = rawInit.length >= 10 ? rawInit.substring(0, 10) : rawInit;
        if (!grouped.containsKey(key)) {
          grouped[key] = widget.item;
        } else {
          final existing = grouped[key]!;
          grouped[key] = GroupedAttendanceItem(
            tanggal: key,
            karyawanId: widget.item.karyawanId,
            namaCleaner: widget.item.namaCleaner,
            cabangName: widget.item.cabangName,
            checkIn: existing.checkIn ?? widget.item.checkIn,
            checkOut: existing.checkOut ?? widget.item.checkOut,
          );
        }
      }

      // Generate day-by-day sequence matching Cleaner & Web ERP view
      final now = DateTime.now();
      final isCurrentMonth = _selectedMonth.year == now.year && _selectedMonth.month == now.month;
      final int lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
      final int maxDayToEvaluate = isCurrentMonth ? now.day : lastDayOfMonth;

      int masuk = 0;
      int keluar = 0;
      int telat = 0;
      int tidakAbsen = 0;
      int izinCutiLibur = 0;

      final List<GroupedAttendanceItem> fullList = [];

      for (int day = maxDayToEvaluate; day >= 1; day--) {
        final dStr = "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
        final existing = grouped[dStr];
        final dt = DateTime(_selectedMonth.year, _selectedMonth.month, day);

        if (existing != null && (existing.checkIn != null || existing.checkOut != null)) {
          String itemStatus = 'Tepat Waktu';
          if (existing.checkIn != null) {
            masuk++;
            final inTime = _parseTimeOnly(existing.checkIn!.time);
            if (_isLate(inTime, _jamMasukStandard, _toleransiTelatMenit)) {
              telat++;
              itemStatus = 'Telat';
            } else if (existing.checkOut != null) {
              itemStatus = 'Lengkap';
            }
          } else {
            itemStatus = 'Pulang Cepat';
          }

          if (existing.checkOut != null) {
            keluar++;
          }

          fullList.add(GroupedAttendanceItem(
            tanggal: dStr,
            karyawanId: widget.item.karyawanId,
            namaCleaner: widget.item.namaCleaner,
            cabangName: widget.item.cabangName,
            checkIn: existing.checkIn,
            checkOut: existing.checkOut,
            status: itemStatus,
          ));
        } else {
          if (dt.weekday == DateTime.sunday) {
            izinCutiLibur++;
            fullList.add(GroupedAttendanceItem(
              tanggal: dStr,
              karyawanId: widget.item.karyawanId,
              namaCleaner: widget.item.namaCleaner,
              cabangName: widget.item.cabangName,
              status: 'Libur Mingguan',
            ));
          } else {
            tidakAbsen++;
            fullList.add(GroupedAttendanceItem(
              tanggal: dStr,
              karyawanId: widget.item.karyawanId,
              namaCleaner: widget.item.namaCleaner,
              cabangName: widget.item.cabangName,
              status: 'Tidak Absen',
            ));
          }
        }
      }

      if (mounted) {
        setState(() {
          _monthlyHistory = fullList;
          _statAbsenMasuk = masuk;
          _statAbsenKeluar = keluar;
          _statTelat = telat;
          _statTidakAbsen = tidakAbsen;
          _statIzinCutiLibur = izinCutiLibur;
          _isLoadingHistory = false;

          // Update current inspected day item from the calculated list
          final foundCurrent = fullList.where((e) => e.tanggal == _inspectedDateStr);
          if (foundCurrent.isNotEmpty) {
            _currentDayItem = foundCurrent.first;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  String _parseTimeOnly(String? fullTime, {String fallback = '--:--'}) {
    if (fullTime == null || fullTime.isEmpty || fullTime == '-') return fallback;
    if (fullTime.contains('T')) {
      try {
        final dt = DateTime.parse(fullTime).toLocal();
        return DateFormat('HH:mm').format(dt);
      } catch (_) {}
    }
    if (fullTime.contains(' ')) {
      final parts = fullTime.split(' ');
      if (parts.length > 1 && parts.last.contains(':')) {
        final tParts = parts.last.split(':');
        if (tParts.length >= 2) return '${tParts[0].padLeft(2, '0')}:${tParts[1].padLeft(2, '0')}';
      }
    }
    if (fullTime.contains(':')) {
      final parts = fullTime.split(':');
      if (parts.length >= 2) return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return fallback;
  }

  bool _isLate(String inTime, String shiftMasuk, int toleransiMenit) {
    if (inTime == '--:--') return false;
    final inParts = inTime.split(':');
    final shiftParts = shiftMasuk.split(':');
    if (inParts.length < 2 || shiftParts.length < 2) return false;

    final inMin = (int.tryParse(inParts[0]) ?? 0) * 60 + (int.tryParse(inParts[1]) ?? 0);
    final limitMin = (int.tryParse(shiftParts[0]) ?? 8) * 60 + (int.tryParse(shiftParts[1]) ?? 0) + toleransiMenit;
    return inMin > limitMin;
  }

  void _stepMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
      _inspectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedMonth);
    });
    _loadMonthlyAttendance();
  }

  String _formatIndonesianDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      const months = [
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

  String _dayShort(int weekday) {
    const d = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return d[weekday - 1];
  }

  String _monthName(int month) {
    const m = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return m[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final employeeName = widget.item.namaCleaner.isNotEmpty ? widget.item.namaCleaner : 'Karyawan';
    final branchName = widget.item.cabangName ?? 'Surabaya';
    final inspectedFormattedDate = _formatIndonesianDate(_inspectedDateStr);

    final filteredHistory = _monthlyHistory.where((group) {
      final s = (group.status ?? '').toLowerCase();
      if (_activeFilter == 'hadir') return group.checkIn != null;
      if (_activeFilter == 'keluar') return group.checkOut != null;
      if (_activeFilter == 'telat') return s == 'telat';
      if (_activeFilter == 'tidak_absen') return s == 'tidak absen';
      if (_activeFilter == 'libur_cuti') return s.contains('libur') || s.contains('cuti') || s.contains('izin');
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail Absensi Karyawan',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$employeeName • $branchName',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadMonthlyAttendance,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Standard Schedule Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF64748B).withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.schedule_rounded, color: Color(0xFF2563EB), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Jadwal Kerja Standard', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Text(
                                  'Masuk: $_jamMasukStandard $_tzLabel (Toleransi $_toleransiTelatMenit mnt) • Pulang: $_jamPulangStandard $_tzLabel',
                                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Monthly Summary 5 Stats Cards (Matching Cleaner Layout)
                    _buildSummaryStatCards(),
                    const SizedBox(height: 18),

                    // Current Selected Day Check-in & Check-out Detail
                    _buildInspectedDayDetail(inspectedFormattedDate),
                    const SizedBox(height: 22),

                    // Riwayat Absen Bulan Ini (Day-by-Day List)
                    _buildMonthlyHistorySection(filteredHistory),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. THE 5 SUMMARY STAT CARDS ---
  Widget _buildSummaryStatCards() {
    return Column(
      children: [
        // Row 1: 3 cards (Masuk, Keluar, Telat)
        Row(
          children: [
            Expanded(
              child: _buildSingleStatCard(
                title: 'Absen Masuk',
                value: '$_statAbsenMasuk',
                icon: Icons.login_rounded,
                iconColor: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
                filterKey: 'hadir',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSingleStatCard(
                title: 'Absen Keluar',
                value: '$_statAbsenKeluar',
                icon: Icons.logout_rounded,
                iconColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                filterKey: 'keluar',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSingleStatCard(
                title: 'Telat',
                value: '$_statTelat',
                icon: Icons.alarm_rounded,
                iconColor: const Color(0xFFD97706),
                bgColor: const Color(0xFFFFFBEB),
                filterKey: 'telat',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Row 2: 2 cards (Tidak Absen, Izin/Cuti/Libur)
        Row(
          children: [
            Expanded(
              child: _buildSingleStatCard(
                title: 'Tidak Absen',
                value: '$_statTidakAbsen',
                icon: Icons.cancel_outlined,
                iconColor: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEF2F2),
                filterKey: 'tidak_absen',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSingleStatCard(
                title: 'Izin/Cuti/Libur',
                value: '$_statIzinCutiLibur',
                icon: Icons.event_available_rounded,
                iconColor: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFF5F3FF),
                filterKey: 'libur_cuti',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String filterKey,
  }) {
    final isSelected = _activeFilter == filterKey;
    return InkWell(
      onTap: () {
        setState(() {
          _activeFilter = isSelected ? 'semua' : filterKey;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? iconColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? iconColor.withValues(alpha: 0.12) : const Color(0xFF64748B).withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 13, color: iconColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isSelected ? iconColor : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. CURRENT SELECTED DAY DETAIL ---
  Widget _buildInspectedDayDetail(String inspectedFormattedDate) {
    final checkIn = _currentDayItem.checkIn;
    final checkOut = _currentDayItem.checkOut;
    final status = _currentDayItem.status ?? 'Tidak Absen';

    final bool isAbsent = status == 'Tidak Absen';
    final bool isHolidayOrLeave = status.contains('Libur') || status.contains('Cuti') || status.contains('Izin');

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detail Absensi Hari Terpilih',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    inspectedFormattedDate,
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusBorder),
              ),
              child: Text(
                status,
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Check-In Card
        _buildCheckActionCard(
          title: 'Absensi Masuk (Check-In)',
          isCheckIn: true,
          item: checkIn,
          accentColor: const Color(0xFF059669),
          accentBg: const Color(0xFFECFDF5),
        ),
        const SizedBox(height: 12),

        // Check-Out Card
        _buildCheckActionCard(
          title: 'Absensi Keluar (Check-Out)',
          isCheckIn: false,
          item: checkOut,
          accentColor: const Color(0xFF2563EB),
          accentBg: const Color(0xFFEFF6FF),
        ),
      ],
    );
  }

  Widget _buildCheckActionCard({
    required String title,
    required bool isCheckIn,
    required AttendanceHistoryItem? item,
    required Color accentColor,
    required Color accentBg,
  }) {
    final bool hasRecord = item != null;
    final timeStr = hasRecord ? _parseTimeOnly(item.time) : '--:--';
    final fullTime = hasRecord ? item.time : '-';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                if (hasRecord)
                  Text(
                    '$timeStr $_tzLabel',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: accentColor),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: hasRecord
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Details Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow(Icons.access_time_rounded, 'Waktu Server', fullTime),
                                const SizedBox(height: 8),
                                _buildDetailRow(
                                  Icons.location_on_outlined,
                                  'Jarak ke Kantor',
                                  '${item.distanceMeter.toStringAsFixed(1)} meter',
                                ),
                                const SizedBox(height: 8),
                                _buildDetailRow(
                                  Icons.verified_user_outlined,
                                  'Status Kehadiran',
                                  item.status.isNotEmpty ? item.status : 'Diterima',
                                ),
                              ],
                            ),
                          ),

                          // Right Photo Preview (if any)
                          if (item.selfieViewUrl != null && item.selfieViewUrl!.isNotEmpty && widget.showPhoto) ...[
                            const SizedBox(width: 12),
                            Column(
                              children: [
                                AttendanceSelfieThumbnail(
                                  attendanceId: item.id,
                                  selfieUrl: item.selfieViewUrl!,
                                  title: isCheckIn ? 'Foto Selfie Masuk' : 'Foto Selfie Pulang',
                                  item: item,
                                  badgeLabel: isCheckIn ? 'Masuk' : 'Pulang',
                                  accentColor: accentColor,
                                  width: 86,
                                  height: 106,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Ketuk zoom',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.event_busy_rounded, size: 22, color: Color(0xFF94A3B8)),
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
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
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
                TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- 3. RIWAYAT ABSEN BULAN INI SECTION ---
  Widget _buildMonthlyHistorySection(List<GroupedAttendanceItem> filteredHistory) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month Selector Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Riwayat Absen Bulan Ini',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
                Text(
                  '${_monthlyHistory.length} Hari dalam periode',
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _stepMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    color: const Color(0xFF334155),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      '${_monthName(_selectedMonth.month).substring(0, 3)} ${_selectedMonth.year}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _stepMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    color: const Color(0xFF334155),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Filter Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Daftar Riwayat',
              style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: _activeFilter != 'semua' ? const Color(0xFFEFF6FF) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _activeFilter != 'semua' ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _activeFilter,
                  isDense: true,
                  icon: Icon(
                    Icons.filter_list_rounded,
                    size: 16,
                    color: _activeFilter != 'semua' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _activeFilter != 'semua' ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                  ),
                  items: [
                    DropdownMenuItem(value: 'semua', child: Text('Semua (${_monthlyHistory.length})')),
                    DropdownMenuItem(value: 'hadir', child: Text('Absen Masuk ($_statAbsenMasuk)')),
                    DropdownMenuItem(value: 'keluar', child: Text('Absen Keluar ($_statAbsenKeluar)')),
                    DropdownMenuItem(value: 'telat', child: Text('Telat ($_statTelat)')),
                    DropdownMenuItem(value: 'tidak_absen', child: Text('Tidak Absen ($_statTidakAbsen)')),
                    DropdownMenuItem(value: 'libur_cuti', child: Text('Izin/Cuti/Libur ($_statIzinCutiLibur)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _activeFilter = val);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // List View
        if (_isLoadingHistory)
          const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()))
        else if (filteredHistory.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 36, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text('Belum ada data untuk filter ini.', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredHistory.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final group = filteredHistory[index];
              return _buildMonthlyDayCard(group);
            },
          ),
      ],
    );
  }

  Widget _buildMonthlyDayCard(GroupedAttendanceItem group) {
    DateTime? dt;
    try {
      dt = DateTime.parse(group.tanggal);
    } catch (_) {}

    final dayNum = dt != null ? '${dt.day}' : '--';
    final dayStr = dt != null ? _dayShort(dt.weekday) : '';
    final fullDate = dt != null ? _formatIndonesianDate(group.tanggal) : group.tanggal;

    final inTime = _parseTimeOnly(group.checkIn?.time);
    final outTime = _parseTimeOnly(group.checkOut?.time);

    final status = group.status ?? 'Tepat Waktu';
    final bool isAbsent = status == 'Tidak Absen';
    final bool isHolidayOrLeave = status.contains('Libur') || status.contains('Cuti') || status.contains('Izin');
    final bool isSelectedDate = group.tanggal == _inspectedDateStr;

    Color dateBgColor = const Color(0xFFF1F5F9);
    Color dateTextColor = const Color(0xFF0F172A);
    Color statusColor = const Color(0xFF059669);
    Color statusBg = const Color(0xFFECFDF5);
    Color statusBorder = const Color(0xFFA7F3D0);

    if (isAbsent) {
      dateBgColor = const Color(0xFFFEF2F2);
      dateTextColor = const Color(0xFFDC2626);
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEF2F2);
      statusBorder = const Color(0xFFFECACA);
    } else if (status == 'Telat') {
      dateBgColor = const Color(0xFFFFFBEB);
      dateTextColor = const Color(0xFFD97706);
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFFFBEB);
      statusBorder = const Color(0xFFFDE68A);
    } else if (isHolidayOrLeave) {
      dateBgColor = const Color(0xFFF5F3FF);
      dateTextColor = const Color(0xFF7C3AED);
      statusColor = const Color(0xFF7C3AED);
      statusBg = const Color(0xFFF5F3FF);
      statusBorder = const Color(0xFFDDD6FE);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelectedDate ? const Color(0xFF2563EB) : (isAbsent ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
          width: isSelectedDate ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelectedDate ? const Color(0xFF2563EB).withValues(alpha: 0.08) : const Color(0xFF64748B).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _inspectedDateStr = group.tanggal;
              _currentDayItem = group;
            });
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Date Box
                Container(
                  width: 44,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: dateBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        dayNum,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: dateTextColor,
                        ),
                      ),
                      Text(
                        dayStr,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isAbsent ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Content / Times
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullDate,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isAbsent)
                        Text(
                          'Tidak ada catatan kehadiran',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFFDC2626),
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else if (isHolidayOrLeave)
                        Text(
                          status.contains('Libur') ? 'Jadwal hari libur kerja' : 'Izin / Cuti disetujui',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF7C3AED),
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        Row(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.login_rounded, size: 13, color: Color(0xFF059669)),
                                const SizedBox(width: 3),
                                Text(
                                  inTime != '--:--' ? '$inTime $_tzLabel' : '--:--',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: inTime != '--:--' ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Row(
                              children: [
                                const Icon(Icons.logout_rounded, size: 13, color: Color(0xFF2563EB)),
                                const SizedBox(width: 3),
                                Text(
                                  outTime != '--:--' ? '$outTime $_tzLabel' : '--:--',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: outTime != '--:--' ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Status Badge & Arrow
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
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
