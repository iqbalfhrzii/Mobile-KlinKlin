import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/data/hrd_models.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../services/hrd_service.dart';

class InsentifCleanerListScreen extends StatefulWidget {
  final bool showHeader;
  const InsentifCleanerListScreen({super.key, this.showHeader = true});

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
    final bodyContent = RefreshIndicator(
      onRefresh: _fetchData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchAndFilterBar(),
            _buildActiveFilterChips(),

            // Stat Summary Cards
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF64748B).withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, size: 18, color: Color(0xFF059669)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Insentif',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currencyFormatter.format(_totalInsentifGlobal),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF047857),
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
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF64748B).withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
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
                          child: const Icon(Icons.people_alt_rounded, size: 18, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cleaner',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$_jumlahCleanerGlobal Cleaner',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1D4ED8),
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
                ),
              ],
            ),
            const SizedBox(height: 16),

            // List Header
            Text(
              'Daftar Insentif Cleaner',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),

            // Cleaner List
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredData.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF64748B).withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.payments_outlined, size: 36, color: Colors.grey.shade400),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tidak ada data insentif cleaner',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Coba ubah kata kunci atau periode filter.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
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
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _filteredData[index];
                  final displayName = _toTitleCase(item.namaCleaner);
                  final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C';
                  final hasInsentif = item.totalInsentif > 0;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF64748B).withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: hasInsentif
                                ? const LinearGradient(
                                    colors: [Color(0xFF10B981), Color(0xFF047857)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : const LinearGradient(
                                    colors: [Color(0xFF64748B), Color(0xFF475569)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: hasInsentif ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (hasInsentif) ...[
                                          const Icon(Icons.monetization_on_rounded, size: 12, color: Color(0xFF059669)),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          currencyFormatter.format(item.totalInsentif),
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: hasInsentif ? const Color(0xFF047857) : const Color(0xFF64748B),
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
                        GestureDetector(
                          onTap: () => _showDetailModal(item),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (_visibleLimit < _filteredData.length)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: TextButton(
                      onPressed: () => setState(() => _visibleLimit += 25),
                      child: Text('Muat Lebih Banyak', style: GoogleFonts.inter()),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );

    if (!widget.showHeader) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: bodyContent,
      );
    }

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
            child: bodyContent,
          ),
        ],
      ),
    );
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCabangId != null) count++;
    if (_filterWaktu != 'bulan_ini' || _selectedTanggal != null || _customRange != null) count++;
    return count;
  }

  // --- Modern Filter UI ---
  Widget _buildSearchAndFilterBar() {
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
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'Cari nama cleaner...',
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
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: _activeFilterCount > 0
                  ? const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF4F46E5)])
                  : null,
              color: _activeFilterCount > 0 ? null : Colors.white,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: _activeFilterCount > 0 ? Colors.transparent : Colors.grey.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                if (_activeFilterCount > 0)
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: _activeFilterCount > 0 ? Colors.white : AppColors.textDark,
                ),
                if (_activeFilterCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Text(
                      '$_activeFilterCount',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
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

  Widget _buildActiveFilterChips() {
    if (_activeFilterCount == 0 && _searchQuery.isEmpty) {
      return const SizedBox.shrink();
    }

    final String? namaCabang = _selectedCabangId != null
        ? _cabangList.firstWhere(
            (c) => c.id == _selectedCabangId, 
            orElse: () => CabangModel(id: -1, namaCabang: 'Cabang')
          ).namaCabang
        : null;

    String? labelWaktu;
    if (_filterWaktu == 'custom' && _customRange != null) {
      labelWaktu = '${DateFormat('dd/MM').format(_customRange!.start)} - ${DateFormat('dd/MM').format(_customRange!.end)}';
    } else if (_filterWaktu == 'hari_ini') {
      labelWaktu = 'Hari Ini';
    } else if (_filterWaktu == 'kemarin') {
      labelWaktu = 'Kemarin';
    } else if (_filterWaktu == 'semua') {
      labelWaktu = 'Semua Waktu';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (namaCabang != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text('Cabang: $namaCabang', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1D4ED8))),
                  backgroundColor: const Color(0xFFEFF6FF),
                  side: const BorderSide(color: Color(0xFF93C5FD)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF1D4ED8)),
                  onDeleted: () {
                    setState(() => _selectedCabangId = null);
                    _fetchData();
                  },
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            if (labelWaktu != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text('Waktu: $labelWaktu', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF047857))),
                  backgroundColor: const Color(0xFFECFDF5),
                  side: const BorderSide(color: Color(0xFFA7F3D0)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF047857)),
                  onDeleted: () {
                    setState(() {
                      _filterWaktu = 'bulan_ini';
                      _customRange = null;
                      _selectedTanggal = null;
                    });
                    _fetchData();
                  },
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            if (_activeFilterCount > 0 || _searchQuery.isNotEmpty)
              ActionChip(
                label: Text('Reset Filter', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                backgroundColor: Colors.red.shade50,
                side: BorderSide(color: Colors.red.shade200),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedCabangId = null;
                    _filterWaktu = 'bulan_ini';
                    _customRange = null;
                    _selectedTanggal = null;
                  });
                  _fetchData();
                },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
      ),
    );
  }

  void _showFilterBottomSheet() {
    int? tempCabangId = _selectedCabangId;
    String tempFilterWaktu = _filterWaktu;
    DateTimeRange? tempRange = _customRange;
    DateTime? tempTanggal = _selectedTanggal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Filter Insentif Cleaner', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Cabang Filter
                          if (_cabangList.isNotEmpty) ...[
                            Text('Cabang', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('Semua Cabang'),
                                  selected: tempCabangId == null,
                                  onSelected: (val) {
                                    if (val) setModalState(() => tempCabangId = null);
                                  },
                                  selectedColor: const Color(0xFFEFF6FF),
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 12, 
                                    fontWeight: tempCabangId == null ? FontWeight.bold : FontWeight.w500, 
                                    color: tempCabangId == null ? const Color(0xFF1D4ED8) : AppColors.textDark,
                                  ),
                                  side: BorderSide(color: tempCabangId == null ? const Color(0xFF3B82F6) : Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  showCheckmark: false,
                                ),
                                ..._cabangList.map((c) {
                                  final isSel = tempCabangId == c.id;
                                  return ChoiceChip(
                                    label: Text(c.namaCabang),
                                    selected: isSel,
                                    onSelected: (val) {
                                      setModalState(() => tempCabangId = val ? c.id : null);
                                    },
                                    selectedColor: const Color(0xFFEFF6FF),
                                    labelStyle: GoogleFonts.inter(
                                      fontSize: 12, 
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500, 
                                      color: isSel ? const Color(0xFF1D4ED8) : AppColors.textDark,
                                    ),
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
                          Text('Rentang Waktu', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ...[
                                {'key': 'bulan_ini', 'label': 'Bulan Ini'},
                                {'key': 'hari_ini', 'label': 'Hari Ini'},
                                {'key': 'kemarin', 'label': 'Kemarin'},
                                {'key': 'semua', 'label': 'Semua Waktu'},
                              ].map((item) {
                                final isSel = tempFilterWaktu == item['key'] && tempTanggal == null && tempRange == null;
                                return ChoiceChip(
                                  label: Text(item['label']!),
                                  selected: isSel,
                                  onSelected: (val) {
                                    if (val) {
                                      setModalState(() {
                                        tempFilterWaktu = item['key']!;
                                        tempRange = null;
                                        tempTanggal = null;
                                      });
                                    }
                                  },
                                  selectedColor: const Color(0xFFECFDF5),
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 12, 
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500, 
                                    color: isSel ? const Color(0xFF047857) : AppColors.textDark,
                                  ),
                                  side: BorderSide(color: isSel ? const Color(0xFF10B981) : Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  showCheckmark: false,
                                );
                              }),
                              ActionChip(
                                avatar: const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF4F46E5)),
                                label: Text(
                                  tempFilterWaktu == 'custom' && tempRange != null
                                      ? '${DateFormat('dd/MM').format(tempRange!.start)} - ${DateFormat('dd/MM').format(tempRange!.end)}'
                                      : 'Pilih Tanggal',
                                  style: GoogleFonts.inter(
                                    fontSize: 12, 
                                    fontWeight: tempFilterWaktu == 'custom' ? FontWeight.bold : FontWeight.w500, 
                                    color: tempFilterWaktu == 'custom' ? const Color(0xFF4F46E5) : AppColors.textDark,
                                  ),
                                ),
                                onPressed: () async {
                                  final picked = await showDateRangePicker(
                                    context: context,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                    initialDateRange: tempRange,
                                    builder: (ctx2, child) => Theme(
                                      data: Theme.of(ctx2).copyWith(
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
                                    setModalState(() {
                                      tempRange = picked;
                                      tempFilterWaktu = 'custom';
                                      tempTanggal = picked.start;
                                    });
                                  }
                                },
                                backgroundColor: tempFilterWaktu == 'custom' ? const Color(0xFFEEF2FF) : Colors.white,
                                side: BorderSide(color: tempFilterWaktu == 'custom' ? const Color(0xFF6366F1) : Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                tempCabangId = null;
                                tempFilterWaktu = 'bulan_ini';
                                tempRange = null;
                                tempTanggal = null;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text('Reset', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedCabangId = tempCabangId;
                                _filterWaktu = tempFilterWaktu;
                                _customRange = tempRange;
                                _selectedTanggal = tempTanggal;
                              });
                              Navigator.pop(ctx);
                              _fetchData();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: Text('Terapkan Filter', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
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

String _toTitleCase(String text) {
  if (text.isEmpty) return text;
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
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
    final cleanerName = _toTitleCase(data.namaCleaner);
    final initial = cleanerName.isNotEmpty ? cleanerName[0].toUpperCase() : 'C';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF047857)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cleanerName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Rincian Insentif Cleaner',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF065F46), Color(0xFF047857), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF047857).withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL INSENTIF',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.currencyFormatter.format(data.totalInsentif),
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Jumlah Bonus',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${data.jumlahBonus}x',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_isLoading)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
                  else if (data.riwayat.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF64748B).withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.inbox_outlined, size: 32, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak ada rincian bonus ditemukan',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Belum ada bonus order tercatat pada periode ini.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: data.riwayat.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final r = data.riwayat[idx];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF64748B).withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
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
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF64748B)),
                                            const SizedBox(width: 4),
                                            Text(
                                              r.tanggal,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      widget.currencyFormatter.format(r.totalNominal),
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF047857),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (r.pesananIdVisual.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.tag_rounded, size: 11, color: Color(0xFF64748B)),
                                      const SizedBox(width: 3),
                                      Text(
                                        r.pesananIdVisual,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (r.items.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: r.items.map((item) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 3),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 5,
                                            height: 5,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF059669),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              item.jenisBonus,
                                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155)),
                                            ),
                                          ),
                                          Text(
                                            widget.currencyFormatter.format(item.nominal),
                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
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
