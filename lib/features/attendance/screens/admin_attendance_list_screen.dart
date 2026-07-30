import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../../../core/widgets/weekly_date_picker.dart';
import '../../../../core/data/hrd_models.dart';
import '../../hrd/services/hrd_service.dart';
import '../data/attendance_model.dart';
import '../services/attendance_service.dart';
import 'admin_attendance_detail_screen.dart';

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
  List<KaryawanModel> _allCleaners = [];
  List<CabangModel> _cabangList = [];

  List<GroupedAttendanceItem> _baseGroupedItems = [];
  List<GroupedAttendanceItem> _displayGroupedItems = [];

  String _filterWaktu = 'hari_ini'; // 'hari_ini', 'kemarin', 'bulan_ini', 'semua'
  DateTime? _selectedTanggal;
  int? _selectedCabangId;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  DateTimeRange? _customRange;
  String? _activeStatFilter; // null, 'absen_masuk', 'absen_keluar', 'telat', 'tidak_absen'

  bool _isFinance = false;
  int? _userCabangId;

  @override
  void initState() {
    super.initState();
    _initPrefs();
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

    if (_allCleaners.isNotEmpty) {
      final Map<int, CabangModel> map = {};
      for (var c in _allCleaners) {
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
      if (_selectedTanggal != null) {
        dateParam = DateFormat('yyyy-MM-dd').format(_selectedTanggal!);
      } else if (_filterWaktu == 'hari_ini') {
        dateParam = DateFormat('yyyy-MM-dd').format(now);
      } else if (_filterWaktu == 'kemarin') {
        dateParam = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
      } else if (_filterWaktu == 'bulan_ini') {
        monthParam = DateFormat('yyyy-MM').format(now);
      } else if (_filterWaktu == 'semua') {
        dateParam = null;
        monthParam = null;
      }

      final items = await _service.getAllAbsensi(
        date: dateParam,
        month: monthParam,
        branch: branchParam,
      );

      List<KaryawanModel> cleaners = [];
      try {
        cleaners = await _hrdService.fetchKaryawan();
        cleaners = cleaners.where((k) {
          final role = k.jabatan?.namaJabatan.toLowerCase() ?? '';
          return role.contains('cleaner');
        }).toList();
      } catch (_) {}

      _allRawItems = items;
      _allCleaners = cleaners;
      _loadCabangs();
      _applyFilter();
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

  Future<void> _selectTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedTanggal ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedTanggal = picked;
        _filterWaktu = '';
      });
      _loadData();
    }
  }

  List<String> _getFilterDateStrings() {
    final now = DateTime.now();
    if (_selectedTanggal != null) {
      return [DateFormat('yyyy-MM-dd').format(_selectedTanggal!)];
    }
    if (_filterWaktu == 'hari_ini') {
      return [DateFormat('yyyy-MM-dd').format(now)];
    } else if (_filterWaktu == 'kemarin') {
      return [DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)))];
    } else if (_filterWaktu == 'bulan_ini' || _filterWaktu == 'semua') {
      final start = DateTime(now.year, now.month, 1);
      final dates = <String>[];
      for (var d = now; !d.isBefore(start); d = d.subtract(const Duration(days: 1))) {
        dates.add(DateFormat('yyyy-MM-dd').format(d));
      }
      return dates;
    }
    return [DateFormat('yyyy-MM-dd').format(now)];
  }

  int _visibleLimit = 25;

  void _applyFilter() {
    _visibleLimit = 25;
    final validDates = _getFilterDateStrings();

    final filteredCleaners = _allCleaners.where((c) {
      if (_selectedCabangId != null && c.cabangId != _selectedCabangId) return false;
      return true;
    }).toList();

    // Pre-build HashMap for instant O(1) lookup
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

    final groupedList = <GroupedAttendanceItem>[];

    for (final dateStr in validDates) {
      for (final cleaner in filteredCleaners) {
        final key = '${cleaner.id}_$dateStr';
        final checkIn = checkInMap[key];
        final checkOut = checkOutMap[key];

        groupedList.add(GroupedAttendanceItem(
          tanggal: dateStr,
          karyawanId: cleaner.id,
          namaCleaner: cleaner.nama,
          cabangName: cleaner.cabang?.namaCabang ?? '-',
          checkIn: checkIn,
          checkOut: checkOut,
        ));
      }
    }

    var list = List<GroupedAttendanceItem>.from(groupedList);

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((item) => item.namaCleaner.toLowerCase().contains(q)).toList();
    }

    list.sort((a, b) => b.tanggal.compareTo(a.tanggal));
    _baseGroupedItems = list;

    // Apply stat filter
    if (_activeStatFilter != null) {
      if (_activeStatFilter == 'absen_masuk') {
        list = list.where((e) => e.checkIn != null).toList();
      } else if (_activeStatFilter == 'absen_keluar') {
        list = list.where((e) => e.checkOut != null).toList();
      } else if (_activeStatFilter == 'telat') {
        list = list.where((e) => _isItemLate(e)).toList();
      } else if (_activeStatFilter == 'tidak_absen') {
        list = list.where((e) => e.checkIn == null && e.checkOut == null).toList();
      }
    }

    setState(() => _displayGroupedItems = list);
  }

  bool _isItemLate(GroupedAttendanceItem item) {
    if (item.checkIn == null) return false;
    final timeStr = item.checkIn!.time;
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

  // --- Stats calculations from _baseGroupedItems ---
  int get _absenMasukCount => _baseGroupedItems.where((e) => e.checkIn != null).length;
  int get _absenKeluarCount => _baseGroupedItems.where((e) => e.checkOut != null).length;
  int get _terlambatCount => _baseGroupedItems.where((e) => _isItemLate(e)).length;
  int get _tidakAbsenCount => _baseGroupedItems.where((e) => e.checkIn == null && e.checkOut == null).length;

  void _toggleStatFilter(String filterKey) {
    setState(() {
      if (_activeStatFilter == filterKey) {
        _activeStatFilter = null;
      } else {
        _activeStatFilter = filterKey;
      }
    });
    _applyFilter();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                          const SizedBox(width: 12),
                          Text(
                            'Daftar Absensi',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pantau riwayat & rekapan kehadiran karyawan',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- WeeklyDatePicker (Sama seperti CS List Pesanan & Insentif) ---
                    WeeklyDatePicker(
                      showAllMonthButton: false,
                      onFilterChanged: (start, end) {
                        if (start == null && end == null) {
                          _selectedTanggal = null;
                          _filterWaktu = 'semua';
                        } else if (start != null && end != null) {
                          final startStr = DateFormat('yyyy-MM-dd').format(start);
                          final endStr = DateFormat('yyyy-MM-dd').format(end);
                          if (startStr == endStr || (start.day == end.day && start.month == end.month && start.year == end.year)) {
                            _selectedTanggal = start;
                            _filterWaktu = '';
                          } else {
                            _selectedTanggal = null;
                            _filterWaktu = 'bulan_ini';
                          }
                        }
                        _loadData();
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildProMaxSearchAndFilterBar(),

                    // Stat Summary Cards (di bawah cabang dropdown, geser kanan)
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildInteractiveStatChip(
                              'Absen Masuk',
                              '$_absenMasukCount',
                              Icons.login_rounded,
                              const Color(0xFF2E7D32),
                              const Color(0xFFE8F5E9),
                              'absen_masuk',
                            ),
                            const SizedBox(width: 8),
                            _buildInteractiveStatChip(
                              'Absen Keluar',
                              '$_absenKeluarCount',
                              Icons.logout_rounded,
                              const Color(0xFF1565C0),
                              const Color(0xFFE3F2FD),
                              'absen_keluar',
                            ),
                            const SizedBox(width: 8),
                            _buildInteractiveStatChip(
                              'Telat',
                              '$_terlambatCount',
                              Icons.schedule_rounded,
                              const Color(0xFFF57F17),
                              const Color(0xFFFFF8E1),
                              'telat',
                            ),
                            const SizedBox(width: 8),
                            _buildInteractiveStatChip(
                              'Tidak Absen',
                              '$_tidakAbsenCount',
                              Icons.cancel_rounded,
                              const Color(0xFFC62828),
                              const Color(0xFFFFEBEE),
                              'tidak_absen',
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_activeStatFilter != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Filter Active: ${_getStatFilterLabel(_activeStatFilter!)}',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  setState(() => _activeStatFilter = null);
                                  _applyFilter();
                                },
                                child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),

                    // Section Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daftar Kehadiran Cleaner',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          '${_displayGroupedItems.length} Data',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // --- List Items ---
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_displayGroupedItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'Belum ada data absensi.',
                                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _displayGroupedItems.length < _visibleLimit
                            ? _displayGroupedItems.length
                            : _visibleLimit,
                        itemBuilder: (context, index) {
                          final group = _displayGroupedItems[index];
                          return _buildAttendanceCard(group);
                        },
                      ),
                      if (_displayGroupedItems.length > _visibleLimit) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _visibleLimit += 25;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.expand_more_rounded, color: AppColors.primary),
                            label: Text(
                              'Tampilkan Lebih Banyak (${_visibleLimit < _displayGroupedItems.length ? _visibleLimit : _displayGroupedItems.length} dari ${_displayGroupedItems.length})',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatFilterLabel(String key) {
    switch (key) {
      case 'absen_masuk':
        return 'Absen Masuk';
      case 'absen_keluar':
        return 'Absen Keluar';
      case 'telat':
        return 'Terlambat';
      case 'tidak_absen':
        return 'Tidak Absen';
      default:
        return key;
    }
  }

  Widget _buildInteractiveStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color bgColor,
    String filterKey,
  ) {
    final bool isActive = _activeStatFilter == filterKey;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _toggleStatFilter(filterKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.15) : bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? color : color.withValues(alpha: 0.2),
              width: isActive ? 2.5 : 1.0,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: color,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActive)
                          Icon(Icons.check_circle_rounded, size: 14, color: color),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(GroupedAttendanceItem group) {
    final bool hasCheckIn = group.checkIn != null;
    final bool hasCheckOut = group.checkOut != null;

    // Status logic:
    String statusLabel = 'Tidak Absen';
    Color statusColor = const Color(0xFFC62828);
    Color statusBg = const Color(0xFFFFEBEE);

    if (hasCheckIn && hasCheckOut) {
      statusLabel = 'Hadir Lengkap';
      statusColor = const Color(0xFF2E7D32);
      statusBg = const Color(0xFFE8F5E9);
    } else if (hasCheckIn && !hasCheckOut) {
      final timeStr = group.checkIn!.time;
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminAttendanceDetailScreen(item: group),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar Circle
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1D4ED8).withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      group.namaCleaner.isNotEmpty ? group.namaCleaner[0].toUpperCase() : 'C',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Name & Branch & Times
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name & Status Badge Row with Flexible overflow prevention
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              group.namaCleaner,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                statusLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Tanggal & Cabang
                      Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            group.tanggal,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                          ),
                          if (group.cabangName != null && group.cabangName!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.storefront_rounded, size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              group.cabangName!,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),

                      // CheckIn / CheckOut Badges
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _buildTimeChip('Masuk', group.checkIn?.time, const Color(0xFF2E7D32)),
                              const SizedBox(width: 8),
                              _buildTimeChip('Keluar', group.checkOut?.time, const Color(0xFF1565C0)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              'Detail',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveStatChip(
    String label,
    String count,
    IconData icon,
    Color textColor,
    Color bgColor,
    String filterKey,
  ) {
    final bool isSelected = _activeStatFilter == filterKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_activeStatFilter == filterKey) {
            _activeStatFilter = null;
          } else {
            _activeStatFilter = filterKey;
          }
        });
        _applyFilter();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? textColor : bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? textColor : textColor.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: textColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : textColor),
            const SizedBox(width: 6),
            Text(
              '$label: ',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : textColor,
              ),
            ),
            Text(
              count,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip(String label, String? rawTimeStr, Color color) {
    final bool hasData = rawTimeStr != null && rawTimeStr.isNotEmpty;
    String displayTime = '--:--';
    if (hasData) {
      final parts = rawTimeStr.split(' ');
      displayTime = parts.last;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: hasData ? color.withValues(alpha: 0.08) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasData ? color.withValues(alpha: 0.3) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            label == 'Masuk' ? Icons.login_rounded : Icons.logout_rounded,
            size: 13,
            color: hasData ? color : Colors.grey.shade400,
          ),
          const SizedBox(width: 4),
          Text(
            displayTime,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: hasData ? color : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // --- Modern Filter UI ---
  Widget _buildProMaxSearchAndFilterBar() {
    final int activeFilterCount = (_selectedCabangId != null ? 1 : 0) +
        (_filterWaktu != 'semua' && _filterWaktu.isNotEmpty ? 1 : 0) +
        (_customRange != null || _selectedTanggal != null ? 1 : 0);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: _searchQuery.isNotEmpty ? const Color(0xFF3B82F6) : Colors.grey.withValues(alpha: 0.25),
                width: _searchQuery.isNotEmpty ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _searchQuery.isNotEmpty ? const Color(0xFF3B82F6).withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: _searchQuery.isNotEmpty ? const Color(0xFF2563EB) : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                      _applyFilter();
                    },
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'Cari cleaner...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                      _applyFilter();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, size: 14, color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _showFilterBottomSheet(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: activeFilterCount > 0
                  ? const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF4F46E5)])
                  : null,
              color: activeFilterCount > 0 ? null : Colors.white,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: activeFilterCount > 0 ? Colors.transparent : Colors.grey.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                if (activeFilterCount > 0)
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: activeFilterCount > 0 ? Colors.white : AppColors.textDark,
                ),
                const SizedBox(width: 6),
                Text(
                  'Filter',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: activeFilterCount > 0 ? Colors.white : AppColors.textDark,
                  ),
                ),
                if (activeFilterCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$activeFilterCount',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Filter Absensi', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // 1. Cabang
                  if (_cabangList.isNotEmpty) ...[
                    Text('Pilih Cabang', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Semua Cabang'),
                          selected: _selectedCabangId == null,
                          onSelected: (val) {
                            setModalState(() => _selectedCabangId = null);
                            setState(() => _selectedCabangId = null);
                            _loadData();
                          },
                          selectedColor: const Color(0xFFEFF6FF),
                          labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: _selectedCabangId == null ? FontWeight.bold : FontWeight.w500, color: _selectedCabangId == null ? const Color(0xFF1D4ED8) : AppColors.textDark),
                          side: BorderSide(color: _selectedCabangId == null ? const Color(0xFF3B82F6) : Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          showCheckmark: false,
                        ),
                        ..._cabangList.map((c) {
                          final isSel = _selectedCabangId == c.id;
                          return ChoiceChip(
                            label: Text(c.namaCabang),
                            selected: isSel,
                            onSelected: (val) {
                              setModalState(() => _selectedCabangId = val ? c.id : null);
                              setState(() => _selectedCabangId = val ? c.id : null);
                              _loadData();
                            },
                            selectedColor: const Color(0xFFEFF6FF),
                            labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? const Color(0xFF1D4ED8) : AppColors.textDark),
                            side: BorderSide(color: isSel ? const Color(0xFF3B82F6) : Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            showCheckmark: false,
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 2. Rentang Waktu
                  Text('Rentang Waktu', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...[
                        {'key': 'semua', 'label': 'Semua Waktu'},
                        {'key': 'hari_ini', 'label': 'Hari Ini'},
                        {'key': 'kemarin', 'label': 'Kemarin'},
                        {'key': 'bulan_ini', 'label': 'Bulan Ini'},
                      ].map((item) {
                        final isSel = _filterWaktu == item['key'] && _selectedTanggal == null;
                        return ChoiceChip(
                          label: Text(item['label']!),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                _filterWaktu = item['key']!;
                                _customRange = null;
                                _selectedTanggal = null;
                              });
                              setState(() {
                                _filterWaktu = item['key']!;
                                _customRange = null;
                                _selectedTanggal = null;
                              });
                              _loadData();
                            }
                          },
                          selectedColor: const Color(0xFFECFDF5),
                          labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? const Color(0xFF047857) : AppColors.textDark),
                          side: BorderSide(color: isSel ? const Color(0xFF10B981) : Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          showCheckmark: false,
                        );
                      }),
                      ActionChip(
                        avatar: const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF4F46E5)),
                        label: Text(
                          _filterWaktu == 'custom' && _customRange != null
                              ? '${DateFormat('dd/MM').format(_customRange!.start)} - ${DateFormat('dd/MM').format(_customRange!.end)}'
                              : 'Pilih Tanggal',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: _filterWaktu == 'custom' ? FontWeight.bold : FontWeight.w500, color: _filterWaktu == 'custom' ? const Color(0xFF4F46E5) : AppColors.textDark),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _pickCustomRange();
                        },
                        backgroundColor: _filterWaktu == 'custom' ? const Color(0xFFEEF2FF) : Colors.white,
                        side: BorderSide(color: _filterWaktu == 'custom' ? const Color(0xFF6366F1) : Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _customRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _filterWaktu = 'custom';
        _selectedTanggal = picked.start;
      });
      _loadData();
    }
  }
}
