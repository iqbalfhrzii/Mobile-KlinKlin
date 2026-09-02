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
      useSafeArea: true,
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
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: PengadaanBarangDetailSheet(item: item),
      ),
    );
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedJenis != 'Semua') count++;
    if (_selectedStatus != 'Semua') count++;
    if (_isOperasionalOrAdmin && _selectedCabangId != null) count++;
    return count;
  }

  void _openFilterSheet() {
    String tempJenis = _selectedJenis;
    String tempStatus = _selectedStatus;
    int? tempCabangId = _selectedCabangId;

    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, size: 20, color: AppColors.primaryMid),
                      const SizedBox(width: 8),
                      Text(
                        'Filter Pengajuan',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempJenis = 'Semua';
                            tempStatus = 'Semua';
                            if (_isOperasionalOrAdmin) {
                              tempCabangId = null;
                            }
                          });
                        },
                        child: Text(
                          'Reset',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 16),

              // Section 1: Jenis Barang
              Text(
                'Jenis Barang',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _jenisFilters.map((j) {
                  final isSel = tempJenis == j;
                  return ChoiceChip(
                    label: Text(j == 'Semua' ? 'Semua Jenis' : j),
                    selected: isSel,
                    selectedColor: AppColors.primaryMid,
                    backgroundColor: const Color(0xFFF1F5F9),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                      color: isSel ? Colors.white : AppColors.textDark,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isSel ? AppColors.primaryMid : Colors.transparent),
                    ),
                    onSelected: (_) {
                      setModalState(() => tempJenis = j);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Section 2: Status Pengajuan
              Text(
                'Status Pengajuan',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _statusFilters.map((s) {
                  final isSel = tempStatus == s;
                  final activeColor = s == 'Approved'
                      ? const Color(0xFF16A34A)
                      : s == 'Rejected'
                          ? const Color(0xFFDC2626)
                          : s == 'Pending'
                              ? const Color(0xFFD97706)
                              : AppColors.primaryMid;
                  return ChoiceChip(
                    label: Text(s == 'Semua' ? 'Semua Status' : s),
                    selected: isSel,
                    selectedColor: activeColor,
                    backgroundColor: const Color(0xFFF1F5F9),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                      color: isSel ? Colors.white : AppColors.textDark,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isSel ? activeColor : Colors.transparent),
                    ),
                    onSelected: (_) {
                      setModalState(() => tempStatus = s);
                    },
                  );
                }).toList(),
              ),

              // Section 3: Cabang (Jika Operasional / Admin)
              if (_isOperasionalOrAdmin && _cabangs.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Cabang',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Semua Cabang'),
                      selected: tempCabangId == null,
                      selectedColor: AppColors.primaryMid,
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: tempCabangId == null ? FontWeight.bold : FontWeight.w500,
                        color: tempCabangId == null ? Colors.white : AppColors.textDark,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: tempCabangId == null ? AppColors.primaryMid : Colors.transparent),
                      ),
                      onSelected: (_) {
                        setModalState(() => tempCabangId = null);
                      },
                    ),
                    ..._cabangs.map((c) {
                      final isSel = tempCabangId == c['id'];
                      final cName = c['nama_cabang'] ?? c['nama'] ?? 'Cabang ${c['id']}';
                      return ChoiceChip(
                        label: Text(cName),
                        selected: isSel,
                        selectedColor: AppColors.primaryMid,
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          color: isSel ? Colors.white : AppColors.textDark,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: isSel ? AppColors.primaryMid : Colors.transparent),
                        ),
                        onSelected: (_) {
                          setModalState(() => tempCabangId = c['id']);
                        },
                      );
                    }),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedJenis = tempJenis;
                      _selectedStatus = tempStatus;
                      _selectedCabangId = tempCabangId;
                    });
                    _fetchPengajuans(page: 1);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMid,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Terapkan Filter',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

          // Search & Filter Row Header
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 8 : 10),
            child: Row(
              children: [
                // Search Input Box
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

                // Single Filter Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openFilterSheet,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _activeFilterCount > 0 ? AppColors.primaryMid : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _activeFilterCount > 0 ? AppColors.primaryMid : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 16,
                            color: _activeFilterCount > 0 ? Colors.white : AppColors.textDark,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _activeFilterCount > 0 ? 'Filter ($_activeFilterCount)' : 'Filter',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _activeFilterCount > 0 ? Colors.white : AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showDetailModal(item),
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      child: Row(
                        children: [
                          Icon(_getJenisIcon(jenis), size: 16, color: AppColors.primaryMid),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryMid.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              jenis,
                              style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primaryMid),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tglStr,
                              style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textMuted),
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
                              style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      namaBarang,
                                      style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                    ),
                                    const SizedBox(height: 3),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                      'Urgensi: ${_getUrgensiLabel(urgensi)}',
                                      style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: urgensiColor),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Location & Requester info banner with chevron
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFF1F5F9)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(pemohon, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 12),
                                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(cabang, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Detail', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.primaryMid)),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.primaryMid),
                                  ],
                                ),
                              ],
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
        },
      ),
    );
  }
}
