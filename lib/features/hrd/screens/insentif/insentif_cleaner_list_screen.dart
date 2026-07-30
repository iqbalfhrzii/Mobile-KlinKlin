import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/data/hrd_models.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../../../core/widgets/weekly_date_picker.dart';
import '../../services/hrd_service.dart';

class InsentifCleanerListScreen extends StatefulWidget {
  const InsentifCleanerListScreen({super.key});

  @override
  State<InsentifCleanerListScreen> createState() => _InsentifCleanerListScreenState();
}

class _InsentifCleanerListScreenState extends State<InsentifCleanerListScreen> {
  final HrdService _hrdService = HrdService();
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool _isLoading = true;
  String _filterWaktu = 'bulan_ini'; // bulan_ini, hari_ini, kemarin, semua
  int? _selectedCabangId;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  DateTimeRange? _customRange;

  DateTime? _selectedTanggal;
  List<InsentifCleanerModel> _allData = [];
  List<CabangModel> _cabangList = [];
  int _visibleLimit = 25;
  int _totalInsentifGlobal = 0;
  int _jumlahCleanerGlobal = 0;

  @override
  void initState() {
    super.initState();
    _loadCabangs();
    _fetchData();
  }

  Future<void> _loadCabangs() async {
    try {
      final res = await _hrdService.fetchCabang();
      if (mounted) setState(() => _cabangList = res);
    } catch (_) {}
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
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _visibleLimit = 25;
    });
    try {
      final tglStr = _selectedTanggal != null
          ? DateFormat('yyyy-MM-dd').format(_selectedTanggal!)
          : null;
      final res = await _hrdService.fetchInsentifCleaner(
        filterWaktu: _filterWaktu,
        filterCabang: _selectedCabangId,
        filterTanggal: tglStr,
      );
      if (mounted) {
        setState(() {
          _allData = res['data'] as List<InsentifCleanerModel>;
          _totalInsentifGlobal = res['total_insentif'] as int;
          _jumlahCleanerGlobal = res['jumlah_cleaner'] as int;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<InsentifCleanerModel> get _filteredData {
    if (_searchQuery.trim().isEmpty) return _allData;
    return _allData
        .where((e) => e.namaCleaner.toLowerCase().contains(_searchQuery.toLowerCase().trim()))
        .toList();
  }

  void _showDetailModal(InsentifCleanerModel item) async {
    final tglStr = _selectedTanggal != null
        ? DateFormat('yyyy-MM-dd').format(_selectedTanggal!)
        : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _InsentifDetailBottomSheet(
        item: item,
        filterWaktu: _filterWaktu,
        filterTanggal: tglStr,
        hrdService: _hrdService,
        currencyFormatter: currencyFormatter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (Navigator.canPop(context)) ...[
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Text(
                      'Insentif Cleaner',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Pantau dan kelola insentif / bonus cleaner',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- WeeklyDatePicker (Sama seperti CS List Pesanan) ---
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
                        _fetchData();
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFA5D6A7)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.payments_rounded, size: 14, color: Color(0xFF2E7D32)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Total Insentif: ',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2E7D32),
                                    ),
                                  ),
                                  Text(
                                    currencyFormatter.format(_totalInsentifGlobal),
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1B5E20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF90CAF9)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.people_alt_rounded, size: 14, color: Color(0xFF1565C0)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Cleaner: ',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1565C0),
                                    ),
                                  ),
                                  Text(
                                    '$_jumlahCleanerGlobal Cleaner',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0D47A1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // List Header
                    Text(
                      'Daftar Insentif Cleaner',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Cleaner List
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_filteredData.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.payments_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada data insentif cleaner',
                              style: GoogleFonts.inter(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredData.length < _visibleLimit
                            ? _filteredData.length
                            : _visibleLimit,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _filteredData[index];
                          return Container(
                            padding: const EdgeInsets.all(16),
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
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF2DD4BF), Color(0xFF0F766E)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0F766E).withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      item.namaCleaner.isNotEmpty ? item.namaCleaner[0].toUpperCase() : 'C',
                                      style: GoogleFonts.inter(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.namaCleaner,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textDark,
                                          letterSpacing: -0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.storefront_rounded, size: 14, color: AppColors.textMuted),
                                          const SizedBox(width: 4),
                                          Text(
                                            item.cabang,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF0FDF4),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: const Color(0xFFBBF7D0)),
                                            ),
                                            child: Text(
                                              '${item.jumlahBonus} bonus',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF166534),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      currencyFormatter.format(item.totalInsentif),
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F766E),
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () => _showDetailModal(item),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
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
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (_filteredData.length > _visibleLimit) ...[
                        const SizedBox(height: 16),
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
                              'Tampilkan Lebih Banyak (${_visibleLimit < _filteredData.length ? _visibleLimit : _filteredData.length} dari ${_filteredData.length})',
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
                    onChanged: (val) => setState(() => _searchQuery = val),
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
                      Text('Filter Insentif', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
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
                            _fetchData();
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
                              _fetchData();
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
                              _fetchData();
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
      _fetchData();
    }
  }
}

class _InsentifDetailBottomSheet extends StatefulWidget {
  final InsentifCleanerModel item;
  final String filterWaktu;
  final String? filterTanggal;
  final HrdService hrdService;
  final NumberFormat currencyFormatter;

  const _InsentifDetailBottomSheet({
    required this.item,
    required this.filterWaktu,
    this.filterTanggal,
    required this.hrdService,
    required this.currencyFormatter,
  });

  @override
  State<_InsentifDetailBottomSheet> createState() => _InsentifDetailBottomSheetState();
}

class _InsentifDetailBottomSheetState extends State<_InsentifDetailBottomSheet> {
  bool _isLoading = true;
  InsentifCleanerModel? _detail;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final res = await widget.hrdService.fetchInsentifCleanerDetail(
      widget.item.karyawanId,
      filterWaktu: widget.filterWaktu,
      filterTanggal: widget.filterTanggal,
    );
    if (mounted) {
      setState(() {
        _detail = res ?? widget.item;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _detail ?? widget.item;

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
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Insentif — ${data.namaCleaner}',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total Card (Pro Max)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF047857)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF047857).withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Total Insentif',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.85)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.currencyFormatter.format(data.totalInsentif),
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(height: 45, width: 1, color: Colors.white.withValues(alpha: 0.2)),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.stars_rounded, color: Colors.white, size: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Jumlah Bonus',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.85)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${data.jumlahBonus}x',
                                  style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Rincian Insentif',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_isLoading)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()))
                  else if (data.riwayat.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Tidak ada rincian bonus ditemukan',
                          style: GoogleFonts.inter(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: data.riwayat.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final r = data.riwayat[idx];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
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
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.pelanggan,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_month_rounded, size: 12, color: AppColors.textMuted),
                                            const SizedBox(width: 4),
                                            Text(
                                              r.tanggal,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFBBF7D0)),
                                    ),
                                    child: Text(
                                      widget.currencyFormatter.format(r.totalNominal),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF166534),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (r.pesananIdVisual.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.tag_rounded, size: 12, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        r.pesananIdVisual,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (r.items.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                                    ),
                                  ),
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Column(
                                    children: r.items.map((item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(top: 5, right: 8),
                                            width: 4,
                                            height: 4,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF0F766E),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              item.jenisBonus,
                                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
                                            ),
                                          ),
                                          Text(
                                            widget.currencyFormatter.format(item.nominal),
                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                          ),
                                        ],
                                      ),
                                    )).toList(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
