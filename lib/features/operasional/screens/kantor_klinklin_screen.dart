import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/operasional_kantor_service.dart';
import 'kantor_klinklin_form_screen.dart';

class KantorKlinklinScreen extends StatefulWidget {
  const KantorKlinklinScreen({super.key});

  @override
  State<KantorKlinklinScreen> createState() => _KantorKlinklinScreenState();
}

class _KantorKlinklinScreenState extends State<KantorKlinklinScreen> {
  bool _isLoading = false;
  List<dynamic> _cabangs = [];
  String _searchQuery = '';
  String _selectedStatusFilter = 'all'; // all, Aset, Sewa

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await OperasionalKantorService.fetchKantor();
      if (mounted) {
        setState(() {
          _cabangs = data;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data kantor cabang: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<dynamic> get _filteredCabangs {
    return _cabangs.where((item) {
      final nama = (item['nama_cabang'] ?? '').toString().toLowerCase();
      final alamat = (item['alamat'] ?? '').toString().toLowerCase();
      final status = (item['status_kantor'] ?? 'Aset').toString();
      final q = _searchQuery.toLowerCase();

      final matchesQuery = nama.contains(q) || alamat.contains(q);
      final matchesStatus = _selectedStatusFilter == 'all' || status.toLowerCase() == _selectedStatusFilter.toLowerCase();

      return matchesQuery && matchesStatus;
    }).toList();
  }

  int get _countAset => _cabangs.where((c) => (c['status_kantor'] ?? 'Aset') == 'Aset').length;
  int get _countSewa => _cabangs.where((c) => (c['status_kantor'] ?? 'Aset') == 'Sewa').length;

  double get _totalBiayaSewa => _cabangs.where((c) => (c['status_kantor'] ?? 'Aset') == 'Sewa').fold(
      0.0, (sum, c) => sum + (double.tryParse(c['harga_sewa']?.toString() ?? '0') ?? 0.0));

  String _formatCurrency(double value) {
    final formatter = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCabangs;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Enhanced Gradient Header
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppBackButton(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kantor KlinKlin',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kelola data alamat dan riwayat sewa kantor untuk setiap cabang',
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
              ],
            ),
          ),

          // Scrollable Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPI Summary Cards
                    _buildSummaryCards(),

                    const SizedBox(height: 16),

                    // Search & Filter Bar
                    _buildSearchAndFilterBar(),

                    const SizedBox(height: 16),

                    // List Header Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Daftar Kantor Cabang',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'Menampilkan ${filtered.length} kantor',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // List Content
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    else if (filtered.isEmpty)
                      _buildEmptyState()
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            return _buildCabangCard(filtered[index]);
                          },
                        ),
                      ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => KantorKlinklinFormScreen(cabang: null, allCabangs: _cabangs),
            ),
          );
          if (result == true) {
            _loadData();
          }
        },
        backgroundColor: AppColors.primary,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: Text(
          'Tambah Riwayat',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // --- STATS SUMMARY CARDS ---
  Widget _buildSummaryCards() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatCard(
            title: 'Total Kantor',
            value: '${_cabangs.length} Cabang',
            subtitle: 'Seluruh Wilayah',
            icon: Icons.business_rounded,
            color: const Color(0xFF2563EB),
            bgColor: const Color(0xFFEFF6FF),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            title: 'Status Aset',
            value: '$_countAset Kantor',
            subtitle: 'Milik Perusahaan',
            icon: Icons.verified_rounded,
            color: const Color(0xFF059669),
            bgColor: const Color(0xFFECFDF5),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            title: 'Status Sewa',
            value: '$_countSewa Kantor',
            subtitle: 'Total: ${_formatCurrency(_totalBiayaSewa)}',
            icon: Icons.home_work_rounded,
            color: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF5F3FF),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      width: 165,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
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
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- SEARCH & FILTER BAR ---
  Widget _buildSearchAndFilterBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Input
          TextField(
            controller: _searchCtrl,
            onChanged: (val) => setState(() => _searchQuery = val),
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B)),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              hintText: 'Cari nama cabang atau alamat...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Status Filter Tabs
          Row(
            children: [
              _buildFilterTab('all', 'Semua (${_cabangs.length})'),
              const SizedBox(width: 8),
              _buildFilterTab('Aset', 'Aset ($_countAset)'),
              const SizedBox(width: 8),
              _buildFilterTab('Sewa', 'Sewa ($_countSewa)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String key, String label) {
    final isSelected = _selectedStatusFilter == key;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedStatusFilter = key),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- CABANG CARD ITEM ---
  Widget _buildCabangCard(dynamic item) {
    final statusKantor = item['status_kantor'] ?? 'Aset';
    final isAset = statusKantor == 'Aset';

    final formatter = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final hargaSewa = item['harga_sewa'] != null
        ? formatter.format(double.tryParse(item['harga_sewa'].toString()) ?? 0)
        : '-';

    final awalSewaDate = DateTime.tryParse(item['awal_sewa'] ?? '');
    final akhirSewaDate = DateTime.tryParse(item['akhir_sewa'] ?? '');

    final awalSewa = awalSewaDate != null ? DateFormat('dd MMM yyyy').format(awalSewaDate) : '-';
    final akhirSewa = akhirSewaDate != null ? DateFormat('dd MMM yyyy').format(akhirSewaDate) : '-';

    // Calculate remaining lease days
    int? sisaHari;
    bool isExpired = false;
    bool isWarning = false;

    if (!isAset && akhirSewaDate != null) {
      final now = DateTime.now();
      sisaHari = akhirSewaDate.difference(now).inDays;
      if (sisaHari < 0) {
        isExpired = true;
      } else if (sisaHari <= 60) {
        isWarning = true;
      }
    }

    final noTelp = item['no_telp']?.toString() ?? '';
    final alamat = item['alamat'] != null && item['alamat'].toString().isNotEmpty
        ? item['alamat'].toString()
        : 'Alamat belum diatur';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAset
              ? const Color(0xFFE2E8F0)
              : isExpired
                  ? const Color(0xFFFECACA)
                  : isWarning
                      ? const Color(0xFFFDE68A)
                      : const Color(0xFFDDD6FE),
          width: isAset ? 1 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetailSheet(item),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Business Icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isAset ? const Color(0xFFECFDF5) : const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isAset ? const Color(0xFFA7F3D0) : const Color(0xFFDDD6FE),
                        ),
                      ),
                      child: Icon(
                        isAset ? Icons.domain_verification_rounded : Icons.home_work_rounded,
                        color: isAset ? const Color(0xFF059669) : const Color(0xFF7C3AED),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Cabang Name & Alamat
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['nama_cabang'] ?? '-',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (item['pic_nama'] != null && item['pic_nama'].toString().trim().isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'PIC: ${item['pic_nama']}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF475569),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  alamat,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isAset ? const Color(0xFFDCFCE7) : const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isAset ? const Color(0xFF86EFAC) : const Color(0xFFC4B5FD),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isAset ? const Color(0xFF16A34A) : const Color(0xFF7C3AED),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusKantor.toString().toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isAset ? const Color(0xFF15803D) : const Color(0xFF6D28D9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // If SEWA: Show Lease Details Box
                if (!isAset) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Harga Sewa',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hargaSewa,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF7C3AED),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Masa Sewa',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$awalSewa - $akhirSewa',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (sisaHari != null) ...[
                          const SizedBox(height: 8),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                isExpired
                                    ? Icons.error_outline_rounded
                                    : isWarning
                                        ? Icons.warning_amber_rounded
                                        : Icons.timer_outlined,
                                size: 14,
                                color: isExpired
                                    ? Colors.red.shade600
                                    : isWarning
                                        ? Colors.orange.shade700
                                        : const Color(0xFF059669),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isExpired
                                    ? 'Masa sewa telah berakhir (${sisaHari.abs()} hari yang lalu)'
                                    : 'Sisa masa sewa: $sisaHari hari lagi',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isExpired
                                      ? Colors.red.shade600
                                      : isWarning
                                          ? Colors.orange.shade700
                                          : const Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
                const SizedBox(height: 10),

                // Bottom Meta: Phone & Action Buttons (Riwayat + Edit)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.phone_in_talk_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              noTelp.isNotEmpty ? noTelp : 'No. Telp belum diatur',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: noTelp.isNotEmpty ? const Color(0xFF334155) : const Color(0xFF94A3B8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showRiwayatSheet(item),
                          icon: const Icon(Icons.history_rounded, size: 14, color: AppColors.primary),
                          label: Text(
                            'Riwayat',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => KantorKlinklinFormScreen(cabang: item, allCabangs: _cabangs),
                              ),
                            );
                            if (result == true) _loadData();
                          },
                          icon: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                          label: Text(
                            'Edit',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- RIWAYAT SEWA KANTOR BOTTOM SHEET ---
  void _showRiwayatSheet(dynamic cabang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RiwayatSewaKantorSheet(
        cabang: cabang,
        allCabangs: _cabangs,
        onRefreshParent: _loadData,
      ),
    );
  }

  // --- DETAIL BOTTOM SHEET ---
  void _showDetailSheet(dynamic item) {
    final statusKantor = item['status_kantor'] ?? 'Aset';
    final isAset = statusKantor == 'Aset';

    final formatter = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final hargaSewa = item['harga_sewa'] != null
        ? formatter.format(double.tryParse(item['harga_sewa'].toString()) ?? 0)
        : '-';

    final awalSewaDate = DateTime.tryParse(item['awal_sewa'] ?? '');
    final akhirSewaDate = DateTime.tryParse(item['akhir_sewa'] ?? '');

    final awalSewa = awalSewaDate != null ? DateFormat('dd MMMM yyyy').format(awalSewaDate) : '-';
    final akhirSewa = akhirSewaDate != null ? DateFormat('dd MMMM yyyy').format(akhirSewaDate) : '-';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isAset ? const Color(0xFFECFDF5) : const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isAset ? Icons.domain_verification_rounded : Icons.home_work_rounded,
                      color: isAset ? const Color(0xFF059669) : const Color(0xFF7C3AED),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['nama_cabang'] ?? '-',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Kantor Operasional Cabang',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAset ? const Color(0xFFDCFCE7) : const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusKantor.toString().toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isAset ? const Color(0xFF15803D) : const Color(0xFF6D28D9),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 16),

              // Detail fields
              _buildDetailItem(Icons.location_on_rounded, 'Alamat Lengkap', item['alamat'] ?? 'Belum diatur'),
              _buildDetailItem(Icons.phone_rounded, 'Nomor Telepon', item['no_telp'] ?? 'Belum diatur'),

              if (!isAset) ...[
                _buildDetailItem(Icons.payments_rounded, 'Harga Sewa', hargaSewa),
                _buildDetailItem(Icons.calendar_month_rounded, 'Periode Awal Sewa', awalSewa),
                _buildDetailItem(Icons.event_available_rounded, 'Periode Akhir Sewa', akhirSewa),
              ],

              const SizedBox(height: 20),

              // Action Edit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => KantorKlinklinFormScreen(cabang: item, allCabangs: _cabangs),
                      ),
                    );
                    if (result == true) _loadData();
                  },
                  icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                  label: Text(
                    'Edit Informasi Kantor',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF64748B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.business_rounded, color: AppColors.primary, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak Ada Data Kantor',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Data kantor cabang tidak ditemukan untuk filter ini.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RIWAYAT SEWA KANTOR SHEET (Parity with Web Modal)
// ─────────────────────────────────────────────────────────────────────────────
class _RiwayatSewaKantorSheet extends StatefulWidget {
  final dynamic cabang;
  final List<dynamic> allCabangs;
  final VoidCallback onRefreshParent;

  const _RiwayatSewaKantorSheet({
    required this.cabang,
    required this.allCabangs,
    required this.onRefreshParent,
  });

  @override
  State<_RiwayatSewaKantorSheet> createState() => _RiwayatSewaKantorSheetState();
}

class _RiwayatSewaKantorSheetState extends State<_RiwayatSewaKantorSheet> {
  bool _isLoading = true;
  List<dynamic> _riwayatList = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final cabangId = widget.cabang['id'] as int;
      final data = await OperasionalKantorService.fetchRiwayatKantor(cabangId);
      if (mounted) {
        setState(() {
          _riwayatList = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final namaCabang = widget.cabang['nama_cabang'] ?? '-';

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Riwayat Sewa Kantor: $namaCabang',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Daftar catatan riwayat status aset dan sewa cabang',
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
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  splashRadius: 20,
                ),
              ],
            ),
          ),

          // Button + Tambah Riwayat Baru
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => KantorKlinklinFormScreen(
                        cabang: widget.cabang,
                        allCabangs: widget.allCabangs,
                      ),
                    ),
                  );
                  if (result == true) {
                    _fetchHistory();
                    widget.onRefreshParent();
                  }
                },
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: Colors.white),
                label: Text(
                  '+ Tambah Riwayat Baru',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // History List Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _riwayatList.isEmpty
                    ? _buildFallbackCurrentState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _riwayatList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final item = _riwayatList[index];
                          return _buildRiwayatCard(item, isFirst: index == 0);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackCurrentState() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildRiwayatCard(widget.cabang, isFirst: true, isCurrentActive: true),
      ],
    );
  }

  Widget _buildRiwayatCard(dynamic item, {bool isFirst = false, bool isCurrentActive = false}) {
    final status = (item['status_kantor'] ?? 'Aset').toString();
    final isAset = status.toLowerCase() == 'aset';

    final isActive = isCurrentActive || item['is_active'] == true || (item['is_active'] == 1) || isFirst;

    final createdAtStr = item['created_at']?.toString();
    String formattedDate = '-';
    if (createdAtStr != null && createdAtStr.isNotEmpty) {
      final parsedDate = DateTime.tryParse(createdAtStr);
      if (parsedDate != null) {
        formattedDate = DateFormat('dd MMM yyyy').format(parsedDate);
      }
    }

    final formatter = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final rawHarga = item['harga_sewa'];
    final hargaSewa = (rawHarga != null && rawHarga.toString().isNotEmpty && rawHarga.toString() != '0')
        ? formatter.format(double.tryParse(rawHarga.toString()) ?? 0)
        : '-';

    final awalSewaDate = item['awal_sewa'] != null ? DateTime.tryParse(item['awal_sewa'].toString()) : null;
    final akhirSewaDate = item['akhir_sewa'] != null ? DateTime.tryParse(item['akhir_sewa'].toString()) : null;

    final awalSewaStr = awalSewaDate != null ? DateFormat('dd/MM/yyyy').format(awalSewaDate) : '-';
    final akhirSewaStr = akhirSewaDate != null ? DateFormat('dd/MM/yyyy').format(akhirSewaDate) : '-';
    final masaSewa = isAset ? '- s/d -' : '$awalSewaStr s/d $akhirSewaStr';

    final picNama = (item['pic_nama'] != null && item['pic_nama'].toString().trim().isNotEmpty)
        ? item['pic_nama'].toString()
        : '-';

    final noTelp = (item['no_telp'] != null && item['no_telp'].toString().trim().isNotEmpty)
        ? item['no_telp'].toString()
        : '-';

    final alamat = (item['alamat'] != null && item['alamat'].toString().trim().isNotEmpty)
        ? item['alamat'].toString()
        : '-';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Date, Status, Active Checkmark, Edit
            Row(
              children: [
                const Icon(Icons.event_note_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  formattedDate,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(width: 8),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isAset ? const Color(0xFFDCFCE7) : const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isAset ? const Color(0xFF86EFAC) : const Color(0xFFC4B5FD),
                    ),
                  ),
                  child: Text(
                    isAset ? 'Aset' : 'Sewa',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isAset ? const Color(0xFF15803D) : const Color(0xFF6D28D9),
                    ),
                  ),
                ),

                const Spacer(),

                // Active checkmark badge
                if (isActive) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        Text(
                          'Aktif',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // Edit Button
                InkWell(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => KantorKlinklinFormScreen(
                          cabang: item,
                          allCabangs: widget.allCabangs,
                        ),
                      ),
                    );
                    if (result == true) {
                      _fetchHistory();
                      widget.onRefreshParent();
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Grid Details
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildRiwayatRow('NAMA PIC', picNama, Icons.person_outline_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildRiwayatRow('NO TELP', noTelp, Icons.phone_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildRiwayatRow('ALAMAT', alamat, Icons.location_on_outlined),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildRiwayatRow('HARGA SEWA', hargaSewa, Icons.payments_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildRiwayatRow('MASA SEWA', masaSewa, Icons.date_range_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiwayatRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
