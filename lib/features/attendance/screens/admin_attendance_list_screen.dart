import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  List<KaryawanModel> _allKaryawanList = [];
  List<CabangModel> _cabangList = [];

  String _selectedRole = 'cleaner'; // 'cleaner' | 'cs'

  List<GroupedAttendanceItem> _baseGroupedItems = [];
  List<GroupedAttendanceItem> _displayGroupedItems = [];

  String _filterWaktu = 'hari_ini'; // 'hari_ini', 'kemarin', 'bulan_ini', 'semua', 'custom'
  DateTime? _selectedTanggal;
  int? _selectedCabangId;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  DateTimeRange? _customRange;
  String _activeStatFilter = 'semua'; // 'semua', 'absen_masuk', 'absen_keluar', 'telat', 'tidak_absen'

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

      List<KaryawanModel> karyawans = [];
      try {
        karyawans = await _hrdService.fetchKaryawan();
      } catch (_) {}

      _allRawItems = items;
      _allKaryawanList = karyawans;
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

    final isCleaner = _selectedRole == 'cleaner';
    final targetEmployees = _allKaryawanList.where((k) {
      final role = (k.jabatan?.namaJabatan ?? '').toLowerCase();
      if (isCleaner) {
        if (!role.contains('cleaner')) return false;
      } else {
        if (!role.contains('cs') && !role.contains('customer service')) return false;
      }
      if (_selectedCabangId != null && k.cabangId != _selectedCabangId) return false;
      return true;
    }).toList();

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
      for (final emp in targetEmployees) {
        final key = '${emp.id}_$dateStr';
        final checkIn = checkInMap[key];
        final checkOut = checkOutMap[key];

        groupedList.add(GroupedAttendanceItem(
          tanggal: dateStr,
          karyawanId: emp.id,
          namaCleaner: emp.nama,
          cabangName: emp.cabang?.namaCabang ?? '-',
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

    // Apply active status filter
    if (_activeStatFilter == 'absen_masuk') {
      list = list.where((e) => e.checkIn != null).toList();
    } else if (_activeStatFilter == 'absen_keluar') {
      list = list.where((e) => e.checkOut != null).toList();
    } else if (_activeStatFilter == 'telat') {
      list = list.where((e) => _isItemLate(e)).toList();
    } else if (_activeStatFilter == 'tidak_absen') {
      list = list.where((e) => e.checkIn == null && e.checkOut == null).toList();
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

  bool get _hasActiveModalFilter =>
      _selectedCabangId != null ||
      (_filterWaktu != 'hari_ini' && _filterWaktu.isNotEmpty && _filterWaktu != 'semua') ||
      _customRange != null ||
      _selectedTanggal != null;

  String _getCabangName(int? cabangId) {
    if (cabangId == null) return 'Semua Cabang';
    final found = _cabangList.where((c) => c.id == cabangId);
    return found.isNotEmpty ? found.first.namaCabang : 'Cabang #$cabangId';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
                    // --- Role Selector: Cleaner vs Customer Service ---
                    _buildRoleSegmentedControl(),
                    const SizedBox(height: 12),

                    // --- WeeklyDatePicker ---
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

                    // --- Search Bar + Filter Button (Matching Pengajuan Style) ---
                    _buildSearchAndFilterRow(),
                    const SizedBox(height: 12),

                    // --- Status Filter ChoiceChips (Matching Pengajuan Style) ---
                    _buildStatusChoiceChipsRow(),

                    // --- Active Filter Badge Chips (if any active filter) ---
                    if (_hasActiveModalFilter) ...[
                      const SizedBox(height: 10),
                      _buildActiveFilterChips(),
                    ],
                    const SizedBox(height: 14),

                    // Section Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedRole == 'cleaner' ? 'Daftar Kehadiran Cleaner' : 'Daftar Kehadiran Customer Service',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${_displayGroupedItems.length} Data',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

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
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                _selectedRole == 'cleaner'
                                    ? 'Belum ada data absensi cleaner.'
                                    : 'Belum ada data absensi customer service.',
                                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 14),
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
                              side: const BorderSide(color: Color(0xFF2563EB)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.expand_more_rounded, color: Color(0xFF2563EB)),
                            label: Text(
                              'Tampilkan Lebih Banyak (${_visibleLimit < _displayGroupedItems.length ? _visibleLimit : _displayGroupedItems.length} dari ${_displayGroupedItems.length})',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2563EB),
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

  // --- Search Bar + Filter Button (Matching Pengajuan Style) ---
  Widget _buildSearchAndFilterRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _searchQuery.isNotEmpty ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                width: _searchQuery.isNotEmpty ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF64748B).withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _applyFilter();
              },
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: _selectedRole == 'cleaner' ? 'Cari cleaner...' : 'Cari customer service...',
                hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                          _applyFilter();
                        },
                        child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: _showFilterBottomSheet,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _hasActiveModalFilter ? const Color(0xFF2563EB) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hasActiveModalFilter ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: _hasActiveModalFilter
                      ? const Color(0xFF2563EB).withValues(alpha: 0.25)
                      : const Color(0xFF64748B).withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 22,
                  color: _hasActiveModalFilter ? Colors.white : const Color(0xFF334155),
                ),
                if (_hasActiveModalFilter)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Status Filter ChoiceChips Row (Matching Pengajuan Style) ---
  Widget _buildStatusChoiceChipsRow() {
    final filters = [
      {'key': 'semua', 'label': 'SEMUA', 'count': _baseGroupedItems.length},
      {'key': 'absen_masuk', 'label': 'MASUK', 'count': _absenMasukCount},
      {'key': 'absen_keluar', 'label': 'KELUAR', 'count': _absenKeluarCount},
      {'key': 'telat', 'label': 'TELAT', 'count': _terlambatCount},
      {'key': 'tidak_absen', 'label': 'TIDAK ABSEN', 'count': _tidakAbsenCount},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _activeStatFilter == f['key'];
          final count = f['count'] as int;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${f['label']} ($count)'),
              selected: isSelected,
              onSelected: (val) {
                setState(() {
                  _activeStatFilter = f['key'] as String;
                });
                _applyFilter();
              },
              selectedColor: const Color(0xFF2563EB),
              backgroundColor: Colors.white,
              labelStyle: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
              side: BorderSide(
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Active Filter Badge Chips ---
  Widget _buildActiveFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (_selectedCabangId != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Cabang: ${_getCabangName(_selectedCabangId)}',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() => _selectedCabangId = null);
                        _loadData();
                      },
                      child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF059669)),
                    ),
                  ],
                ),
              ),
            ),
          if (_filterWaktu != 'hari_ini' && _filterWaktu.isNotEmpty && _filterWaktu != 'semua')
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Waktu: ${_filterWaktu == 'kemarin' ? 'Kemarin' : (_filterWaktu == 'bulan_ini' ? 'Bulan Ini' : 'Custom')}',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8)),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _filterWaktu = 'hari_ini';
                          _customRange = null;
                          _selectedTanggal = null;
                        });
                        _loadData();
                      },
                      child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF1D4ED8)),
                    ),
                  ],
                ),
              ),
            ),
          InkWell(
            onTap: () {
              setState(() {
                _selectedCabangId = null;
                _filterWaktu = 'hari_ini';
                _customRange = null;
                _selectedTanggal = null;
                _activeStatFilter = 'semua';
              });
              _loadData();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                'Reset Filter',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Role Segmented Control (Cleaner vs Customer Service) ---
  Widget _buildRoleSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildRoleButton('Cleaner', 'cleaner', Icons.cleaning_services_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildRoleButton('Customer Service', 'cs', Icons.headset_mic_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton(String title, String roleKey, IconData icon) {
    final isSelected = _selectedRole == roleKey;
    return InkWell(
      onTap: () {
        if (_selectedRole != roleKey) {
          setState(() {
            _selectedRole = roleKey;
            _activeStatFilter = 'semua';
            _searchQuery = '';
            _searchCtrl.clear();
          });
          _applyFilter();
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(GroupedAttendanceItem group) {
    final bool hasCheckIn = group.checkIn != null;
    final bool hasCheckOut = group.checkOut != null;

    String statusLabel = 'Tidak Absen';
    Color statusColor = const Color(0xFFDC2626);
    Color statusBg = const Color(0xFFFEF2F2);
    Color statusBorder = const Color(0xFFFECACA);

    if (hasCheckIn && hasCheckOut) {
      statusLabel = 'Hadir Lengkap';
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFECFDF5);
      statusBorder = const Color(0xFFA7F3D0);
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
        statusColor = const Color(0xFFD97706);
        statusBg = const Color(0xFFFFFBEB);
        statusBorder = const Color(0xFFFDE68A);
      } else {
        statusLabel = 'Absen Masuk';
        statusColor = const Color(0xFF2563EB);
        statusBg = const Color(0xFFEFF6FF);
        statusBorder = const Color(0xFFBFDBFE);
      }
    }

    final initial = group.namaCleaner.trim().isNotEmpty ? group.namaCleaner.trim()[0].toUpperCase() : 'C';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Box
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1D4ED8).withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: GoogleFonts.inter(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name, Date & Branch
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  group.namaCleaner,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
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
                                  statusLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),

                          // Tanggal & Cabang Row
                          Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded, size: 13, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                group.tanggal,
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                              ),
                              if (group.cabangName != null && group.cabangName!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.storefront_rounded, size: 13, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    group.cabangName!,
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // In & Out Time Badges Row (No Detail Button)
                Row(
                  children: [
                    _buildTimeChip('Masuk', group.checkIn?.time, const Color(0xFF059669)),
                    const SizedBox(width: 8),
                    _buildTimeChip('Keluar', group.checkOut?.time, const Color(0xFF2563EB)),
                  ],
                ),
                const SizedBox(height: 10),

                // Tap Hint Footer (Matching Pengajuan Frame Indicator)
                Row(
                  children: [
                    const Icon(Icons.touch_app_outlined, size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      'Ketuk kartu untuk detail absensi',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
                  ],
                ),
              ],
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: hasData ? color.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasData ? color.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            label == 'Masuk' ? Icons.login_rounded : Icons.logout_rounded,
            size: 13,
            color: hasData ? color : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 5),
          Text(
            '$label: $displayTime',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: hasData ? color : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // --- Filter Bottom Sheet Modal (Matching Pengajuan Style) ---
  void _showFilterBottomSheet() {
    int? tempCabangId = _selectedCabangId;
    String tempWaktu = _filterWaktu;
    String tempRole = _selectedRole;

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
                      Text('Filter Absensi', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 16),

                  // 1. Role / Jabatan
                  Text('Jabatan Karyawan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      {'label': 'Cleaner', 'value': 'cleaner'},
                      {'label': 'Customer Service (CS)', 'value': 'cs'},
                    ].map((item) {
                      final isSelected = tempRole == item['value'];
                      return ChoiceChip(
                        label: Text(item['label'] as String),
                        selected: isSelected,
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: const Color(0xFFF8FAFC),
                        labelStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                        side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        showCheckmark: false,
                        onSelected: (val) {
                          setModalState(() {
                            tempRole = item['value'] as String;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // 2. Cabang Karyawan
                  if (_cabangList.isNotEmpty) ...[
                    Text('Cabang Karyawan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int?>(
                      initialValue: tempCabangId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Semua Cabang')),
                        ..._cabangList.map((c) => DropdownMenuItem(value: c.id, child: Text(c.namaCabang))),
                      ],
                      onChanged: (val) {
                        setModalState(() {
                          tempCabangId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 3. Rentang Waktu
                  Text('Rentang Waktu', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      {'key': 'hari_ini', 'label': 'Hari Ini'},
                      {'key': 'kemarin', 'label': 'Kemarin'},
                      {'key': 'bulan_ini', 'label': 'Bulan Ini'},
                      {'key': 'semua', 'label': 'Semua Waktu'},
                    ].map((item) {
                      final isSel = tempWaktu == item['key'];
                      return ChoiceChip(
                        label: Text(item['label']!),
                        selected: isSel,
                        onSelected: (val) {
                          if (val) {
                            setModalState(() {
                              tempWaktu = item['key']!;
                            });
                          }
                        },
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: const Color(0xFFF8FAFC),
                        labelStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          color: isSel ? Colors.white : const Color(0xFF475569),
                        ),
                        side: BorderSide(color: isSel ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Actions: Reset & Terapkan
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedCabangId = null;
                              _filterWaktu = 'hari_ini';
                              _customRange = null;
                              _selectedTanggal = null;
                              _activeStatFilter = 'semua';
                            });
                            _loadData();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Reset Filter',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedRole = tempRole;
                              _selectedCabangId = tempCabangId;
                              _filterWaktu = tempWaktu;
                              _customRange = null;
                              _selectedTanggal = null;
                            });
                            _loadData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Terapkan Filter',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
