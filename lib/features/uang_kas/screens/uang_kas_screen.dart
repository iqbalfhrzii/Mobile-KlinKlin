import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/api/api_client.dart';
import '../services/uang_kas_service.dart';
import 'cashflow_form_sheet.dart';
import 'pengajuan_kas_form_sheet.dart';

class UangKasScreen extends StatefulWidget {
  const UangKasScreen({super.key});

  @override
  State<UangKasScreen> createState() => _UangKasScreenState();
}

class _UangKasScreenState extends State<UangKasScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = UangKasService();

  // User & Branch Scoping
  String _userRole = '';
  int? _userCabangId;
  String _userCabangName = '';
  bool _isOperasionalOrAdmin = false;
  int? _selectedCabangId;
  List<dynamic> _cabangs = [];

  // ================= Tab 1: Cashflow State =================
  bool _isCashflowLoading = true;
  String _cashflowError = '';
  List<dynamic> _cashflows = [];
  final _cashflowSearchController = TextEditingController();
  String _selectedArus = 'Semua Arus';
  final List<String> _arusFilters = ['Semua Arus', 'Masuk', 'Keluar'];
  Timer? _cashflowDebounce;

  double _saldoSekarang = 0;
  double _masukBulanIni = 0;
  double _keluarBulanIni = 0;

  // ================= Tab 2: Pengajuan Kas State =================
  bool _isPengajuanLoading = true;
  String _pengajuanError = '';
  List<dynamic> _pengajuans = [];
  final _pengajuanSearchController = TextEditingController();
  String _selectedPengajuanStatus = 'Semua';
  Timer? _pengajuanDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadUserAndData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cashflowSearchController.dispose();
    _pengajuanSearchController.dispose();
    _cashflowDebounce?.cancel();
    _pengajuanDebounce?.cancel();
    super.dispose();
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

    _fetchCashflow();
    _fetchPengajuanKas();
  }

  // ================= CASHFLOW METHODS =================

  Future<void> _fetchCashflow() async {
    setState(() {
      _isCashflowLoading = true;
      _cashflowError = '';
    });

    try {
      final res = await _service.getCashflow(
        search: _cashflowSearchController.text.trim(),
        cabangId: _selectedCabangId,
        arus: _selectedArus == 'Semua Arus' ? null : _selectedArus,
      );

      final list = (res['data'] is List) ? res['data'] as List : [];

      double allMasuk = 0;
      double allKeluar = 0;
      double thisMonthMasuk = 0;
      double thisMonthKeluar = 0;

      final now = DateTime.now();

      for (var c in list) {
        final nominal = double.tryParse((c['nominal'] ?? 0).toString()) ?? 0;
        final arus = (c['arus'] ?? 'Masuk').toString();
        DateTime? dt;
        try {
          if (c['tanggal'] != null) dt = DateTime.parse(c['tanggal'].toString());
        } catch (_) {}

        if (arus.contains('Masuk')) {
          allMasuk += nominal;
          if (dt != null && dt.month == now.month && dt.year == now.year) {
            thisMonthMasuk += nominal;
          }
        } else {
          allKeluar += nominal;
          if (dt != null && dt.month == now.month && dt.year == now.year) {
            thisMonthKeluar += nominal;
          }
        }
      }

      setState(() {
        _cashflows = List.from(list);
        _masukBulanIni = thisMonthMasuk;
        _keluarBulanIni = thisMonthKeluar;
        _saldoSekarang = (allMasuk - allKeluar);
      });
    } catch (e) {
      setState(() => _cashflowError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isCashflowLoading = false);
    }
  }

  void _onCashflowSearchChanged(String val) {
    if (_cashflowDebounce?.isActive ?? false) _cashflowDebounce!.cancel();
    _cashflowDebounce = Timer(const Duration(milliseconds: 400), () {
      _fetchCashflow();
    });
  }

  void _openCashflowForm({dynamic item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: CashflowFormSheet(
            item: item,
            cabangId: _selectedCabangId ?? 1,
            onSave: () {
              Navigator.pop(context);
              _fetchCashflow();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCashflow(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Data Cashflow?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Data transaksi kas ini akan dihapus permanen.', style: GoogleFonts.inter(fontSize: 13)),
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
      await _service.deleteCashflow(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data cashflow berhasil dihapus'), backgroundColor: Colors.green),
        );
        _fetchCashflow();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ================= PENGAJUAN KAS METHODS =================

  Future<void> _fetchPengajuanKas() async {
    setState(() {
      _isPengajuanLoading = true;
      _pengajuanError = '';
    });

    try {
      final res = await _service.getPengajuanKas(
        search: _pengajuanSearchController.text.trim(),
        cabangId: _selectedCabangId,
        status: _selectedPengajuanStatus == 'Semua' ? null : _selectedPengajuanStatus,
      );

      final list = (res['data'] is List) ? res['data'] as List : [];

      setState(() {
        _pengajuans = List.from(list);
      });
    } catch (e) {
      setState(() => _pengajuanError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isPengajuanLoading = false);
    }
  }

  void _onPengajuanSearchChanged(String val) {
    if (_pengajuanDebounce?.isActive ?? false) _pengajuanDebounce!.cancel();
    _pengajuanDebounce = Timer(const Duration(milliseconds: 400), () {
      _fetchPengajuanKas();
    });
  }

  void _openPengajuanForm({dynamic item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: PengajuanKasFormSheet(
            item: item,
            cabangId: _selectedCabangId ?? 1,
            onSave: () {
              Navigator.pop(context);
              _fetchPengajuanKas();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _deletePengajuan(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Pengajuan Kas?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Pengajuan uang kas ini akan dihapus dari sistem.', style: GoogleFonts.inter(fontSize: 13)),
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
      await _service.deletePengajuanKas(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengajuan kas berhasil dihapus'), backgroundColor: Colors.green),
        );
        _fetchPengajuanKas();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ================= UTILITIES =================

  String _formatRupiah(num? n) {
    if (n == null) return 'Rp 0';
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(n);
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(date.toString()));
    } catch (_) {
      return date.toString();
    }
  }

  String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final baseUrl = ApiClient.baseUrl.replaceAll('/api', '');
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    if (cleanPath.startsWith('storage/')) {
      return '$baseUrl/$cleanPath';
    }
    return '$baseUrl/storage/$cleanPath';
  }

  void _showImageDialog(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text('Gagal memuat gambar bukti', style: GoogleFonts.inter(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: InkWell(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTab0 = _tabController.index == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Gradient Header
          GradientHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (Navigator.canPop(context)) ...[
                      HeaderBackButton(onTap: () => Navigator.pop(context)),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Uang Kas Cabang',
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kelola arus kas & pengajuan dana ke Finance',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _fetchCashflow();
                        _fetchPengajuanKas();
                      },
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Modern 2-Tab Selector
                Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    labelColor: AppColors.primaryMid,
                    unselectedLabelColor: Colors.white,
                    labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                    unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                    tabs: const [
                      Tab(text: 'Cashflow Cabang'),
                      Tab(text: 'Pengajuan Kas'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCashflowTab(),
                _buildPengajuanTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isTab0 ? () => _openCashflowForm() : () => _openPengajuanForm(),
        backgroundColor: AppColors.primaryMid,
        elevation: 3,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          isTab0 ? 'Tambah Data' : 'Buat Pengajuan',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }

  // ================= TAB 1: CASHFLOW VIEW =================

  Widget _buildCashflowTab() {
    return Column(
      children: [
        // KPI Summary Cards
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              // Row 1: Saldo Kas Sekarang (Dark Hero Card)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_rounded, size: 14, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 6),
                            Text(
                              'SALDO KAS SEKARANG (DANA AKTUAL)',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8), letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatRupiah(_saldoSekarang),
                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    if (!_isOperasionalOrAdmin && _userCabangId != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, size: 12, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 4),
                            Text(
                              _userCabangName.isNotEmpty ? _userCabangName : 'Cabang $_userCabangId',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Row 2: Masuk & Keluar Bulan ini
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_downward_rounded, size: 12, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Masuk', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF047857))),
                                Text(
                                  _formatRupiah(_masukBulanIni),
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF065F46)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_upward_rounded, size: 12, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Keluar', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFB91C1C))),
                                Text(
                                  _formatRupiah(_keluarBulanIni),
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF991B1B)),
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
            ],
          ),
        ),

        // Search & Filter Arus Chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: [
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _cashflowSearchController,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Cari keterangan atau kategori...',
                    hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                    suffixIcon: _cashflowSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                            onPressed: () {
                              _cashflowSearchController.clear();
                              _fetchCashflow();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: _onCashflowSearchChanged,
                ),
              ),
              const SizedBox(height: 10),
              // Filter Chips
              Row(
                children: _arusFilters.map((arus) {
                  final isSelected = _selectedArus == arus;
                  final activeColor = arus == 'Masuk'
                      ? const Color(0xFF16A34A)
                      : arus == 'Keluar'
                          ? const Color(0xFFDC2626)
                          : AppColors.primaryMid;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(arus),
                      selected: isSelected,
                      selectedColor: activeColor,
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: isSelected ? activeColor : Colors.transparent),
                      ),
                      onSelected: (_) {
                        setState(() => _selectedArus = arus);
                        _fetchCashflow();
                      },
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // Cashflow List
        Expanded(
          child: _isCashflowLoading
              ? const Center(child: CircularProgressIndicator())
              : _cashflowError.isNotEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 40, color: Colors.red),
                            const SizedBox(height: 8),
                            Text(_cashflowError, style: GoogleFonts.inter(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _fetchCashflow,
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMid),
                              child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _cashflows.isEmpty
                      ? Center(
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
                                  child: const Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.primaryMid),
                                ),
                                const SizedBox(height: 14),
                                Text('Belum Ada Data Cashflow', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                                const SizedBox(height: 4),
                                Text('Tekan tombol "+ Tambah Data" untuk mencatat pemasukan atau pengeluaran kas.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted), textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchCashflow,
                          color: AppColors.primaryMid,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: _cashflows.length,
                            itemBuilder: (context, index) {
                              final item = _cashflows[index];
                              final isMasuk = (item['arus'] ?? 'Masuk').toString().contains('Masuk');
                              final nominal = double.tryParse((item['nominal'] ?? 0).toString()) ?? 0;
                              final kategori = item['kategori_kas'] ?? 'Umum';
                              final metode = item['metode'] ?? 'cash';
                              final keterangan = item['keterangan'] ?? '-';
                              final tglStr = _formatDate(item['tanggal']);
                              final buktiUrl = _getImageUrl(item['bukti']);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header: Tanggal & Arus Badge
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textMuted),
                                              const SizedBox(width: 4),
                                              Text(tglStr, style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isMasuk ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: isMasuk ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isMasuk ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                                  size: 12,
                                                  color: isMasuk ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  isMasuk ? 'Masuk' : 'Keluar',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: isMasuk ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // Nominal & Kategori
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _formatRupiah(nominal),
                                                style: GoogleFonts.inter(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.bold,
                                                  color: isMasuk ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'Kategori: $kategori',
                                                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF475569), fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 10),

                                      // Keterangan & Via
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                keterangan.isNotEmpty ? keterangan : '-',
                                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF334155)),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Via: $metode',
                                              style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 10),

                                      // Bottom Actions: Bukti on Left, Edit/Hapus on Right
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Left: Bukti Button
                                          if (buktiUrl.isNotEmpty)
                                            InkWell(
                                              onTap: () => _showImageDialog(context, buktiUrl, 'Bukti Transaksi'),
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryMid.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: AppColors.primaryMid.withValues(alpha: 0.2)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.receipt_long_rounded, size: 15, color: AppColors.primaryMid),
                                                    const SizedBox(width: 5),
                                                    Text(
                                                      'Lihat Bukti',
                                                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primaryMid),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          else
                                            const SizedBox.shrink(),

                                          // Right: Edit & Hapus Buttons
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              InkWell(
                                                onTap: () => _openCashflowForm(item: item),
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primaryMid.withValues(alpha: 0.08),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.edit_outlined, size: 14, color: AppColors.primaryMid),
                                                      const SizedBox(width: 4),
                                                      Text('Edit', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primaryMid)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              InkWell(
                                                onTap: () => _deleteCashflow(item['id']),
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.withValues(alpha: 0.08),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                                                      const SizedBox(width: 4),
                                                      Text('Hapus', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.red)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  // ================= TAB 2: PENGAJUAN UANG KAS VIEW =================

  Widget _buildPengajuanTab() {
    final totalPengajuan = _pengajuans.length;
    final pendingCount = _pengajuans.where((p) => (p['status'] ?? 'pending').toString().toLowerCase() == 'pending').length;
    final approvedCount = _pengajuans.where((p) => (p['status'] ?? '').toString().toLowerCase() == 'disetujui' || (p['status'] ?? '').toString().toLowerCase() == 'approved').length;
    final rejectedCount = _pengajuans.where((p) => (p['status'] ?? '').toString().toLowerCase() == 'ditolak' || (p['status'] ?? '').toString().toLowerCase() == 'rejected').length;

    return Column(
      children: [
        // Top KPI Clickable Filter Cards
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  _buildPengajuanStat('Total', '$totalPengajuan', AppColors.primaryMid, const Color(0xFFF1F5F9), 'Semua'),
                  const SizedBox(width: 6),
                  _buildPengajuanStat('Pending', '$pendingCount', const Color(0xFFD97706), const Color(0xFFFEF3C7), 'Pending'),
                  const SizedBox(width: 6),
                  _buildPengajuanStat('Disetujui', '$approvedCount', const Color(0xFF16A34A), const Color(0xFFDCFCE7), 'Disetujui'),
                  const SizedBox(width: 6),
                  _buildPengajuanStat('Ditolak', '$rejectedCount', const Color(0xFFDC2626), const Color(0xFFFEE2E2), 'Ditolak'),
                ],
              ),
              const SizedBox(height: 10),

              // Search Bar
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _pengajuanSearchController,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Cari keterangan pengajuan...',
                    hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                    suffixIcon: _pengajuanSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                            onPressed: () {
                              _pengajuanSearchController.clear();
                              _fetchPengajuanKas();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: _onPengajuanSearchChanged,
                ),
              ),
            ],
          ),
        ),

        // Pengajuan List
        Expanded(
          child: _isPengajuanLoading
              ? const Center(child: CircularProgressIndicator())
              : _pengajuanError.isNotEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 40, color: Colors.red),
                            const SizedBox(height: 8),
                            Text(_pengajuanError, style: GoogleFonts.inter(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _fetchPengajuanKas,
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMid),
                              child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _pengajuans.isEmpty
                      ? Center(
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
                                  child: const Icon(Icons.monetization_on_outlined, size: 48, color: AppColors.primaryMid),
                                ),
                                const SizedBox(height: 14),
                                Text('Belum Ada Pengajuan Kas', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                                const SizedBox(height: 4),
                                Text('Tekan tombol "+ Buat Pengajuan" untuk mengajukan permohonan uang kas ke Finance.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted), textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchPengajuanKas,
                          color: AppColors.primaryMid,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: _pengajuans.length,
                            itemBuilder: (context, index) {
                              final item = _pengajuans[index];
                              final status = (item['status'] ?? 'pending').toString().toLowerCase();
                              final isPending = status == 'pending';
                              final isApproved = status == 'disetujui' || status == 'approved';
                              final isRejected = status == 'ditolak' || status == 'rejected';

                              final nominal = double.tryParse((item['nominal'] ?? 0).toString()) ?? 0;
                              final keterangan = item['keterangan'] ?? '-';
                              final tglStr = _formatDate(item['tanggal']);
                              final buktiTransfer = _getImageUrl(item['bukti_transfer']);

                              Color statusColor = const Color(0xFFD97706);
                              String statusLabel = 'Pending';
                              IconData statusIcon = Icons.access_time_rounded;
                              if (isApproved) {
                                statusColor = const Color(0xFF16A34A);
                                statusLabel = 'Disetujui';
                                statusIcon = Icons.check_circle_outline_rounded;
                              } else if (isRejected) {
                                statusColor = const Color(0xFFDC2626);
                                statusLabel = 'Ditolak';
                                statusIcon = Icons.highlight_off_rounded;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header: Tanggal & Status Badge
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textMuted),
                                              const SizedBox(width: 4),
                                              Text(tglStr, style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(statusIcon, size: 12, color: statusColor),
                                                const SizedBox(width: 3),
                                                Text(
                                                  statusLabel,
                                                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // Nominal
                                      Text(
                                        _formatRupiah(nominal),
                                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                      ),
                                      const SizedBox(height: 6),

                                      // Keterangan / Tujuan
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: const Border(left: BorderSide(color: AppColors.primaryMid, width: 3)),
                                        ),
                                        child: Text(
                                          keterangan,
                                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155), height: 1.35),
                                        ),
                                      ),

                                      // Bukti Transfer (if approved)
                                      if (buktiTransfer.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        InkWell(
                                          onTap: () => _showImageDialog(context, buktiTransfer, 'Bukti Transfer Finance'),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFA7F3D0)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF16A34A)),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Lihat Bukti Transfer Finance',
                                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF065F46)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],

                                      if (isPending) ...[
                                        const SizedBox(height: 10),
                                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            InkWell(
                                              onTap: () => _openPengajuanForm(item: item),
                                              borderRadius: BorderRadius.circular(6),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryMid.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.edit_outlined, size: 13, color: AppColors.primaryMid),
                                                    const SizedBox(width: 4),
                                                    Text('Edit', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryMid)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () => _deletePengajuan(item['id']),
                                              borderRadius: BorderRadius.circular(6),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.delete_outline, size: 13, color: Colors.red),
                                                    const SizedBox(width: 4),
                                                    Text('Hapus', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildPengajuanStat(String label, String count, Color textColor, Color bgColor, String filterKey) {
    final isSelected = _selectedPengajuanStatus == filterKey;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _selectedPengajuanStatus = filterKey);
            _fetchPengajuanKas();
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected ? textColor : bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? textColor : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: textColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
