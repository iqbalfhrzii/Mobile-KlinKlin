import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/data/hrd_models.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../hrd/services/hrd_service.dart';
import '../widgets/ceo_karyawan_detail_sheet.dart';

class CeoKaryawanScreen extends StatefulWidget {
  const CeoKaryawanScreen({super.key});

  @override
  State<CeoKaryawanScreen> createState() => _CeoKaryawanScreenState();
}

class _CeoKaryawanScreenState extends State<CeoKaryawanScreen> {
  final HrdService _hrdService = HrdService();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isLoading = true;
  String _error = '';

  List<KaryawanModel> _allKaryawan = [];
  List<CabangModel> _cabangList = [];
  List<JabatanModel> _jabatanList = [];

  // Filters
  String _searchQuery = '';
  String _statusAkunFilter = 'semua'; // 'semua', 'aktif', 'nonaktif'
  int? _selectedCabangId;
  int? _selectedJabatanId;
  String _jabatanCategory = 'semua'; // 'semua', 'cleaner', 'non_cleaner'

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final results = await Future.wait([
        _hrdService.fetchKaryawan(all: true),
        _hrdService.fetchCabang(),
        _hrdService.fetchJabatan(),
      ]);

      if (mounted) {
        setState(() {
          _allKaryawan = results[0] as List<KaryawanModel>;
          _cabangList = results[1] as List<CabangModel>;
          _jabatanList = results[2] as List<JabatanModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat data karyawan: $e';
          _isLoading = false;
        });
      }
    }
  }

  bool _isKaryawanAktif(KaryawanModel k) {
    final s = k.status.toLowerCase().trim();
    return s == 'aktif' || s == 'active' || s == '1';
  }

  List<KaryawanModel> get _filteredKaryawan {
    return _allKaryawan.where((k) {
      final isAktif = _isKaryawanAktif(k);

      // 1. Status Akun (Aktif / Non-Aktif)
      if (_statusAkunFilter == 'aktif' && !isAktif) return false;
      if (_statusAkunFilter == 'nonaktif' && isAktif) return false;

      // 2. Filter Cabang
      if (_selectedCabangId != null && k.cabangId != _selectedCabangId) return false;

      // 3. Filter Jabatan Spesifik
      if (_selectedJabatanId != null && k.jabatanId != _selectedJabatanId) return false;

      // 4. Filter Kategori Jabatan (Cleaner vs Non-Cleaner)
      final role = (k.jabatan?.namaJabatan ?? '').toLowerCase();
      final isCleaner = role.contains('cleaner');
      if (_jabatanCategory == 'cleaner' && !isCleaner) return false;
      if (_jabatanCategory == 'non_cleaner' && isCleaner) return false;

      // 5. Pencarian Teks
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final nameMatch = k.nama.toLowerCase().contains(q);
        final cabangMatch = (k.cabang?.namaCabang ?? '').toLowerCase().contains(q);
        final jabatanMatch = (k.jabatan?.namaJabatan ?? '').toLowerCase().contains(q);
        final phoneMatch = (k.noWa ?? '').contains(q);
        if (!nameMatch && !cabangMatch && !jabatanMatch && !phoneMatch) return false;
      }

      return true;
    }).toList();
  }

  // Statistics
  int get _totalCount => _allKaryawan.length;
  int get _aktifCount => _allKaryawan.where(_isKaryawanAktif).length;
  int get _nonAktifCount => _allKaryawan.where((k) => !_isKaryawanAktif(k)).length;
  int get _cleanerCount => _allKaryawan.where((k) => (k.jabatan?.namaJabatan ?? '').toLowerCase().contains('cleaner')).length;

  int get _activeFilterCount {
    int count = 0;
    if (_statusAkunFilter != 'semua') count++;
    if (_selectedCabangId != null) count++;
    if (_selectedJabatanId != null) count++;
    if (_jabatanCategory != 'semua') count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredKaryawan;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Executive Gradient Header
          _buildHeader(),

          // Main Body
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              color: const Color(0xFF0F172A),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
                  : _error.isNotEmpty
                      ? _buildErrorWidget()
                      : CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            // Summary Metrics
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                                child: _buildMetricsBar(),
                              ),
                            ),

                            // Search & Filter Controls
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                                child: _buildSearchAndFilterSection(),
                              ),
                            ),

                            // Result List or Empty State
                            if (filtered.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: _buildEmptyState(),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final k = filtered[index];
                                      return _buildKaryawanCard(k);
                                    },
                                    childCount: filtered.length,
                                  ),
                                ),
                              ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return GradientHeader(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 10 : 16,
      ),
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
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Direktori Eksekutif SDM',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      'Data Karyawan & Cleaner',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.remove_red_eye_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Monitoring',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsBar() {
    return Row(
      children: [
        _buildMetricItem(
          title: 'Total SDM',
          count: '$_totalCount',
          icon: Icons.people_alt_rounded,
          color: const Color(0xFF2563EB),
          bgColor: const Color(0xFFEFF6FF),
        ),
        const SizedBox(width: 8),
        _buildMetricItem(
          title: 'Aktif',
          count: '$_aktifCount',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF059669),
          bgColor: const Color(0xFFECFDF5),
        ),
        const SizedBox(width: 8),
        _buildMetricItem(
          title: 'Non-Aktif',
          count: '$_nonAktifCount',
          icon: Icons.cancel_rounded,
          color: const Color(0xFFDC2626),
          bgColor: const Color(0xFFFEF2F2),
        ),
        const SizedBox(width: 8),
        _buildMetricItem(
          title: 'Cleaner',
          count: '$_cleanerCount',
          icon: Icons.cleaning_services_rounded,
          color: const Color(0xFFD97706),
          bgColor: const Color(0xFFFFFBEB),
        ),
      ],
    );
  }

  Widget _buildMetricItem({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              count,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input + Filter Dialog Button
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Cari nama, cabang, jabatan...',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
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
                        child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Filter BottomSheet Trigger
            InkWell(
              onTap: _openFilterBottomSheet,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _activeFilterCount > 0 ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _activeFilterCount > 0 ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: _activeFilterCount > 0 ? Colors.white : const Color(0xFF475569),
                    ),
                    if (_activeFilterCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_activeFilterCount',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Status Akun Quick Chips (Semua | Aktif | Non-Aktif)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatusPill(label: 'Semua Akun', value: 'semua', count: _totalCount),
              const SizedBox(width: 8),
              _buildStatusPill(
                label: 'Aktif',
                value: 'aktif',
                count: _aktifCount,
                activeColor: const Color(0xFF059669),
                activeBg: const Color(0xFFECFDF5),
              ),
              const SizedBox(width: 8),
              _buildStatusPill(
                label: 'Non-Aktif',
                value: 'nonaktif',
                count: _nonAktifCount,
                activeColor: const Color(0xFFDC2626),
                activeBg: const Color(0xFFFEF2F2),
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 24, color: const Color(0xFFCBD5E1)),
              const SizedBox(width: 12),
              _buildCategoryPill(label: 'Semua Peran', value: 'semua'),
              const SizedBox(width: 8),
              _buildCategoryPill(label: 'Cleaner', value: 'cleaner'),
              const SizedBox(width: 8),
              _buildCategoryPill(label: 'Staff & Non-Cleaner', value: 'non_cleaner'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPill({
    required String label,
    required String value,
    required int count,
    Color activeColor = const Color(0xFF0F172A),
    Color activeBg = const Color(0xFF0F172A),
  }) {
    final isSelected = _statusAkunFilter == value;

    return InkWell(
      onTap: () => setState(() => _statusAkunFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (value == 'semua' ? const Color(0xFF0F172A) : activeBg)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (value == 'semua' ? const Color(0xFF0F172A) : activeColor)
                : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (value == 'semua' ? Colors.white : activeColor)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? (value == 'semua'
                        ? Colors.white.withValues(alpha: 0.2)
                        : activeColor.withValues(alpha: 0.15))
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (value == 'semua' ? Colors.white : activeColor)
                      : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPill({
    required String label,
    required String value,
  }) {
    final isSelected = _jabatanCategory == value;

    return InkWell(
      onTap: () => setState(() => _jabatanCategory = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildKaryawanCard(KaryawanModel k) {
    final isAktif = _isKaryawanAktif(k);
    final cabangName = k.cabang?.namaCabang ?? 'Cabang -';
    final jabatanName = k.jabatan?.namaJabatan ?? 'Staff';
    final statusKaryawan = k.statusKaryawan ?? 'Tetap';
    final isCleaner = jabatanName.toLowerCase().contains('cleaner');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAktif ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => CeoKaryawanDetailSheet.show(context, karyawan: k),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar with online/active dot
                Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isAktif
                              ? (isCleaner
                                  ? [const Color(0xFF059669), const Color(0xFF047857)]
                                  : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)])
                              : [const Color(0xFF94A3B8), const Color(0xFF64748B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        image: k.fotoProfil != null && k.fotoProfil!.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(k.fotoProfil!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: k.fotoProfil == null || k.fotoProfil!.isEmpty
                          ? Center(
                              child: Text(
                                k.nama.isNotEmpty ? k.nama[0].toUpperCase() : 'K',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: isAktif ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Info Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              k.nama,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAktif ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isAktif ? 'AKTIF' : 'NON-AKTIF',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isAktif ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Tags Row (Jabatan & Cabang)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              jabatanName,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF334155),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              cabangName,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1D4ED8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusKaryawan,
                            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Quick Action Subtext
                      Row(
                        children: [
                          Icon(
                            isCleaner ? Icons.paid_rounded : Icons.receipt_long_rounded,
                            size: 13,
                            color: isCleaner ? const Color(0xFF059669) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCleaner ? 'Klik untuk lihat Gaji & Bonus Cleaner' : 'Klik untuk lihat rincian kompensasi',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: isCleaner ? const Color(0xFF059669) : const Color(0xFF64748B),
                              fontWeight: isCleaner ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFCBD5E1)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        int? tempCabang = _selectedCabangId;
        int? tempJabatan = _selectedJabatanId;

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
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter Data Karyawan',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempCabang = null;
                              tempJabatan = null;
                            });
                          },
                          child: Text(
                            'Reset',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cabang Filter
                          Text(
                            'Cabang',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Semua Cabang'),
                                selected: tempCabang == null,
                                onSelected: (val) {
                                  if (val) setModalState(() => tempCabang = null);
                                },
                                selectedColor: const Color(0xFF0F172A),
                                labelStyle: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: tempCabang == null ? FontWeight.bold : FontWeight.w500,
                                  color: tempCabang == null ? Colors.white : const Color(0xFF475569),
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                showCheckmark: false,
                              ),
                              ..._cabangList.map((c) {
                                final isSel = tempCabang == c.id;
                                return ChoiceChip(
                                  label: Text(c.namaCabang),
                                  selected: isSel,
                                  onSelected: (val) {
                                    setModalState(() => tempCabang = val ? c.id : null);
                                  },
                                  selectedColor: const Color(0xFF0F172A),
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                    color: isSel ? Colors.white : const Color(0xFF475569),
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  showCheckmark: false,
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 22),

                          // Jabatan Filter
                          Text(
                            'Jabatan Tertentu',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Semua Jabatan'),
                                selected: tempJabatan == null,
                                onSelected: (val) {
                                  if (val) setModalState(() => tempJabatan = null);
                                },
                                selectedColor: const Color(0xFF0F172A),
                                labelStyle: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: tempJabatan == null ? FontWeight.bold : FontWeight.w500,
                                  color: tempJabatan == null ? Colors.white : const Color(0xFF475569),
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                showCheckmark: false,
                              ),
                              ..._jabatanList.map((j) {
                                final isSel = tempJabatan == j.id;
                                return ChoiceChip(
                                  label: Text(j.namaJabatan),
                                  selected: isSel,
                                  onSelected: (val) {
                                    setModalState(() => tempJabatan = val ? j.id : null);
                                  },
                                  selectedColor: const Color(0xFF0F172A),
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                    color: isSel ? Colors.white : const Color(0xFF475569),
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  showCheckmark: false,
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Button
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      10,
                      20,
                      MediaQuery.of(context).padding.bottom > 0
                          ? MediaQuery.of(context).padding.bottom + 12
                          : 16,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedCabangId = tempCabang;
                            _selectedJabatanId = tempJabatan;
                          });
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text(
                          'Terapkan Filter',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline_rounded, size: 40, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 14),
            Text(
              'Tidak ada karyawan ditemukan',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Coba ubah kriteria pencarian atau atur ulang filter.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                _searchCtrl.clear();
                setState(() {
                  _searchQuery = '';
                  _statusAkunFilter = 'semua';
                  _selectedCabangId = null;
                  _selectedJabatanId = null;
                  _jabatanCategory = 'semua';
                });
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Reset Filter',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
            const SizedBox(height: 12),
            Text(
              _error,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchData,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
              child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
