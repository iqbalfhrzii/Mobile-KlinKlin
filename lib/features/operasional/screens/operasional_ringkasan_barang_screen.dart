import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/operasional_ringkasan_barang_service.dart';
import '../services/operasional_stok_opname_service.dart';

class OperasionalRingkasanBarangScreen extends StatefulWidget {
  const OperasionalRingkasanBarangScreen({super.key});

  @override
  State<OperasionalRingkasanBarangScreen> createState() => _OperasionalRingkasanBarangScreenState();
}

class _OperasionalRingkasanBarangScreenState extends State<OperasionalRingkasanBarangScreen> {
  bool _isLoading = false;
  List<dynamic> _cabangs = [];
  Map<String, dynamic> _summary = {};
  List<dynamic> _items = [];
  String? _authToken;

  int? _selectedCabangId;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // Active filter from KPI Cards: 'ALL', 'MSN', 'CLA', 'BAIK', 'BERMASALAH'
  String _activeKpiFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadAuthToken();
    _loadCabangs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('auth_token');
    } catch (_) {}
  }

  Future<void> _loadCabangs() async {
    try {
      final cabangs = await OperasionalRingkasanBarangService.getCabangs();
      if (mounted) {
        setState(() => _cabangs = cabangs);
        _loadData();
      }
    } catch (e) {
      debugPrint('Error loading cabangs: $e');
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await OperasionalRingkasanBarangService.getSummary(
        cabangId: _selectedCabangId,
        search: _searchController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _summary = data['summary'] ?? {};
          _items = data['list'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredItems {
    if (_activeKpiFilter == 'ALL') return _items;
    if (_activeKpiFilter == 'MSN') {
      return _items.where((i) => (i['kategori'] ?? '').toString().toUpperCase() == 'MSN').toList();
    }
    if (_activeKpiFilter == 'CLA') {
      return _items.where((i) => (i['kategori'] ?? '').toString().toUpperCase() == 'CLA').toList();
    }
    if (_activeKpiFilter == 'BAIK') {
      return _items.where((i) => (int.tryParse(i['kondisi_baik']?.toString() ?? '0') ?? 0) > 0).toList();
    }
    if (_activeKpiFilter == 'BERMASALAH') {
      return _items.where((i) => (int.tryParse(i['bermasalah']?.toString() ?? '0') ?? 0) > 0).toList();
    }
    return _items;
  }

  void _showDetailModal(Map<String, dynamic> item) {
    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetailBottomSheet(
        barangId: item['id'],
        namaBarang: item['nama_barang'] ?? '-',
        kategori: item['kategori'] ?? '-',
        selectedCabangId: _selectedCabangId,
        cabangs: _cabangs,
        authToken: _authToken,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredItems;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Gradient Header
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            child: Row(
              children: [
                if (Navigator.canPop(context)) ...[
                  const AppBackButton(),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ringkasan Barang',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Pantau ketersediaan & kondisi fisik aset alat',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Filters: Cabang & Search
          _buildFilterBar(),

          // Main Scrollable Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: AppColors.primary,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Interactive KPI Summary Cards
                          _buildInteractiveSummarySection(),

                          // Active Filter Indicator Pill (if filtered)
                          if (_activeKpiFilter != 'ALL') _buildActiveFilterBanner(filteredList.length),

                          // Section Title
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Daftar Barang',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  '${filteredList.length} Item',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // List Items
                          _buildListItems(filteredList),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // --- FILTER BAR: CABANG & SEARCH (Matching Mobile Style) ---
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Cabang Dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<dynamic>(
                      value: _selectedCabangId,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
                      hint: Text(
                        'Semua Cabang',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(
                            'Semua Cabang',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                          ),
                        ),
                        ..._cabangs.map(
                          (c) => DropdownMenuItem(
                            value: c['id'],
                            child: Text(
                              c['nama_cabang'] ?? '-',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedCabangId = val as int?);
                        _loadData();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Search Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Cari nama barang aset...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _loadData();
                    },
                    child: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- INTERACTIVE KPI SUMMARY SECTION (Can be tapped as filters!) ---
  Widget _buildInteractiveSummarySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ringkasan Status Aset',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
              if (_activeKpiFilter != 'ALL')
                GestureDetector(
                  onTap: () => setState(() => _activeKpiFilter = 'ALL'),
                  child: Text(
                    'Reset Filter',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildClickableSummaryCard(
                  filterKey: 'MSN',
                  title: 'Mesin Alat (MSN)',
                  value: _summary['total_msn']?.toString() ?? '0',
                  icon: Icons.precision_manufacturing_rounded,
                  accentColor: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildClickableSummaryCard(
                  filterKey: 'CLA',
                  title: 'Cleaning Alat (CLA)',
                  value: _summary['total_cla']?.toString() ?? '0',
                  icon: Icons.cleaning_services_rounded,
                  accentColor: const Color(0xFF0284C7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildClickableSummaryCard(
                  filterKey: 'BAIK',
                  title: 'Kondisi Baik',
                  value: _summary['kondisi_baik']?.toString() ?? '0',
                  icon: Icons.check_circle_rounded,
                  accentColor: const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildClickableSummaryCard(
                  filterKey: 'BERMASALAH',
                  title: 'Bermasalah',
                  value: _summary['bermasalah']?.toString() ?? '0',
                  icon: Icons.warning_amber_rounded,
                  accentColor: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClickableSummaryCard({
    required String filterKey,
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    final bool isSelected = _activeKpiFilter == filterKey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _activeKpiFilter = isSelected ? 'ALL' : filterKey;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? accentColor : const Color(0xFFE2E8F0),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: isSelected ? accentColor : const Color(0xFF64748B),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          value,
                          style: GoogleFonts.inter(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? accentColor : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Unit',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isSelected ? accentColor : accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : accentColor,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilterBanner(int resultCount) {
    String label = '';
    Color color = AppColors.primary;
    if (_activeKpiFilter == 'MSN') {
      label = 'Kategori: Mesin Alat (MSN)';
      color = const Color(0xFF2563EB);
    } else if (_activeKpiFilter == 'CLA') {
      label = 'Kategori: Cleaning Alat (CLA)';
      color = const Color(0xFF0284C7);
    } else if (_activeKpiFilter == 'BAIK') {
      label = 'Kondisi: Hanya Unit Baik';
      color = const Color(0xFF16A34A);
    } else if (_activeKpiFilter == 'BERMASALAH') {
      label = 'Kondisi: Hanya Unit Bermasalah (Rusak/Hilang)';
      color = const Color(0xFFDC2626);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.filter_alt_rounded, size: 15, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => setState(() => _activeKpiFilter = 'ALL'),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close_rounded, size: 13, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- LIST ITEMS (Modern Mobile Cards) ---
  Widget _buildListItems(List<dynamic> list) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              Text(
                'Tidak Ada Data Barang',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tidak ditemukan barang yang sesuai dengan filter atau kata kunci pencarian.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: list.map((item) {
          final kategori = (item['kategori'] ?? '-').toString().toUpperCase();
          final nama = item['nama_barang'] ?? '-';
          final total = int.tryParse(item['total_unit']?.toString() ?? '0') ?? 0;
          final baik = int.tryParse(item['kondisi_baik']?.toString() ?? '0') ?? 0;
          final bermasalah = int.tryParse(item['bermasalah']?.toString() ?? '0') ?? 0;

          final isMsn = kategori == 'MSN';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showDetailModal(item),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Category Badge + Detail Action
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isMsn ? const Color(0xFFEFF6FF) : const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isMsn ? const Color(0xFFBFDBFE) : const Color(0xFFBAE6FD),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isMsn ? Icons.precision_manufacturing_rounded : Icons.cleaning_services_rounded,
                                  size: 13,
                                  color: isMsn ? const Color(0xFF2563EB) : const Color(0xFF0284C7),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  kategori,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: isMsn ? const Color(0xFF1D4ED8) : const Color(0xFF0369A1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Lihat Detail',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppColors.primary),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Nama Barang
                      Text(
                        nama,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // KPI Metrics Row (3-Column Clean Badges)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Row(
                          children: [
                            // Total Unit
                            Expanded(
                              child: _buildMetricPill(
                                label: 'Total',
                                value: '$total Unit',
                                valueColor: const Color(0xFF334155),
                                icon: Icons.inventory_2_outlined,
                              ),
                            ),
                            Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),

                            // Baik
                            Expanded(
                              child: _buildMetricPill(
                                label: 'Kondisi Baik',
                                value: '$baik Unit',
                                valueColor: const Color(0xFF16A34A),
                                icon: Icons.check_circle_outline_rounded,
                              ),
                            ),
                            Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),

                            // Bermasalah
                            Expanded(
                              child: _buildMetricPill(
                                label: 'Bermasalah',
                                value: bermasalah > 0 ? '$bermasalah Unit' : '-',
                                valueColor: bermasalah > 0 ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                                icon: Icons.warning_amber_rounded,
                              ),
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
        }).toList(),
      ),
    );
  }

  Widget _buildMetricPill({
    required String label,
    required String value,
    required Color valueColor,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: valueColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// =========================================================
// BOTTOM SHEET RINCIAN ITEM FISIK (Interactive & Modern)
// =========================================================

class _DetailBottomSheet extends StatefulWidget {
  final int barangId;
  final String namaBarang;
  final String kategori;
  final int? selectedCabangId;
  final List<dynamic> cabangs;
  final String? authToken;

  const _DetailBottomSheet({
    required this.barangId,
    required this.namaBarang,
    required this.kategori,
    this.selectedCabangId,
    required this.cabangs,
    this.authToken,
  });

  @override
  State<_DetailBottomSheet> createState() => _DetailBottomSheetState();
}

class _DetailBottomSheetState extends State<_DetailBottomSheet> {
  bool _isLoading = true;
  List<dynamic> _items = [];
  int? _localCabangId;
  String _selectedKondisiFilter = 'ALL'; // 'ALL', 'Baik', 'Rusak', 'Hilang'

  @override
  void initState() {
    super.initState();
    _localCabangId = widget.selectedCabangId;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      final data = await OperasionalRingkasanBarangService.getDetailItem(
        widget.barangId,
        cabangId: _localCabangId,
      );
      List<dynamic> items = List.from(data['items'] ?? []);

      // Smart fallback: If VPS API returned null/empty photo_path, resolve latest photos from stok opname inspection sessions
      final bool hasMissingPhotos = items.any((i) => i['foto_path'] == null || i['foto_path'].toString().isEmpty);
      if (hasMissingPhotos) {
        try {
          final sessions = await OperasionalStokOpnameService.getSessions(cabangId: _localCabangId);
          for (final s in sessions.take(4)) {
            final detail = await OperasionalStokOpnameService.getSessionDetails(s['id']);
            final listDetails = detail?['details'] as List<dynamic>? ?? [];
            for (final opItem in listDetails) {
              final fisik = opItem['item_fisik'];
              final qr = (fisik?['kode_qr'] ?? opItem['kode_qr'] ?? '').toString().trim();
              final photo = opItem['foto_path'] ?? opItem['foto_item'] ?? opItem['foto'] ?? opItem['foto_url'];
              if (qr.isNotEmpty && photo != null && photo.toString().isNotEmpty) {
                for (var i = 0; i < items.length; i++) {
                  final itemQr = (items[i]['kode_qr'] ?? '').toString().trim();
                  if (itemQr == qr && (items[i]['foto_path'] == null || items[i]['foto_path'].toString().isEmpty)) {
                    items[i]['foto_path'] = photo;
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Photo fallback error: $e');
        }
      }

      if (mounted) {
        setState(() {
          _items = items;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredDetailItems {
    if (_selectedKondisiFilter == 'ALL') return _items;
    return _items.where((i) {
      final k = (i['kondisi_fisik'] ?? '').toString().toLowerCase();
      return k == _selectedKondisiFilter.toLowerCase();
    }).toList();
  }

  String _getImageUrl(dynamic rawPath) {
    if (rawPath == null) return '';
    String p = rawPath.toString().trim().replaceAll(r'\', '/');
    if (p.isEmpty) return '';
    if (p.startsWith('http://') || p.startsWith('https://')) return p;

    final baseDomain = ApiClient.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    if (p.startsWith('storage/')) return '$baseDomain/$p';
    if (p.startsWith('/storage/')) return '$baseDomain$p';
    return '$baseDomain/storage/$p';
  }

  void _showFullImage(String url, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  headers: widget.authToken != null ? {'Authorization': 'Bearer ${widget.authToken}'} : null,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, color: Colors.white54, size: 48),
                        SizedBox(height: 8),
                        Text('Gagal memuat gambar', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        shadows: const [Shadow(blurRadius: 6, color: Colors.black)],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                    style: IconButton.styleFrom(backgroundColor: Colors.black45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDetailItems;
    final totalBaik = _items.where((i) => (i['kondisi_fisik'] ?? '').toString().toLowerCase() == 'baik').length;
    final totalRusak = _items.where((i) => (i['kondisi_fisik'] ?? '').toString().toLowerCase() == 'rusak').length;
    final totalHilang = _items.where((i) => (i['kondisi_fisik'] ?? '').toString().toLowerCase() == 'hilang').length;
    final totalBermasalah = totalRusak + totalHilang;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 10),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          'RINCIAN UNIT FISIK QR',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1D4ED8),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.namaBarang,
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFE2E8F0),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Quick Summary Counter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMiniStat(
                      label: 'Total Unit',
                      value: '${_items.length}',
                      icon: Icons.qr_code_2_rounded,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                  Expanded(
                    child: _buildMiniStat(
                      label: 'Kondisi Baik',
                      value: '$totalBaik',
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                  Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                  Expanded(
                    child: _buildMiniStat(
                      label: 'Bermasalah',
                      value: '$totalBermasalah',
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Modal Filter: Cabang Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<dynamic>(
                  value: _localCabangId,
                  isExpanded: true,
                  hint: Row(
                    children: [
                      const Icon(Icons.storefront_outlined, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        'Semua Cabang',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Row(
                        children: [
                          const Icon(Icons.storefront_outlined, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text('Semua Cabang', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    ...widget.cabangs.map(
                      (c) => DropdownMenuItem(
                        value: c['id'],
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(c['nama_cabang'] ?? '-'),
                          ],
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() => _localCabangId = val as int?);
                    _loadDetail();
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Modal Filter: Kondisi Segment Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildKondisiChip('ALL', 'Semua (${_items.length})', const Color(0xFF2563EB)),
                const SizedBox(width: 6),
                _buildKondisiChip('Baik', 'Baik ($totalBaik)', const Color(0xFF16A34A)),
                const SizedBox(width: 6),
                _buildKondisiChip('Rusak', 'Rusak ($totalRusak)', const Color(0xFFDC2626)),
                const SizedBox(width: 6),
                _buildKondisiChip('Hilang', 'Hilang ($totalHilang)', const Color(0xFFEA580C)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // List of Asset Cards
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.assignment_late_outlined, size: 44, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 10),
                            Text(
                              'Tidak ada item fisik',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tidak ada unit QR yang cocok dengan filter yang dipilih.',
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return _buildPhysicalItemCard(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildPhysicalItemCard(dynamic item) {
    final qr = (item['kode_qr'] ?? '-').toString();
    final cabang = (item['cabang'] ?? '-').toString();
    final ketersediaan = (item['status_ketersediaan'] ?? 'Tersedia').toString();
    final kondisi = (item['kondisi_fisik'] ?? 'Baik').toString();
    final rawFoto = item['foto_path'] ?? item['foto'] ?? item['foto_item'] ?? item['foto_url'] ?? item['foto_master'];
    final fotoUrl = _getImageUrl(rawFoto);

    final isRusak = kondisi.toLowerCase() == 'rusak';
    final isHilang = kondisi.toLowerCase() == 'hilang';

    Color kondisiColor = const Color(0xFF16A34A);
    Color kondisiBg = const Color(0xFFDCFCE7);
    Color kondisiBorder = const Color(0xFF86EFAC);

    if (isRusak) {
      kondisiColor = const Color(0xFFDC2626);
      kondisiBg = const Color(0xFFFEE2E2);
      kondisiBorder = const Color(0xFFFCA5A5);
    } else if (isHilang) {
      kondisiColor = const Color(0xFFEA580C);
      kondisiBg = const Color(0xFFFFEDD5);
      kondisiBorder = const Color(0xFFFDBA74);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar: QR Code Badge & Condition Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                // QR Badge
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.qr_code_2_rounded, size: 14, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          qr,
                          style: GoogleFonts.robotoMono(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                            letterSpacing: 0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Kondisi Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kondisiBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kondisiBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: kondisiColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        kondisi.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: kondisiColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Photo Preview (Hero Visual Banner)
          if (fotoUrl.isNotEmpty) ...[
            GestureDetector(
              onTap: () => _showFullImage(fotoUrl, 'Foto $qr'),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.network(
                        fotoUrl,
                        fit: BoxFit.cover,
                        headers: widget.authToken != null ? {'Authorization': 'Bearer ${widget.authToken}'} : null,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
                        },
                        errorBuilder: (c, e, s) => const Center(
                          child: Icon(Icons.broken_image_rounded, size: 28, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                    // Gradient Bottom Bar with Zoom Prompt
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.75),
                            ],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Foto Opname Aktual',
                              style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.zoom_in, color: Colors.white, size: 13),
                                const SizedBox(width: 3),
                                Text(
                                  'Ketuk untuk Zoom',
                                  style: GoogleFonts.inter(fontSize: 10, color: Colors.white70),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ] else ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.photo_outlined, size: 16, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(
                    'Foto opname belum tersedia',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Footer Info (Cabang & Ketersediaan)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Cabang
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      cabang,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),

                // Status Ketersediaan Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 12, color: Color(0xFF1D4ED8)),
                      const SizedBox(width: 4),
                      Text(
                        ketersediaan,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1D4ED8),
                        ),
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

  Widget _buildKondisiChip(String filterKey, String label, Color accentColor) {
    final bool isSelected = _selectedKondisiFilter == filterKey;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedKondisiFilter = filterKey),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? accentColor : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? accentColor : const Color(0xFFE2E8F0),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

