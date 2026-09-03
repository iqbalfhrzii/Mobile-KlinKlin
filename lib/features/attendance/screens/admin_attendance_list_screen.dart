import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../../../core/data/hrd_models.dart';
import '../../hrd/services/hrd_service.dart';
import '../data/attendance_model.dart';
import '../services/attendance_service.dart';
import 'selfie_viewer_screen.dart';
import 'admin_attendance_detail_screen.dart';
import '../widgets/attendance_day_detail_sheet.dart';
import '../../../../core/widgets/app_avatar.dart';

class EmployeeAttendanceSummary {
  final KaryawanModel karyawan;
  final int totalHariPeriode;
  final int hadirCount;
  final int terlambatCount;
  final int cutiLiburCount;
  final int tidakAbsenCount;
  final List<DailyAttendanceLog> dailyLogs;

  EmployeeAttendanceSummary({
    required this.karyawan,
    required this.totalHariPeriode,
    required this.hadirCount,
    required this.terlambatCount,
    required this.cutiLiburCount,
    required this.tidakAbsenCount,
    required this.dailyLogs,
  });

  double get attendancePercentage {
    if (totalHariPeriode == 0) return 0.0;
    return (hadirCount / totalHariPeriode) * 100;
  }
}

class DailyAttendanceLog {
  final String dateStr;
  final DateTime date;
  final String status; // 'Tepat Waktu', 'Telat', 'Cuti', 'Libur', 'Tidak Absen'
  final AttendanceHistoryItem? checkIn;
  final AttendanceHistoryItem? checkOut;

  DailyAttendanceLog({
    required this.dateStr,
    required this.date,
    required this.status,
    this.checkIn,
    this.checkOut,
  });
}

class AdminAttendanceListScreen extends StatefulWidget {
  const AdminAttendanceListScreen({super.key});

  @override
  State<AdminAttendanceListScreen> createState() => _AdminAttendanceListScreenState();
}

class _AdminAttendanceListScreenState extends State<AdminAttendanceListScreen> {
  final AttendanceService _service = AttendanceService();
  final HrdService _hrdService = HrdService();

  bool _isLoading = true;
  List<AttendanceHistoryItem> _allRawItems = [];
  List<KaryawanModel> _allKaryawanList = [];
  List<CabangModel> _cabangList = [];

  String _selectedRole = 'cleaner'; // 'cleaner' | 'cs'
  String _filterWaktu = 'bulan_ini'; // 'bulan_ini' (default), 'minggu_ini', 'bulan_lalu', 'hari_ini', 'custom'

  DateTime? _customStartDate;
  DateTime? _customEndDate;
  DateTime _selectedMonth = DateTime.now();

  int? _selectedCabangId;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  String _activeStatusMetricFilter = 'all'; // 'all', 'hadir', 'telat', 'cuti_libur', 'tidak_absen'

  List<EmployeeAttendanceSummary> _summaries = [];
  List<EmployeeAttendanceSummary> _filteredSummaries = [];

  bool _isFinance = false;
  int? _userCabangId;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? '';
    if (mounted) {
      setState(() {
        _isFinance = role.toLowerCase().contains('finance');
        _userCabangId = prefs.getInt('user_cabang_id');
        if (_isFinance && _userCabangId != null) {
          _selectedCabangId = _userCabangId;
        }
      });
      _loadCabangs();
      _loadData();
    }
  }

  Future<void> _loadCabangs() async {
    try {
      final cabangs = await _hrdService.fetchCabang();
      if (mounted && cabangs.isNotEmpty) {
        setState(() {
          _cabangList = cabangs.where((c) => !c.namaCabang.toLowerCase().contains('kantor pusat')).toList();
        });
        return;
      }
    } catch (_) {}

    if (_allKaryawanList.isNotEmpty) {
      final Map<int, CabangModel> map = {};
      for (var c in _allKaryawanList) {
        if (c.cabang != null && !c.cabang!.namaCabang.toLowerCase().contains('kantor pusat')) {
          map[c.cabang!.id] = c.cabang!;
        }
      }
      if (mounted && map.isNotEmpty) {
        setState(() {
          _cabangList = map.values.toList();
        });
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final String? branchParam = _selectedCabangId?.toString();
      String? dateParam;
      String? monthParam;

      final now = DateTime.now();
      if (_filterWaktu == 'hari_ini') {
        dateParam = DateFormat('yyyy-MM-dd').format(now);
      } else if (_filterWaktu == 'bulan_ini') {
        monthParam = DateFormat('yyyy-MM').format(_selectedMonth);
      } else if (_filterWaktu == 'bulan_lalu') {
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        monthParam = DateFormat('yyyy-MM').format(lastMonth);
      } else if (_filterWaktu == 'custom' && _customStartDate != null && _customEndDate != null) {
        if (_customStartDate!.month == _customEndDate!.month && _customStartDate!.year == _customEndDate!.year) {
          monthParam = DateFormat('yyyy-MM').format(_customStartDate!);
        } else {
          monthParam = null;
        }
      }

      final items = await _service.getAllAbsensi(
        date: dateParam,
        month: monthParam,
        branch: branchParam,
      );

      List<KaryawanModel> karyawans = [];
      try {
        karyawans = await _hrdService.fetchKaryawan();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _allRawItems = items;
          _allKaryawanList = karyawans;
        });
        _loadCabangs();
        _recalculateSummaries();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat absensi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<DateTime> _getDatesForCurrentFilter() {
    final now = DateTime.now();
    final dates = <DateTime>[];

    if (_filterWaktu == 'hari_ini') {
      dates.add(DateTime(now.year, now.month, now.day));
    } else if (_filterWaktu == 'minggu_ini') {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      for (int i = 0; i < now.weekday; i++) {
        final d = startOfWeek.add(Duration(days: i));
        dates.add(DateTime(d.year, d.month, d.day));
      }
    } else if (_filterWaktu == 'bulan_ini') {
      final targetMonth = _selectedMonth;
      final start = DateTime(targetMonth.year, targetMonth.month, 1);
      final isCurrentMonth = targetMonth.year == now.year && targetMonth.month == now.month;
      final end = isCurrentMonth ? now : DateTime(targetMonth.year, targetMonth.month + 1, 0);

      for (var d = end; !d.isBefore(start); d = d.subtract(const Duration(days: 1))) {
        dates.add(DateTime(d.year, d.month, d.day));
      }
    } else if (_filterWaktu == 'bulan_lalu') {
      final targetMonth = DateTime(now.year, now.month - 1, 1);
      final start = DateTime(targetMonth.year, targetMonth.month, 1);
      final end = DateTime(targetMonth.year, targetMonth.month + 1, 0);

      for (var d = end; !d.isBefore(start); d = d.subtract(const Duration(days: 1))) {
        dates.add(DateTime(d.year, d.month, d.day));
      }
    } else if (_filterWaktu == 'custom' && _customStartDate != null && _customEndDate != null) {
      for (var d = _customEndDate!; !d.isBefore(_customStartDate!); d = d.subtract(const Duration(days: 1))) {
        dates.add(DateTime(d.year, d.month, d.day));
      }
    } else {
      final start = DateTime(now.year, now.month, 1);
      for (var d = now; !d.isBefore(start); d = d.subtract(const Duration(days: 1))) {
        dates.add(DateTime(d.year, d.month, d.day));
      }
    }

    return dates;
  }

  void _recalculateSummaries() {
    final validDates = _getDatesForCurrentFilter();
    final isCleaner = _selectedRole == 'cleaner';

    // Target employees filtered by role and branch
    final targetEmployees = _allKaryawanList.where((k) {
      final status = k.status.toLowerCase();
      if (status == 'pending' || status == 'nonaktif' || status == 'inactive') return false;
      final role = (k.jabatan?.namaJabatan ?? '').toLowerCase();
      if (isCleaner) {
        if (!role.contains('cleaner')) return false;
      } else {
        if (!role.contains('cs') && !role.contains('customer service') && !role.contains('staff')) return false;
      }
      if (_selectedCabangId != null && k.cabangId != _selectedCabangId) return false;
      return true;
    }).toList();

    // Index raw check-ins and check-outs
    final Map<String, AttendanceHistoryItem> checkInMap = {};
    final Map<String, AttendanceHistoryItem> checkOutMap = {};

    for (final item in _allRawItems) {
      if (item.karyawanId != null && item.tanggal != null) {
        final tStr = item.tanggal!.length >= 10 ? item.tanggal!.substring(0, 10) : item.tanggal!;
        final key = '${item.karyawanId}_$tStr';
        if (item.type == 'check_in' || item.type == 'masuk') {
          checkInMap[key] = item;
        } else if (item.type == 'check_out' || item.type == 'pulang') {
          checkOutMap[key] = item;
        }
      }
    }

    final resultSummaries = <EmployeeAttendanceSummary>[];

    for (final emp in targetEmployees) {
      int hadir = 0;
      int telat = 0;
      int cutiLibur = 0;
      int tidakAbsen = 0;
      final logs = <DailyAttendanceLog>[];

      for (final date in validDates) {
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final key = '${emp.id}_$dateStr';
        final inItem = checkInMap[key];
        final outItem = checkOutMap[key];

        String status = 'Tidak Absen';

        if (inItem != null) {
          final isLate = _isLate(inItem);
          if (isLate) {
            status = 'Telat';
            telat++;
          } else {
            status = 'Tepat Waktu';
          }
          hadir++;
        } else {
          if (date.weekday == DateTime.sunday) {
            status = 'Libur';
            cutiLibur++;
          } else {
            status = 'Tidak Absen';
            tidakAbsen++;
          }
        }

        logs.add(DailyAttendanceLog(
          dateStr: dateStr,
          date: date,
          status: status,
          checkIn: inItem,
          checkOut: outItem,
        ));
      }

      resultSummaries.add(EmployeeAttendanceSummary(
        karyawan: emp,
        totalHariPeriode: validDates.length,
        hadirCount: hadir,
        terlambatCount: telat,
        cutiLiburCount: cutiLibur,
        tidakAbsenCount: tidakAbsen,
        dailyLogs: logs,
      ));
    }

    // Sort by presence desc then by name
    resultSummaries.sort((a, b) {
      final comp = b.hadirCount.compareTo(a.hadirCount);
      if (comp != 0) return comp;
      return a.karyawan.nama.compareTo(b.karyawan.nama);
    });

    _summaries = resultSummaries;
    _applySearchFilter();
  }

  void _applySearchFilter() {
    var list = List<EmployeeAttendanceSummary>.from(_summaries);

    // Apply active status metric filter from clickable boxes
    if (_activeStatusMetricFilter == 'hadir') {
      list = list.where((item) => item.hadirCount > 0).toList();
    } else if (_activeStatusMetricFilter == 'telat') {
      list = list.where((item) => item.terlambatCount > 0).toList();
    } else if (_activeStatusMetricFilter == 'cuti_libur') {
      list = list.where((item) => item.cutiLiburCount > 0).toList();
    } else if (_activeStatusMetricFilter == 'tidak_absen') {
      list = list.where((item) => item.tidakAbsenCount > 0).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((item) {
        final nameMatch = item.karyawan.nama.toLowerCase().contains(q);
        final branchMatch = (item.karyawan.cabang?.namaCabang ?? '').toLowerCase().contains(q);
        return nameMatch || branchMatch;
      }).toList();
    }
    setState(() => _filteredSummaries = list);
  }

  bool _isLate(AttendanceHistoryItem item) {
    final timeStr = item.time;
    if (timeStr.contains(' ')) {
      final tParts = timeStr.split(' ').last.split(':');
      if (tParts.length >= 2) {
        final h = int.tryParse(tParts[0]) ?? 0;
        final m = int.tryParse(tParts[1]) ?? 0;
        if (h > 8 || (h == 8 && m > 15)) return true;
      }
    }
    return false;
  }

  String _getPeriodLabel() {
    final now = DateTime.now();
    if (_filterWaktu == 'hari_ini') {
      return DateFormat('d MMMM yyyy', 'id_ID').format(now);
    } else if (_filterWaktu == 'minggu_ini') {
      final start = now.subtract(Duration(days: now.weekday - 1));
      return '${DateFormat('d MMM', 'id_ID').format(start)} - ${DateFormat('d MMM yyyy', 'id_ID').format(now)}';
    } else if (_filterWaktu == 'bulan_ini') {
      return DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth);
    } else if (_filterWaktu == 'bulan_lalu') {
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      return DateFormat('MMMM yyyy', 'id_ID').format(lastMonth);
    } else if (_filterWaktu == 'custom' && _customStartDate != null && _customEndDate != null) {
      return '${DateFormat('d MMM', 'id_ID').format(_customStartDate!)} - ${DateFormat('d MMM yyyy', 'id_ID').format(_customEndDate!)}';
    }
    return DateFormat('MMMM yyyy', 'id_ID').format(now);
  }

  // Aggregate totals
  int get _totalHadir => _summaries.fold(0, (sum, e) => sum + e.hadirCount);
  int get _totalTelat => _summaries.fold(0, (sum, e) => sum + e.terlambatCount);
  int get _totalCutiLibur => _summaries.fold(0, (sum, e) => sum + e.cutiLiburCount);
  int get _totalTidakAbsen => _summaries.fold(0, (sum, e) => sum + e.tidakAbsenCount);

  Future<void> _pickCustomMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2023),
      lastDate: DateTime(now.year, now.month + 1, 0),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'PILIH BULAN & TAHUN',
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
        _filterWaktu = 'bulan_ini';
      });
      _loadData();
    }
  }

  void _showEmployeeDetailSheet(EmployeeAttendanceSummary summary) {
    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmployeeDetailModal(
        summary: summary,
        periodLabel: _getPeriodLabel(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // 1. Header
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
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
                        'Rekap Absensi',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ringkasan kehadiran & riwayat karyawan',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        _getPeriodLabel(),
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Role Segment Selector (Cleaner vs Customer Service)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildRoleButton(
                      label: 'Cleaner',
                      icon: Icons.cleaning_services_rounded,
                      isSelected: _selectedRole == 'cleaner',
                      onTap: () {
                        setState(() => _selectedRole = 'cleaner');
                        _recalculateSummaries();
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildRoleButton(
                      label: 'Customer Service',
                      icon: Icons.headset_mic_rounded,
                      isSelected: _selectedRole == 'cs',
                      onTap: () {
                        setState(() => _selectedRole = 'cs');
                        _recalculateSummaries();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Horizontal Period Filter Pills (Bulan Ini, Minggu Ini, Hari Ini, Bulan Lalu, dsb)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPeriodPill(
                    label: 'Bulan Ini',
                    isActive: _filterWaktu == 'bulan_ini',
                    onTap: () {
                      setState(() {
                        _selectedMonth = DateTime.now();
                        _filterWaktu = 'bulan_ini';
                      });
                      _loadData();
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildPeriodPill(
                    label: 'Minggu Ini',
                    isActive: _filterWaktu == 'minggu_ini',
                    onTap: () {
                      setState(() => _filterWaktu = 'minggu_ini');
                      _loadData();
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildPeriodPill(
                    label: 'Bulan Lalu',
                    isActive: _filterWaktu == 'bulan_lalu',
                    onTap: () {
                      setState(() => _filterWaktu = 'bulan_lalu');
                      _loadData();
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildPeriodPill(
                    label: 'Hari Ini',
                    isActive: _filterWaktu == 'hari_ini',
                    onTap: () {
                      setState(() => _filterWaktu = 'hari_ini');
                      _loadData();
                    },
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: _pickCustomMonth,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text(
                            'Pilih Bulan',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Overall Period Summary Header (Hadir, Telat, Cuti, Tidak Absen) - Clickable Filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                _buildStatBox(
                  label: 'Total Karyawan',
                  value: '${_summaries.length}',
                  textColor: const Color(0xFF0284C7),
                  bgColor: const Color(0xFFE0F2FE),
                  isSelected: _activeStatusMetricFilter == 'all',
                  onTap: () {
                    setState(() => _activeStatusMetricFilter = 'all');
                    _applySearchFilter();
                  },
                ),
                const SizedBox(width: 6),
                _buildStatBox(
                  label: 'Absen Masuk',
                  value: '$_totalHadir',
                  textColor: const Color(0xFF16A34A),
                  bgColor: const Color(0xFFDCFCE7),
                  isSelected: _activeStatusMetricFilter == 'hadir',
                  onTap: () {
                    setState(() => _activeStatusMetricFilter =
                        _activeStatusMetricFilter == 'hadir' ? 'all' : 'hadir');
                    _applySearchFilter();
                  },
                ),
                const SizedBox(width: 6),
                _buildStatBox(
                  label: 'Terlambat',
                  value: '$_totalTelat',
                  textColor: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                  isSelected: _activeStatusMetricFilter == 'telat',
                  onTap: () {
                    setState(() => _activeStatusMetricFilter =
                        _activeStatusMetricFilter == 'telat' ? 'all' : 'telat');
                    _applySearchFilter();
                  },
                ),
                const SizedBox(width: 6),
                _buildStatBox(
                  label: 'Cuti / Libur',
                  value: '$_totalCutiLibur',
                  textColor: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFF3E8FF),
                  isSelected: _activeStatusMetricFilter == 'cuti_libur',
                  onTap: () {
                    setState(() => _activeStatusMetricFilter =
                        _activeStatusMetricFilter == 'cuti_libur' ? 'all' : 'cuti_libur');
                    _applySearchFilter();
                  },
                ),
                const SizedBox(width: 6),
                _buildStatBox(
                  label: 'Tidak Absen',
                  value: '$_totalTidakAbsen',
                  textColor: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEE2E2),
                  isSelected: _activeStatusMetricFilter == 'tidak_absen',
                  onTap: () {
                    setState(() => _activeStatusMetricFilter =
                        _activeStatusMetricFilter == 'tidak_absen' ? 'all' : 'tidak_absen');
                    _applySearchFilter();
                  },
                ),
              ],
            ),
          ),

          // 5. Search Bar & Branch Filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: GoogleFonts.inter(fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'Cari nama karyawan...',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                  _applySearchFilter();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val);
                        _applySearchFilter();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedCabangId != null ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _selectedCabangId,
                        isExpanded: true,
                        icon: const Icon(Icons.filter_list_rounded, size: 16, color: Color(0xFF64748B)),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              'Semua Cabang',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ..._cabangList.map(
                            (c) => DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text(
                                c.namaCabang,
                                style: GoogleFonts.inter(fontSize: 11.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedCabangId = val);
                          _loadData();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 6. List of Employee Attendance Cards
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _filteredSummaries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.event_busy_rounded, size: 48, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 10),
                            Text(
                              'Tidak ada data karyawan ditemukan',
                              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: const Color(0xFF2563EB),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: _filteredSummaries.length,
                          itemBuilder: (context, index) {
                            final summary = _filteredSummaries[index];
                            return _buildEmployeeCard(summary);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodPill({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required String value,
    required Color textColor,
    required Color bgColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
            decoration: BoxDecoration(
              color: isSelected ? textColor.withValues(alpha: 0.16) : bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? textColor : Colors.transparent,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: textColor.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: textColor.withValues(alpha: isSelected ? 1.0 : 0.85),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(EmployeeAttendanceSummary summary) {
    final k = summary.karyawan;
    final rate = summary.attendancePercentage.round();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showEmployeeDetailSheet(summary),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar, Name, Branch, Rate Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildAvatar(k, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            k.nama,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  k.jabatan?.namaJabatan ?? 'Cleaner',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  k.cabang?.namaCabang ?? '-',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: rate >= 80
                            ? const Color(0xFFDCFCE7)
                            : rate >= 50
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$rate% Hadir',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: rate >= 80
                              ? const Color(0xFF16A34A)
                              : rate >= 50
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // 4-Column Stat Metrics for this Employee
                Row(
                  children: [
                    _buildMiniMetric('Hadir', '${summary.hadirCount}x', const Color(0xFF16A34A)),
                    _buildMiniMetric('Telat', '${summary.terlambatCount}x', const Color(0xFFD97706)),
                    _buildMiniMetric('Cuti/Libur', '${summary.cutiLiburCount}x', const Color(0xFF7C3AED)),
                    _buildMiniMetric('Tidak Absen', '${summary.tidakAbsenCount}x', const Color(0xFFDC2626)),
                  ],
                ),
                const SizedBox(height: 10),

                // Bottom Action Hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Lihat Riwayat Harian',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF2563EB)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(KaryawanModel karyawan, {double size = 42}) {
    return AppAvatar(
      photoUrl: karyawan.fullFotoUrl,
      name: karyawan.nama,
      size: size,
    );
  }
}

class _EmployeeDetailModal extends StatelessWidget {
  final EmployeeAttendanceSummary summary;
  final String periodLabel;

  const _EmployeeDetailModal({
    required this.summary,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final k = summary.karyawan;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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

          // Header: Employee Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        k.nama,
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${k.jabatan?.namaJabatan ?? 'Cleaner'} • ${k.cabang?.namaCabang ?? '-'} ($periodLabel)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Summary Numbers Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryCol('Hadir', '${summary.hadirCount} hari', const Color(0xFF16A34A)),
                _buildSummaryCol('Telat', '${summary.terlambatCount} kali', const Color(0xFFD97706)),
                _buildSummaryCol('Cuti/Libur', '${summary.cutiLiburCount} hari', const Color(0xFF7C3AED)),
                _buildSummaryCol('Tidak Absen', '${summary.tidakAbsenCount} hari', const Color(0xFFDC2626)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Action Bar to Open Full Calendar History
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Material(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminAttendanceDetailScreen(
                        item: GroupedAttendanceItem(
                          tanggal: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                          karyawanId: k.id,
                          namaCleaner: k.nama,
                          cabangName: k.cabang?.namaCabang,
                        ),
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 15, color: Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      Text(
                        'Buka Riwayat Kalender Lengkap',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Daily Logs List
          Expanded(
            child: summary.dailyLogs.isEmpty
                ? const Center(child: Text('Tidak ada catatan absensi'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    itemCount: summary.dailyLogs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final log = summary.dailyLogs[index];
                      return _buildDailyLogRow(context, log);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyLogRow(BuildContext context, DailyAttendanceLog log) {
    final status = log.status;
    final isHadir = status == 'Tepat Waktu';
    final isTelat = status == 'Telat';
    final isLibur = status == 'Libur';

    Color statusBg = const Color(0xFFFEE2E2);
    Color statusText = const Color(0xFFDC2626);

    if (isHadir) {
      statusBg = const Color(0xFFDCFCE7);
      statusText = const Color(0xFF16A34A);
    } else if (isTelat) {
      statusBg = const Color(0xFFFEF3C7);
      statusText = const Color(0xFFD97706);
    } else if (isLibur) {
      statusBg = const Color(0xFFF3E8FF);
      statusText = const Color(0xFF7C3AED);
    }

    final inTime = log.checkIn?.time ?? '--:--';
    final outTime = log.checkOut?.time ?? '--:--';
    final k = summary.karyawan;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AttendanceDayDetailSheet.show(
            context,
            employeeName: k.nama,
            jabatanName: k.jabatan?.namaJabatan,
            cabangName: k.cabang?.namaCabang,
            date: log.date,
            dateStr: log.dateStr,
            status: log.status,
            checkIn: log.checkIn,
            checkOut: log.checkOut,
            onOpenFullHistory: () {
              Navigator.pop(context); // close sheet
              Navigator.pop(context); // close modal
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminAttendanceDetailScreen(
                    item: GroupedAttendanceItem(
                      tanggal: log.dateStr,
                      karyawanId: k.id,
                      namaCleaner: k.nama,
                      cabangName: k.cabang?.namaCabang,
                      checkIn: log.checkIn,
                      checkOut: log.checkOut,
                    ),
                  ),
                ),
              );
            },
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              // Date Column
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('dd').format(log.date),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      DateFormat('E', 'id_ID').format(log.date),
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Hours Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(log.date),
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.login_rounded, size: 12, color: Color(0xFF16A34A)),
                        const SizedBox(width: 4),
                        Text(
                          inTime,
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.logout_rounded, size: 12, color: Color(0xFFDC2626)),
                        const SizedBox(width: 4),
                        Text(
                          outTime,
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: statusText,
                  ),
                ),
              ),

              // Check-In Photo Badge/Button
              if (log.checkIn?.selfieViewUrl != null && log.checkIn!.selfieViewUrl!.isNotEmpty) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SelfieViewerScreen(
                          attendanceId: log.checkIn!.id,
                          initialUrl: log.checkIn!.selfieViewUrl!,
                          title: 'Foto Selfie Masuk',
                          item: log.checkIn,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_camera_rounded, size: 11, color: Color(0xFF16A34A)),
                        const SizedBox(width: 2),
                        Text(
                          'In',
                          style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Check-Out Photo Badge/Button
              if (log.checkOut?.selfieViewUrl != null && log.checkOut!.selfieViewUrl!.isNotEmpty) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SelfieViewerScreen(
                          attendanceId: log.checkOut!.id,
                          initialUrl: log.checkOut!.selfieViewUrl!,
                          title: 'Foto Selfie Pulang',
                          item: log.checkOut,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF93C5FD)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_camera_rounded, size: 11, color: Color(0xFF2563EB)),
                        const SizedBox(width: 2),
                        Text(
                          'Out',
                          style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}
