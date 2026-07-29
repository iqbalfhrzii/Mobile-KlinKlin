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
                      searchQuery: _searchQuery,
                      onSearchChanged: (val) => setState(() => _searchQuery = val),
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

                    // Filter Periode Chips (di bawah pencarian)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Bulan Ini', 'bulan_ini'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Hari Ini', 'hari_ini'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Kemarin', 'kemarin'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Semua', 'semua'),
                        ],
                      ),
                    ),

                    // Filter Cabang Dropdown
                    if (_cabangList.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            isExpanded: true,
                            value: _selectedCabangId,
                            icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textMuted),
                            hint: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark)),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 13)),
                              ),
                              ..._cabangList.map(
                                (c) => DropdownMenuItem<int?>(
                                  value: c.id,
                                  child: Text(c.namaCabang, style: GoogleFonts.inter(fontSize: 13)),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedCabangId = val);
                              _fetchData();
                            },
                          ),
                        ),
                      ),
                    ],

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
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  child: Text(
                                    item.namaCleaner.isNotEmpty ? item.namaCleaner[0].toUpperCase() : 'C',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.namaCleaner,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.storefront_rounded, size: 14, color: AppColors.textMuted),
                                          const SizedBox(width: 4),
                                          Text(
                                            item.cabang,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${item.jumlahBonus} bonus',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF00796B),
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
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF00796B),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    OutlinedButton(
                                      onPressed: () => _showDetailModal(item),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        side: const BorderSide(color: AppColors.primary),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: Text(
                                        'Detail',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterWaktu == value && _selectedTanggal == null;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _filterWaktu = value;
            _selectedTanggal = null;
          });
          _fetchData();
        }
      },
      selectedColor: AppColors.primary,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        color: isSelected ? Colors.white : AppColors.textDark,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
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
                  // Total Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Insentif',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.currencyFormatter.format(data.totalInsentif),
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(height: 30, width: 1, color: Colors.grey.shade300),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Jumlah Bonus',
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${data.jumlahBonus} bonus',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
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
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${r.tanggal} · ${r.pelanggan}',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    widget.currencyFormatter.format(r.totalNominal),
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              ),
                              if (r.pesananIdVisual.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  r.pesananIdVisual,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                              if (r.items.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                ...r.items.map((item) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '• ${item.jenisBonus}',
                                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
                                          ),
                                          Text(
                                            widget.currencyFormatter.format(item.nominal),
                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    )),
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
