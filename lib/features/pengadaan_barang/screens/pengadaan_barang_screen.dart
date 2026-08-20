import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/pengadaan_barang_service.dart';
import 'pengadaan_barang_form_sheet.dart';
import 'pengadaan_barang_detail_sheet.dart';

class PengadaanBarangScreen extends StatefulWidget {
  const PengadaanBarangScreen({super.key});

  @override
  State<PengadaanBarangScreen> createState() => _PengadaanBarangScreenState();
}

class _PengadaanBarangScreenState extends State<PengadaanBarangScreen> {
  final _service = PengadaanBarangService();
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _error = '';
  List<dynamic> _pengajuans = [];
  List<dynamic> _cabangs = [];

  int _currentPage = 1;
  int _lastPage = 1;

  String _selectedStatus = 'Semua';
  final List<String> _statusFilters = ['Semua', 'Pending', 'Approved', 'Rejected'];

  String _selectedJenis = 'Semua';
  final List<String> _jenisFilters = ['Semua', 'Alat', 'Chemical', 'BHP'];

  int? _selectedCabangId;
  String _userRole = '';
  int? _userCabangId;
  String _userCabangName = '';
  bool _isOperasionalOrAdmin = true;

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _currentPage < _lastPage) {
        _fetchPengajuans(page: _currentPage + 1, append: true);
      }
    }
  }

  Future<void> _loadUserAndData() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    _userCabangId = prefs.getInt('user_cabang_id');
    _userCabangName = prefs.getString('user_cabang_name') ?? '';

    final r = _userRole.toLowerCase();
    _isOperasionalOrAdmin = r.contains('operasional') || r.contains('admin') || r.contains('ceo') || r.contains('superadmin');

    if (!_isOperasionalOrAdmin && _userCabangId != null) {
      _selectedCabangId = _userCabangId;
    }

    try {
      final cabangs = await _service.getCabangs();
      if (mounted) {
        setState(() {
          _cabangs = cabangs;
          if (_userCabangName.isEmpty && _userCabangId != null && _cabangs.isNotEmpty) {
            final match = _cabangs.firstWhere((c) => c['id'] == _userCabangId, orElse: () => null);
            if (match != null) {
              _userCabangName = match['nama_cabang'] ?? match['nama'] ?? 'Cabang $_userCabangId';
            }
          }
        });
      }
    } catch (_) {}

    _fetchPengajuans();
  }

  Future<void> _fetchPengajuans({int page = 1, bool append = false}) async {
    if (!append) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final res = await _service.getPengajuan(
        page: page,
        search: _searchController.text.trim(),
        status: _selectedStatus == 'Semua' ? null : _selectedStatus,
        jenis: _selectedJenis == 'Semua' ? null : _selectedJenis,
        cabangId: _selectedCabangId,
      );

      final list = (res['data'] is List) ? res['data'] as List : [];

      setState(() {
        if (append) {
          _pengajuans.addAll(list);
        } else {
          _pengajuans = List.from(list);
        }
        _currentPage = res['current_page'] ?? 1;
        _lastPage = res['last_page'] ?? 1;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  String _getUrgensiLabel(String? urgensi) {
    final u = (urgensi ?? 'low').toLowerCase();
    if (u.contains('darurat') || u.contains('high') || u.contains('tinggi')) {
      return 'Tinggi';
    } else if (u.contains('medium') || u.contains('sedang')) {
      return 'Sedang';
    } else {
      return 'Rendah';
    }
  }

  Color _getUrgensiColor(String? urgensi) {
    final u = (urgensi ?? 'low').toLowerCase();
    if (u.contains('darurat') || u.contains('high') || u.contains('tinggi')) {
      return const Color(0xFFDC2626); // Red
    } else if (u.contains('medium') || u.contains('sedang')) {
      return const Color(0xFFD97706); // Amber
    } else {
      return const Color(0xFF16A34A); // Green
    }
  }

  Color _getStatusColor(String? status) {
    final s = (status ?? 'pending').toLowerCase();
    if (s.contains('setuju') || s == 'approved') {
      return const Color(0xFF16A34A);
    } else if (s.contains('tolak') || s == 'rejected') {
      return const Color(0xFFDC2626);
    } else {
      return const Color(0xFFD97706);
    }
  }

  IconData _getJenisIcon(String? jenis) {
    final j = (jenis ?? '').toLowerCase();
    if (j == 'chemical') {
      return Icons.science_outlined;
    } else if (j == 'bhp') {
      return Icons.cleaning_services_outlined;
    }
    return Icons.build_outlined;
  }

  void _openForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: PengadaanBarangFormSheet(
            onSave: () {
              Navigator.pop(context);
              _fetchPengajuans(page: 1);
            },
          ),
        ),
      ),
    );
  }

  void _showDetailModal(dynamic item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: PengadaanBarangDetailSheet(item: item),
      ),
    );
  }

  Future<void> _deletePengajuan(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Pengajuan?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Data pengadaan barang ini akan dihapus dari sistem.', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, elevation: 0),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      await _service.deletePengajuan(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengajuan berhasil dihapus'), backgroundColor: Colors.green),
        );
        _fetchPengajuans(page: 1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate stats
    final totalCount = _pengajuans.length;
    final pendingCount = _pengajuans.where((p) => (p['status_pengajuan'] ?? 'pending').toString().toLowerCase() == 'pending').length;
    final approvedCount = _pengajuans.where((p) => (p['status_pengajuan'] ?? '').toString().toLowerCase() == 'approved').length;
    final rejectedCount = _pengajuans.where((p) => (p['status_pengajuan'] ?? '').toString().toLowerCase() == 'rejected').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Gradient Header
          GradientHeader(
            child: Row(
              children: [
                HeaderBackButton(onTap: () => Navigator.pop(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pengajuan Alat & Chemical',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kelola permintaan barang cabang',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _fetchPengajuans(page: 1),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          // Search & Filters Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Search + Branch
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: GoogleFonts.inter(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Cari Nama Barang / Merk...',
                            hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12),
                            prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                                    onPressed: () {
                                      _searchController.clear();
                                      _fetchPengajuans(page: 1);
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onSubmitted: (_) => _fetchPengajuans(page: 1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Branch indicator / selector
                    if (!_isOperasionalOrAdmin && _userCabangId != null)
                      Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryMid.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primaryMid.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, size: 14, color: AppColors.primaryMid),
                            const SizedBox(width: 4),
                            Text(
                              _userCabangName.isNotEmpty ? _userCabangName : 'Cabang $_userCabangId',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryMid),
                            ),
                          ],
                        ),
                      )
                    else if (_cabangs.isNotEmpty)
                      Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _selectedCabangId,
                            hint: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark)),
                            icon: const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('Semua Cabang')),
                              ..._cabangs.map((c) => DropdownMenuItem<int?>(
                                    value: c['id'],
                                    child: Text(c['nama_cabang'] ?? c['nama'] ?? 'Cabang ${c['id']}'),
                                  )),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedCabangId = val);
                              _fetchPengajuans(page: 1);
                            },
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // Filter Chips Row (Jenis & Status)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Jenis Chips
                      ..._jenisFilters.map((j) {
                        final isSelected = _selectedJenis == j;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(j == 'Semua' ? 'Semua Jenis' : j),
                            selected: isSelected,
                            selectedColor: AppColors.primaryMid,
                            backgroundColor: Colors.grey.shade100,
                            labelStyle: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.textDark,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            onSelected: (_) {
                              setState(() => _selectedJenis = j);
                              _fetchPengajuans(page: 1);
                            },
                          ),
                        );
                      }),
                      const SizedBox(width: 4),
                      Container(height: 20, width: 1, color: Colors.grey.shade300),
                      const SizedBox(width: 8),

                      // Status Chips
                      ..._statusFilters.map((s) {
                        final isSelected = _selectedStatus == s;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(s),
                            selected: isSelected,
                            selectedColor: s == 'Approved'
                                ? const Color(0xFF16A34A)
                                : s == 'Rejected'
                                    ? const Color(0xFFDC2626)
                                    : s == 'Pending'
                                        ? const Color(0xFFD97706)
                                        : AppColors.textDark,
                            backgroundColor: Colors.grey.shade100,
                            labelStyle: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.textDark,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            onSelected: (_) {
                              setState(() => _selectedStatus = s);
                              _fetchPengajuans(page: 1);
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mini KPI Stats
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                _buildMiniStat('Total', '$totalCount', AppColors.textDark, Colors.grey.shade100),
                const SizedBox(width: 8),
                _buildMiniStat('Pending', '$pendingCount', const Color(0xFFD97706), const Color(0xFFFEF3C7)),
                const SizedBox(width: 8),
                _buildMiniStat('Approved', '$approvedCount', const Color(0xFF16A34A), const Color(0xFFDCFCE7)),
                const SizedBox(width: 8),
                _buildMiniStat('Rejected', '$rejectedCount', const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
              ],
            ),
          ),

          // List Data
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 40, color: Colors.red),
                              const SizedBox(height: 8),
                              Text(_error, style: GoogleFonts.inter(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _fetchPengajuans(page: 1),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMid),
                                child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        backgroundColor: AppColors.primaryMid,
        elevation: 3,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Buat Pengajuan',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String count, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: textColor)),
            const SizedBox(height: 2),
            Text(count, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_pengajuans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryMid.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.primaryMid),
              ),
              const SizedBox(height: 14),
              Text(
                'Belum Ada Pengajuan',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 4),
              Text(
                'Tekan tombol "+ Buat Pengajuan" untuk mengajukan pengadaan alat atau chemical.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchPengajuans(page: 1),
      color: AppColors.primaryMid,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _pengajuans.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _pengajuans.length) {
            return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
          }

          final item = _pengajuans[index];
          final status = (item['status_pengajuan'] ?? 'pending').toString().toLowerCase();
          final statusColor = _getStatusColor(status);

          final namaBarang = item['nama_barang'] ?? '-';
          final merkSpek = item['merk_spesifikasi'] ?? '-';
          final jenis = item['jenis_pembelian'] ?? 'Alat';
          final jumlah = item['jumlah'] ?? 1;
          final satuan = item['satuan'] == 'Other' ? (item['satuan_lainnya'] ?? 'Pcs') : (item['satuan'] ?? 'Pcs');
          final urgensi = item['tingkat_urgensi'] ?? 'Low';
          final urgensiColor = _getUrgensiColor(urgensi);
          final pemohon = item['pemohon']?['nama_lengkap'] ?? item['pemohon']?['nama'] ?? item['pemohon']?['name'] ?? 'Bagus';
          final cabang = item['cabang']?['nama_cabang'] ?? item['cabang']?['nama'] ?? 'Surabaya';

          String tglStr = '-';
          if (item['tanggal_pengajuan'] != null) {
            try {
              tglStr = DateFormat('dd MMM yyyy').format(DateTime.parse(item['tanggal_pengajuan'].toString()));
            } catch (_) {
              tglStr = item['tanggal_pengajuan'].toString();
            }
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      Icon(_getJenisIcon(jenis), size: 16, color: AppColors.primaryMid),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryMid.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          jenis,
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryMid),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tglStr,
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status == 'pending'
                              ? 'Pending'
                              : status == 'approved'
                                  ? 'Approved'
                                  : 'Rejected',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                ),

                // Body Card
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item Name & Qty
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  namaBarang,
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  merkSpek,
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  '$jumlah $satuan',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: urgensiColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getUrgensiLabel(urgensi),
                                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: urgensiColor),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Location & Requester info banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 13, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(pemohon, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(cabang, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFEEEEEE)),

                // Actions Footer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => _showDetailModal(item),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryMid.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.remove_red_eye_outlined, size: 14, color: AppColors.primaryMid),
                              const SizedBox(width: 4),
                              Text('Detail', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryMid)),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (status == 'pending')
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          onPressed: () => _deletePengajuan(item['id']),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          tooltip: 'Hapus',
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
