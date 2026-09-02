import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../services/hrd_jadwal_libur_service.dart';

class HrdJadwalLiburScreen extends StatefulWidget {
  const HrdJadwalLiburScreen({super.key});

  @override
  State<HrdJadwalLiburScreen> createState() => _HrdJadwalLiburScreenState();
}

class _HrdJadwalLiburScreenState extends State<HrdJadwalLiburScreen> {
  bool _isLoading = true;
  List<dynamic> _cabangs = [];
  int? _selectedCabangId;
  DateTime _selectedMonth = DateTime.now();

  Map<String, dynamic> _jadwalLiburs = {};
  List<dynamic> _karyawans = [];
  List<dynamic> _karyawanSummary = [];
  Map<String, dynamic> _stats = {
    'total_libur_biasa': 0,
    'total_tukar_libur': 0,
    'total_cuti': 0,
    'total_cleaner': 0,
  };

  int _selectedDay = DateTime.now().day;
  int _activeViewIndex = 0; // 0 = Kalender, 1 = Per Karyawan
  String _searchKaryawanQuery = '';
  final TextEditingController _searchKaryawanCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final res = await HrdJadwalLiburService.getJadwalLibur(
        cabangId: _selectedCabangId,
        month: _selectedMonth.month,
        year: _selectedMonth.year,
      );

      if (mounted) {
        setState(() {
          _cabangs = res['cabangs'] is List ? (res['cabangs'] as List<dynamic>) : [];
          if (res['cabang_id'] != null) {
            _selectedCabangId = int.tryParse(res['cabang_id'].toString()) ?? _selectedCabangId;
          } else if (_cabangs.isNotEmpty && _selectedCabangId == null) {
            final first = _cabangs.first;
            if (first is Map && first['id'] != null) {
              _selectedCabangId = int.tryParse(first['id'].toString());
            }
          }

          final rawLiburs = res['jadwal_liburs'];
          final Map<String, dynamic> parsedLiburs = {};
          if (rawLiburs is Map) {
            rawLiburs.forEach((k, v) {
              parsedLiburs[k.toString()] = v;
            });
          }
          _jadwalLiburs = parsedLiburs;

          _karyawans = res['karyawans'] is List ? (res['karyawans'] as List<dynamic>) : [];
          _karyawanSummary = res['karyawan_summary'] is List ? (res['karyawan_summary'] as List<dynamic>) : [];

          final rawStats = res['stats'];
          if (rawStats is Map) {
            final Map<String, dynamic> parsedStats = {};
            rawStats.forEach((k, v) {
              parsedStats[k.toString()] = v;
            });
            _stats = parsedStats;
          }

          final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
          if (_selectedDay > daysInMonth) {
            _selectedDay = daysInMonth;
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat jadwal libur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _stepMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    });
    _fetchData();
  }

  String _monthName(int month) {
    const m = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return m[month - 1];
  }

  String _formatSelectedDateStr(int day) {
    final y = _selectedMonth.year.toString();
    final m = _selectedMonth.month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _handleToggleLibur(int karyawanId, String dateStr) async {
    try {
      final res = await HrdJadwalLiburService.toggleLibur(
        karyawanId: karyawanId,
        tanggal: dateStr,
      );

      if (mounted) {
        final action = res['action'];
        final msg = res['message'] ?? (action == 'added' ? 'Jadwal libur ditambahkan' : 'Jadwal libur dihapus');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: action == 'added' ? const Color(0xFF059669) : const Color(0xFF475569),
            duration: const Duration(seconds: 2),
          ),
        );
        _fetchData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah jadwal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDeleteLibur({
    required int karyawanId,
    required String nama,
    required String tanggal,
  }) async {
    String formattedDate = tanggal;
    try {
      final dt = DateTime.parse(tanggal);
      const dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      final dayName = dayNames[dt.weekday - 1];
      formattedDate = '$dayName, ${dt.day} ${_monthName(dt.month)} ${dt.year}';
    } catch (_) {}

    final confirm = await AppConfirmationDialog.show(
      context,
      title: 'Hapus Jadwal Libur',
      message: 'Apakah Anda yakin ingin menghapus jadwal libur untuk $nama pada tanggal $formattedDate?',
      type: ConfirmationDialogType.danger,
      confirmText: 'Ya, Hapus',
      cancelText: 'Batal',
      isDestructive: true,
    );

    if (confirm == true) {
      _handleToggleLibur(karyawanId, tanggal);
    }
  }

  Future<void> _handleGeneratePola() async {
    if (_selectedCabangId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih cabang terlebih dahulu.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final monthNameStr = '${_monthName(_selectedMonth.month)} ${_selectedMonth.year}';

    final confirm = await AppConfirmationDialog.show(
      context,
      title: 'Generate Pola Libur',
      message: 'Anda yakin ingin men-generate jadwal libur dari pola bulan sebelumnya? Jadwal libur yang sudah ada di bulan $monthNameStr akan tertimpa!',
      type: ConfirmationDialogType.info,
      confirmText: 'Ya, Generate Pola',
      cancelText: 'Batal',
      customIcon: Icons.auto_awesome_rounded,
      contentWidget: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Semua jadwal libur pada periode $monthNameStr akan ditimpa dengan rotasi pola baru.',
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF991B1B)),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final res = await HrdJadwalLiburService.generatePola(
        cabangId: _selectedCabangId!,
        month: _selectedMonth.month,
        year: _selectedMonth.year,
      );

      if (mounted) Navigator.pop(context); // close loading

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Pola jadwal libur berhasil di-generate.'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        _fetchData();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // close loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal men-generate pola: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          GradientHeader(
            padding: EdgeInsets.fromLTRB(20, 52, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 16 : 20),
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
                        'Jadwal Libur Karyawan',
                        style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Atur & pantau hari libur bulanan cabang',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _fetchData,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Body Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Controls: Cabang Selector & Month Switcher
                    _buildCabangAndMonthSelector(),
                    const SizedBox(height: 12),

                    // 4 Stat Summary Cards
                    _buildStatSummaryRow(),
                    const SizedBox(height: 12),

                    // Legend & Generate Pola Action Row
                    _buildLegendAndGenerateAction(),
                    const SizedBox(height: 14),

                    // View Segmented Switcher (Kalender / Per Karyawan)
                    _buildViewSegmentedBar(),
                    const SizedBox(height: 14),

                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_activeViewIndex == 0)
                      _buildCalendarView()
                    else
                      _buildKaryawanRosterView(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. CABANG & MONTH SELECTOR ---
  Widget _buildCabangAndMonthSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        children: [
          // Cabang Selector
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _selectedCabangId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Pilih Cabang',
                    labelStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  items: _cabangs.map((c) {
                    final cId = int.tryParse(c['id']?.toString() ?? '');
                    return DropdownMenuItem<int?>(
                      value: cId,
                      child: Text(
                        c['nama_cabang']?.toString() ?? 'Cabang',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null && val != _selectedCabangId) {
                      setState(() => _selectedCabangId = val);
                      _fetchData();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Month Switcher Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text(
                    'Periode: ${_monthName(_selectedMonth.month)} ${_selectedMonth.year}',
                    style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _stepMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    color: const Color(0xFF334155),
                  ),
                  IconButton(
                    onPressed: () => _stepMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    color: const Color(0xFF334155),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 2. STAT SUMMARY ROW (4 STATS) ---
  Widget _buildStatSummaryRow() {
    final biasa = _stats['total_libur_biasa'] ?? 0;
    final tukar = _stats['total_tukar_libur'] ?? 0;
    final cuti = _stats['total_cuti'] ?? 0;
    final cleaner = _stats['total_cleaner'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildSingleStatCard(
            title: 'Libur Biasa',
            value: '$biasa',
            color: const Color(0xFF2563EB),
            bg: const Color(0xFFEFF6FF),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildSingleStatCard(
            title: 'Tukar Libur',
            value: '$tukar',
            color: const Color(0xFFD97706),
            bg: const Color(0xFFFFFBEB),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildSingleStatCard(
            title: 'Cuti',
            value: '$cuti',
            color: const Color(0xFF059669),
            bg: const Color(0xFFECFDF5),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildSingleStatCard(
            title: 'Cleaner',
            value: '$cleaner',
            color: const Color(0xFF7C3AED),
            bg: const Color(0xFFF5F3FF),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleStatCard({
    required String title,
    required String value,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
          ),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- 3. LEGEND & GENERATE POLA ACTION ---
  Widget _buildLegendAndGenerateAction() {
    return Column(
      children: [
        // Legend row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem(label: 'Libur Biasa', color: const Color(0xFF2563EB)),
              _buildLegendItem(label: 'Tukar Libur', color: const Color(0xFFD97706)),
              _buildLegendItem(label: 'Cuti', color: const Color(0xFF059669)),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Generate Pola Button
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _handleGeneratePola,
            icon: const Icon(Icons.auto_awesome_rounded, size: 19, color: Colors.white),
            label: Text(
              'Generate Pola Libur Bulan Ini',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem({required String label, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
        ),
      ],
    );
  }

  // --- 4. VIEW SEGMENTED BAR ---
  Widget _buildViewSegmentedBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton(
              title: '📅 Kalender & Hari',
              index: 0,
            ),
          ),
          Expanded(
            child: _buildSegmentButton(
              title: '👥 Per Karyawan',
              index: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({required String title, required int index}) {
    final isSelected = _activeViewIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _activeViewIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  // --- 5. VIEW 1: CALENDAR VIEW & SELECTED DAY INSPECTOR ---
  Widget _buildCalendarView() {
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    // Monday = 1, Sunday = 7. Start offset: Monday is 0
    final startOffset = firstDayOfMonth.weekday - 1;
    final totalCells = ((daysInMonth + startOffset) / 7).ceil() * 7;

    final selectedDateStr = _formatSelectedDateStr(_selectedDay);
    final scheduledCleanersToday = (_jadwalLiburs[selectedDateStr] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Monthly Calendar Grid Card
        Container(
          padding: const EdgeInsets.all(14),
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
          child: Column(
            children: [
              // Weekday Header
              Row(
                children: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'].asMap().entries.map((entry) {
                  final idx = entry.key;
                  final name = entry.value;
                  final isSunday = idx == 6;
                  return Expanded(
                    child: Center(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isSunday ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 8),

              // Days Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: totalCells,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 6,
                  childAspectRatio: 0.80,
                ),
                itemBuilder: (context, index) {
                  final dayNumber = index - startOffset + 1;
                  final isValid = dayNumber >= 1 && dayNumber <= daysInMonth;

                  if (!isValid) {
                    return const SizedBox();
                  }

                  final dateStr = _formatSelectedDateStr(dayNumber);
                  final libursOnDate = (_jadwalLiburs[dateStr] as List<dynamic>?) ?? [];
                  final isSelected = dayNumber == _selectedDay;
                  final isSunday = (index % 7) == 6;

                  final now = DateTime.now();
                  final isToday = now.year == _selectedMonth.year && now.month == _selectedMonth.month && now.day == dayNumber;

                  return InkWell(
                    onTap: () => setState(() => _selectedDay = dayNumber),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : (isSunday ? const Color(0xFFFEF2F2).withValues(alpha: 0.6) : Colors.transparent),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : (isToday ? const Color(0xFF3B82F6) : Colors.transparent),
                          width: isToday && !isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$dayNumber',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isSunday ? const Color(0xFFDC2626) : const Color(0xFF0F172A)),
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (libursOnDate.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? Colors.white : const Color(0xFFBFDBFE),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '${libursOnDate.length}',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : const Color(0xFF2563EB),
                                  height: 1.1,
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Selected Day Inspector Card
        _buildSelectedDayInspector(selectedDateStr, scheduledCleanersToday),
      ],
    );
  }

  Widget _buildSelectedDayInspector(String selectedDateStr, List<dynamic> scheduledCleaners) {
    final dt = DateTime(_selectedMonth.year, _selectedMonth.month, _selectedDay);
    const dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final dayName = dayNames[dt.weekday - 1];
    final fullDateText = '$dayName, $_selectedDay ${_monthName(_selectedMonth.month)} ${_selectedMonth.year}';

    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Inspector Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullDateText,
                      style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${scheduledCleaners.length} Cleaner Dijadwalkan Libur',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddCleanerModal(selectedDateStr),
                  icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  label: Text(
                    'Tambah',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            // Cleaners List on this date
            if (scheduledCleaners.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_busy_rounded, size: 36, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text(
                        'Belum ada cleaner yang libur di tanggal ini.',
                        style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tekan tombol "+ Tambah" di atas untuk menjadwalkan.',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: scheduledCleaners.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final item = scheduledCleaners[idx];
                  final kId = int.tryParse(item['karyawan_id']?.toString() ?? '') ?? 0;
                  final nama = item['nama']?.toString() ?? 'Cleaner';
                  final type = item['type']?.toString() ?? 'libur_biasa';
                  final isCuti = type == 'cuti';
                  final isTukar = type == 'tukar_libur';

                  Color badgeColor = const Color(0xFF2563EB);
                  Color badgeBg = const Color(0xFFEFF6FF);
                  Color badgeBorder = const Color(0xFFBFDBFE);
                  String badgeText = 'Libur Biasa';

                  if (isTukar) {
                    badgeColor = const Color(0xFFD97706);
                    badgeBg = const Color(0xFFFFFBEB);
                    badgeBorder = const Color(0xFFFDE68A);
                    badgeText = 'Tukar Libur';
                  } else if (isCuti) {
                    badgeColor = const Color(0xFF059669);
                    badgeBg = const Color(0xFFECFDF5);
                    badgeBorder = const Color(0xFFA7F3D0);
                    badgeText = 'Cuti';
                  }

                  final initial = nama.trim().isNotEmpty ? nama.trim()[0].toUpperCase() : 'C';

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: badgeBg,
                          child: Text(
                            initial,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: badgeColor),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nama,
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: badgeBorder),
                                ),
                                child: Text(
                                  badgeText,
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isCuti)
                          InkWell(
                            onTap: () => _confirmDeleteLibur(
                              karyawanId: kId,
                              nama: nama,
                              tanggal: selectedDateStr,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Text(
                                'Hapus',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // --- 6. VIEW 2: KARYAWAN ROSTER SUMMARY ---
  Widget _buildKaryawanRosterView() {
    final filteredCleaners = _karyawanSummary.where((k) {
      if (_searchKaryawanQuery.isEmpty) return true;
      final name = (k['nama'] ?? '').toString().toLowerCase();
      return name.contains(_searchKaryawanQuery.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search cleaner bar
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _searchKaryawanQuery.isNotEmpty ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              width: _searchKaryawanQuery.isNotEmpty ? 1.5 : 1.0,
            ),
          ),
          child: TextField(
            controller: _searchKaryawanCtrl,
            onChanged: (val) => setState(() => _searchKaryawanQuery = val),
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Cari nama cleaner...',
              hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
              suffixIcon: _searchKaryawanQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchKaryawanCtrl.clear();
                        setState(() => _searchKaryawanQuery = '');
                      },
                      child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Cleaner list
        if (filteredCleaners.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(
                'Tidak ada data cleaner ditemukan.',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredCleaners.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final k = filteredCleaners[idx];
              final kId = int.tryParse(k['id']?.toString() ?? '') ?? 0;
              final nama = k['nama']?.toString() ?? 'Cleaner';
              final totalLibur = k['total_libur'] ?? 0;
              final dates = (k['dates'] is List ? k['dates'] as List<dynamic> : []);

              final initial = nama.trim().isNotEmpty ? nama.trim()[0].toUpperCase() : 'C';

              return Container(
                padding: const EdgeInsets.all(14),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFEFF6FF),
                          child: Text(
                            initial,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nama,
                                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              ),
                              Text(
                                'Cleaner • ${_cabangs.firstWhere((c) => c['id'] == _selectedCabangId, orElse: () => {})['nama_cabang'] ?? '-'}',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            '$totalLibur Hari Libur',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),

                    // List of Date Chips for this cleaner
                    if (dates.isEmpty)
                      Text(
                        'Belum ada jadwal libur bulan ini.',
                        style: GoogleFonts.inter(fontSize: 11.5, fontStyle: FontStyle.italic, color: const Color(0xFF94A3B8)),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: dates.map((dItem) {
                          final dateStr = (dItem['tanggal'] ?? '').toString();
                          final type = (dItem['type'] ?? 'libur_biasa').toString();
                          final isCuti = type == 'cuti';
                          final isTukar = type == 'tukar_libur';

                          Color chipColor = const Color(0xFF2563EB);
                          Color chipBg = const Color(0xFFEFF6FF);
                          Color chipBorder = const Color(0xFFBFDBFE);

                          if (isTukar) {
                            chipColor = const Color(0xFFD97706);
                            chipBg = const Color(0xFFFFFBEB);
                            chipBorder = const Color(0xFFFDE68A);
                          } else if (isCuti) {
                            chipColor = const Color(0xFF059669);
                            chipBg = const Color(0xFFECFDF5);
                            chipBorder = const Color(0xFFA7F3D0);
                          }

                          String formattedChip = dateStr;
                          try {
                            final parsed = DateTime.parse(dateStr);
                            formattedChip = '${parsed.day} ${_monthName(parsed.month).substring(0, 3)}';
                          } catch (_) {}

                          return InkWell(
                            onTap: isCuti
                                ? null
                                : () => _confirmDeleteLibur(
                                      karyawanId: kId,
                                      nama: nama,
                                      tanggal: dateStr,
                                    ),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: chipBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: chipBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formattedChip,
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: chipColor),
                                  ),
                                  if (!isCuti) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.close_rounded, size: 12, color: chipColor),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // --- 7. BOTTOM SHEET MODAL: TAMBAH CLEANER LIBUR PADA TANGGAL ---
  void _showAddCleanerModal(String targetDateStr) {
    final currentLiburs = (_jadwalLiburs[targetDateStr] as List<dynamic>?) ?? [];
    final existingKaryawanIds = currentLiburs.map((item) => item['karyawan_id']).toSet();

    final availableCleaners = _karyawans.where((k) => !existingKaryawanIds.contains(k['id'])).toList();

    String formattedDateText = targetDateStr;
    try {
      final dt = DateTime.parse(targetDateStr);
      const dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      final dayName = dayNames[dt.weekday - 1];
      formattedDateText = '$dayName, ${dt.day} ${_monthName(dt.month)} ${dt.year}';
    } catch (_) {}

    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tambah Cleaner Libur',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedDateText,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF2563EB), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
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
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 14),

              if (availableCleaners.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Semua cleaner di cabang ini sudah dijadwalkan libur pada tanggal ini.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: availableCleaners.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final k = availableCleaners[index];
                      final nama = k['nama'] ?? 'Cleaner';
                      final initial = nama.trim().isNotEmpty ? nama.trim()[0].toUpperCase() : 'C';

                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          final cleanerId = int.tryParse(k['id']?.toString() ?? '') ?? 0;
                          _handleToggleLibur(cleanerId, targetDateStr);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFFEFF6FF),
                                child: Text(
                                  initial,
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  nama,
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                ),
                              ),
                              const Icon(Icons.add_circle_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
