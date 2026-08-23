import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/api/api_client.dart';
import '../services/operasional_cashflow_cabang_service.dart';

class OperasionalCashflowCabangScreen extends StatefulWidget {
  const OperasionalCashflowCabangScreen({super.key});

  @override
  State<OperasionalCashflowCabangScreen> createState() => _OperasionalCashflowCabangScreenState();
}

class _OperasionalCashflowCabangScreenState extends State<OperasionalCashflowCabangScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _cashflows = [];
  List<dynamic> _cabangList = [];
  bool _isLoading = false;
  String? _authToken;
  Timer? _debounce;

  int? _selectedCabangId;
  String _selectedArus = 'Semua Arus';

  // Summary Metrics matching Web Dashboard
  double _masukBulanIni = 0.0;
  double _keluarBulanIni = 0.0;
  double _pengajuanBulanIni = 0.0;
  double _saldoSekarang = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAuthToken();
    _fetchCabangList();
    _fetchData();
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

  Future<void> _fetchCabangList() async {
    try {
      final response = await OperasionalCashflowCabangService.getCabangs();
      final data = response['data'] ?? response['cabangs'];
      if (data is List && mounted && data.isNotEmpty) {
        setState(() {
          _cabangList = data;
        });
      }
    } catch (e) {
      debugPrint('Error fetching cabang: $e');
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final response = await OperasionalCashflowCabangService.getCashflow(
        search: _searchController.text.trim(),
        cabangId: _selectedCabangId,
        arus: _selectedArus == 'Semua Arus' ? null : _selectedArus,
      );
      if (response['success'] == true && mounted) {
        setState(() {
          _cashflows = response['data'] ?? [];
          if (response['summary'] != null) {
            final s = response['summary'];
            _masukBulanIni = double.tryParse(s['total_masuk_bulan_ini']?.toString() ?? '0') ?? 0.0;
            _keluarBulanIni = double.tryParse(s['total_keluar_bulan_ini']?.toString() ?? '0') ?? 0.0;
            _pengajuanBulanIni = double.tryParse(s['pengajuan_kas_bulan_ini']?.toString() ?? '0') ?? 0.0;
            _saldoSekarang = double.tryParse(s['saldo_kas_sekarang']?.toString() ?? '0') ?? 0.0;
          } else {
            _recalculateSummaryFallback();
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching cashflow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat data cashflow')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _recalculateSummaryFallback() {
    final now = DateTime.now();
    _masukBulanIni = 0;
    _keluarBulanIni = 0;
    _saldoSekarang = 0;
    _pengajuanBulanIni = 0;

    for (final item in _cashflows) {
      final nom = double.tryParse(item['nominal']?.toString() ?? '0') ?? 0;
      final arus = item['arus']?.toString() ?? '';
      final kat = item['kategori_kas']?.toString() ?? '';
      final tglStr = item['tanggal']?.toString() ?? '';
      final tgl = DateTime.tryParse(tglStr);

      final isPengajuan = kat.toLowerCase().contains('pengajuan') || kat == 'Pengajuan Uang Kas';

      if (arus.contains('Masuk')) {
        _saldoSekarang += nom;
        if (tgl != null && tgl.month == now.month && tgl.year == now.year) {
          if (!isPengajuan) {
            _masukBulanIni += nom;
          } else {
            _pengajuanBulanIni += nom;
          }
        }
      } else if (arus.contains('Keluar')) {
        _saldoSekarang -= nom;
        if (tgl != null && tgl.month == now.month && tgl.year == now.year) {
          _keluarBulanIni += nom;
        }
      }
    }
  }

  Future<void> _deleteCashflow(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Data Cashflow', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text('Apakah kamu yakin ingin menghapus data cashflow ini?', style: GoogleFonts.inter(color: const Color(0xFF475569))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Hapus', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final response = await OperasionalCashflowCabangService.deleteCashflow(id);
      if (response['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data cashflow berhasil dihapus'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        _fetchData();
      }
    } catch (e) {
      debugPrint('Error deleting cashflow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus data')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showFormBottomSheet({Map<String, dynamic>? data}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FormCashflowBottomSheet(
        data: data,
        cabangList: _cabangList,
        onSaved: () {
          _fetchData();
        },
      ),
    );
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return 'Rp 0';
    try {
      double parsedValue = double.parse(value.toString());
      final format = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
      return format.format(parsedValue);
    } catch (e) {
      return 'Rp 0';
    }
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '-';
    try {
      DateTime dt = DateTime.parse(date);
      final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      final dayName = days[dt.weekday % 7];
      final monthName = months[dt.month - 1];
      return '$dayName, ${dt.day} $monthName ${dt.year}';
    } catch (e) {
      return date;
    }
  }

  String _getFileUrl(dynamic rawPath) {
    if (rawPath == null) return '';
    String p = rawPath.toString().trim().replaceAll(r'\', '/');
    if (p.isEmpty || p == 'null') return '';
    if (p.startsWith('http://') || p.startsWith('https://')) return p;

    final baseDomain = ApiClient.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    if (p.startsWith('public/')) {
      p = p.substring(7);
    }
    if (p.startsWith('storage/')) {
      return '$baseDomain/$p';
    }
    return '$baseDomain/storage/$p';
  }

  bool _isImageFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  void _viewBuktiInApp(String path, String title) {
    final fullUrl = _getFileUrl(path);
    if (fullUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lampiran bukti tidak valid.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _CashflowFileViewerDialog(
        url: fullUrl,
        title: title,
        authToken: _authToken,
        isImage: _isImageFile(fullUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Elegant Gradient Header
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 18),
            child: Row(
              children: [
                if (Navigator.canPop(context)) ...[
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Cashflow Cabang',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kelola pemasukan dan pengeluaran kas cabang',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search and Filters Bar
          _buildFilterBar(),

          // List Body with Stats Card
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    color: AppColors.primary,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                      children: [
                        // Summary Stats Overview
                        _buildSummaryStatsCard(),
                        const SizedBox(height: 14),

                        // Section Heading
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Riwayat Transaksi',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                            ),
                            Text(
                              '${_cashflows.length} Transaksi',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // List of Cashflows
                        if (_cashflows.isEmpty)
                          _buildEmptyState()
                        else
                          ..._cashflows.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildCashflowCard(item),
                              )),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormBottomSheet(),
        backgroundColor: AppColors.primary,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: Text(
          'Tambah Data',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
    );
  }

  // --- FILTER HELPER GETTERS & BADGES ---
  int get _activeFiltersCount {
    int count = 0;
    if (_selectedCabangId != null) count++;
    if (_selectedArus != 'Semua Arus' && _selectedArus.isNotEmpty) count++;
    return count;
  }

  // --- FILTER BAR (SEARCH + UNIFIED FILTER BUTTON) ---
  Widget _buildFilterBar() {
    final activeCount = _activeFiltersCount;
    final bool hasActiveFilters = activeCount > 0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input & Filter Button Row
          Row(
            children: [
              // Search Input Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Cari keterangan, kategori, metode...',
                            hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF64748B)),
                          onPressed: () {
                            _searchController.clear();
                            _fetchData();
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Filter Button (Unified Modal Trigger)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showComprehensiveFilterModal,
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: hasActiveFilters ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasActiveFilters ? AppColors.primary : const Color(0xFFCBD5E1),
                        width: 1.5,
                      ),
                      boxShadow: hasActiveFilters
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: hasActiveFilters ? Colors.white : const Color(0xFF334155),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hasActiveFilters ? 'Filter ($activeCount)' : 'Filter',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: hasActiveFilters ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Active Filter Badges Bar
          if (hasActiveFilters) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_selectedArus != 'Semua Arus' && _selectedArus.isNotEmpty)
                    _buildActiveBadge(
                      label: 'Arus: $_selectedArus',
                      onRemove: () {
                        setState(() => _selectedArus = 'Semua Arus');
                        _fetchData();
                      },
                    ),
                  if (_selectedCabangId != null)
                    _buildActiveBadge(
                      label: _cabangList.firstWhere(
                        (c) => c['id'] == _selectedCabangId,
                        orElse: () => {'nama_cabang': 'Cabang'},
                      )['nama_cabang'],
                      onRemove: () {
                        setState(() => _selectedCabangId = null);
                        _fetchData();
                      },
                    ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCabangId = null;
                        _selectedArus = 'Semua Arus';
                      });
                      _fetchData();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Reset Semua',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveBadge({required String label, required VoidCallback onRemove}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  // --- COMPREHENSIVE FILTER MODAL BOTTOM SHEET ---
  void _showComprehensiveFilterModal() {
    int? tempCabangId = _selectedCabangId;
    String tempArus = _selectedArus;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Filter Cashflow Cabang',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            padding: const EdgeInsets.all(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- 1. ARUS KAS FILTER ---
                        Text(
                          'ARUS KAS',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildModalArusOption(
                              label: 'Semua Arus',
                              isSelected: tempArus == 'Semua Arus',
                              color: AppColors.primary,
                              icon: Icons.all_inclusive_rounded,
                              onTap: () => setModalState(() => tempArus = 'Semua Arus'),
                            ),
                            const SizedBox(width: 8),
                            _buildModalArusOption(
                              label: 'Masuk',
                              isSelected: tempArus == 'Masuk',
                              color: const Color(0xFF16A34A),
                              icon: Icons.arrow_downward_rounded,
                              onTap: () => setModalState(() => tempArus = 'Masuk'),
                            ),
                            const SizedBox(width: 8),
                            _buildModalArusOption(
                              label: 'Keluar',
                              isSelected: tempArus == 'Keluar',
                              color: const Color(0xFFDC2626),
                              icon: Icons.arrow_upward_rounded,
                              onTap: () => setModalState(() => tempArus = 'Keluar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // --- 2. CABANG FILTER ---
                        Text(
                          'CABANG',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: tempCabangId,
                              isExpanded: true,
                              hint: Text(
                                'Semua Cabang',
                                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Semua Cabang', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                ),
                                ..._cabangList.map((cabang) {
                                  return DropdownMenuItem<int?>(
                                    value: cabang['id'],
                                    child: Text(
                                      cabang['nama_cabang'] ?? '-',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setModalState(() => tempCabangId = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                  // Bottom Action Buttons (Reset & Terapkan)
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedCabangId = null;
                                _selectedArus = 'Semua Arus';
                              });
                              Navigator.pop(context);
                              _fetchData();
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Reset Filter',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedCabangId = tempCabangId;
                                _selectedArus = tempArus;
                              });
                              Navigator.pop(context);
                              _fetchData();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Terapkan Filter',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
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

  Widget _buildModalArusOption({
    required String label,
    required bool isSelected,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: isSelected ? color : const Color(0xFF64748B)),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? color : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SUMMARY STATS OVERVIEW CARDS (MOBILE-FRIENDLY & NO SCROLL) ---
  Widget _buildSummaryStatsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Prominent Hero Dark Slate Card: Saldo Kas Sekarang (Sepanjang Waktu)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saldo Kas Sekarang (Sepanjang Waktu)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _formatCurrency(_saldoSekarang),
                style: GoogleFonts.inter(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF10B981), // Emerald Green
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(Icons.monetization_on_outlined, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 5),
                  Text(
                    'Dana aktual kas di cabang',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Row: Total Masuk & Total Keluar (Bulan Ini) - Visible side by side
        Row(
          children: [
            // Total Masuk (Bulan Ini)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF16A34A)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Total Masuk',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF166534),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatCurrency(_masukBulanIni),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF166534),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Pemasukan (Bln Ini)',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Total Keluar (Bulan Ini)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.arrow_upward_rounded, size: 14, color: Color(0xFFDC2626)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Total Keluar',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF991B1B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatCurrency(_keluarBulanIni),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF991B1B),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Pengeluaran (Bln Ini)',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 3. Full-Width Card: Pengajuan Kas (Bulan Ini) - Immediately visible without scroll
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF1D4ED8)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pengajuan Kas (Bulan Ini)',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E40AF),
                        ),
                      ),
                      Text(
                        '✓ Dana yang telah disetujui',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                _formatCurrency(_pengajuanBulanIni),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1E40AF),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- CASHFLOW ITEM CARD (MATCHING WEB TABLE FORMAT) ---
  Widget _buildCashflowCard(Map<String, dynamic> item) {
    final isMasuk = item['arus'] == 'Masuk' || item['arus']?.toString().contains('Masuk') == true;
    final nominal = _formatCurrency(item['nominal']);
    final tanggal = _formatDate(item['tanggal']);
    final cabangName = item['cabang']?['nama_cabang'] ?? '-';
    final kategori = item['kategori_kas'] ?? '-';
    final metode = item['metode'] ?? '-';
    final keterangan = item['keterangan'] ?? '';
    final buktiPath = item['bukti'];
    final bool hasBukti = buktiPath != null && buktiPath.toString().trim().isNotEmpty && buktiPath.toString() != 'null';

    final Color themeColor = isMasuk ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final Color themeBg = isMasuk ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Tanggal & Cabang (Matching Web Column 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tanggal,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 11, color: Color(0xFF2563EB)),
                          const SizedBox(width: 3),
                          Text(
                            cabangName,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Middle Row: Arus & Kategori Badge + Nominal
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Arus & Kategori
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: themeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isMasuk ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                  size: 12,
                                  color: themeColor,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isMasuk ? 'Masuk' : 'Keluar',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: themeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            kategori,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Big Nominal
                    Text(
                      nominal,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),

                // Keterangan & Metode Row (Matching Web Column 4)
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        keterangan.toString().trim().isNotEmpty && keterangan != '-'
                            ? keterangan
                            : '-',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF334155),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (metode.toString().trim().isNotEmpty && metode != '-') ...[
                        const SizedBox(height: 4),
                        Text(
                          'Via: $metode',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Bottom Dedicated Action Bar: Text + Icon Buttons (Bukti, Edit, Hapus)
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // 1. IN-APP BUKTI VIEWER (IF HAS BUKTI)
                if (hasBukti) ...[
                  Expanded(
                    child: Material(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => _viewBuktiInApp(buktiPath, '$kategori ($nominal)'),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.image_rounded, color: Color(0xFF1D4ED8), size: 15),
                              const SizedBox(width: 4),
                              Text(
                                'Bukti',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1D4ED8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // 2. EDIT BUTTON
                Expanded(
                  child: Material(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => _showFormBottomSheet(data: item),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.edit_rounded, color: Color(0xFFD97706), size: 15),
                            const SizedBox(width: 4),
                            Text(
                              'Edit',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 3. DELETE BUTTON
                Expanded(
                  child: Material(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => _deleteCashflow(item['id']),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 15),
                            const SizedBox(width: 4),
                            Text(
                              'Hapus',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak Ada Data Cashflow',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            Text(
              'Belum ada transaksi kas yang sesuai dengan filter pencarian.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// IN-APP CASHFLOW BUKTI VIEWER DIALOG
// ---------------------------------------------------------
class _CashflowFileViewerDialog extends StatelessWidget {
  final String url;
  final String title;
  final String? authToken;
  final bool isImage;

  const _CashflowFileViewerDialog({
    required this.url,
    required this.title,
    this.authToken,
    required this.isImage,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(14),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isImage)
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SmartNetworkImage(
                    url: url,
                    token: authToken,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Gagal memuat bukti cashflow',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            url,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 14),
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: url));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('URL berhasil disalin')),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Salin URL'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.description_rounded, size: 48, color: Color(0xFF1D4ED8)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bukti Transaksi Cashflow',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    url,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('URL bukti berhasil disalin')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Salin URL Bukti'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),

          // Close Button on Top Right
          Positioned(
            top: 10,
            right: 10,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// SMART NETWORK IMAGE
// ---------------------------------------------------------
class SmartNetworkImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final String? token;
  final Widget? placeholder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const SmartNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.token,
    this.placeholder,
    this.errorBuilder,
  });

  @override
  State<SmartNetworkImage> createState() => _SmartNetworkImageState();
}

class _SmartNetworkImageState extends State<SmartNetworkImage> {
  late String _activeUrl;
  bool _triedFallback = false;

  @override
  void initState() {
    super.initState();
    _activeUrl = widget.url;
  }

  @override
  void didUpdateWidget(covariant SmartNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _activeUrl = widget.url;
      _triedFallback = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeUrl.isEmpty) {
      return widget.errorBuilder?.call(context, 'Empty URL', null) ??
          const Center(child: Icon(Icons.image_not_supported_rounded, color: Color(0xFF94A3B8), size: 20));
    }

    final headers = widget.token != null && widget.token!.isNotEmpty
        ? {
            'Authorization': 'Bearer ${widget.token}',
            'Accept': 'image/*,*/*',
          }
        : const {'Accept': 'image/*,*/*'};

    return Image.network(
      _activeUrl,
      fit: widget.fit,
      headers: headers,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return widget.placeholder ??
            Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Image load error on $_activeUrl: $error');
        if (!_triedFallback) {
          _triedFallback = true;
          if (_activeUrl.startsWith('http://')) {
            final fallback = _activeUrl.replaceFirst('http://', 'https://');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _activeUrl = fallback);
            });
            return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
          } else if (_activeUrl.startsWith('https://')) {
            final fallback = _activeUrl.replaceFirst('https://', 'http://');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _activeUrl = fallback);
            });
            return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
          }
        }
        return widget.errorBuilder?.call(context, error, stackTrace) ??
            const Center(child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 20));
      },
    );
  }
}

// ---------------------------------------------------------
// MODERN BOTTOM SHEET FORM (CREATE / EDIT)
// ---------------------------------------------------------
class _FormCashflowBottomSheet extends StatefulWidget {
  final Map<String, dynamic>? data;
  final List<dynamic> cabangList;
  final VoidCallback onSaved;

  const _FormCashflowBottomSheet({
    this.data,
    required this.cabangList,
    required this.onSaved,
  });

  @override
  State<_FormCashflowBottomSheet> createState() => _FormCashflowBottomSheetState();
}

class _FormCashflowBottomSheetState extends State<_FormCashflowBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final TextEditingController _tanggalController = TextEditingController();
  final TextEditingController _kategoriController = TextEditingController();
  final TextEditingController _nominalController = TextEditingController();
  final TextEditingController _metodeController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();

  int? _selectedCabangId;
  String _selectedArus = 'Masuk';
  File? _selectedFile;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    if (widget.data != null) {
      _tanggalController.text = widget.data!['tanggal'] ?? '';
      _selectedCabangId = widget.data!['cabang_id'];

      String arusData = widget.data!['arus'] ?? '';
      if (arusData.contains('Keluar')) {
        _selectedArus = 'Keluar';
      } else {
        _selectedArus = 'Masuk';
      }

      _kategoriController.text = widget.data!['kategori_kas'] ?? '';

      double nom = double.tryParse(widget.data!['nominal']?.toString() ?? '0') ?? 0;
      final format = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
      _nominalController.text = format.format(nom);

      _metodeController.text = widget.data!['metode'] ?? '';
      _keteranganController.text = widget.data!['keterangan'] ?? '';

      if (widget.data!['bukti'] != null) {
        _fileName = widget.data!['bukti'].toString().split('/').last;
      }
    } else {
      _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (widget.cabangList.isNotEmpty) {
        _selectedCabangId = widget.cabangList.first['id'];
      }
    }
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _kategoriController.dispose();
    _nominalController.dispose();
    _metodeController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime initialDate = DateTime.now();
    if (_tanggalController.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(_tanggalController.text);
      } catch (_) {}
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _tanggalController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _fileName = result.files.single.name;
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCabangId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cabang harus dipilih')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      String nominalClean = _nominalController.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (nominalClean.isEmpty) nominalClean = '0';

      final data = {
        'tanggal': _tanggalController.text,
        'cabang_id': _selectedCabangId.toString(),
        'arus': _selectedArus,
        'kategori_kas': _kategoriController.text,
        'nominal': nominalClean,
        'metode': _metodeController.text,
        'keterangan': _keteranganController.text,
      };

      if (widget.data == null) {
        await OperasionalCashflowCabangService.createCashflow(data, file: _selectedFile);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data cashflow berhasil ditambahkan')));
        }
      } else {
        await OperasionalCashflowCabangService.updateCashflow(widget.data!['id'], data, file: _selectedFile);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data cashflow berhasil diperbarui')));
        }
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      debugPrint('Error saving cashflow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan data')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(3)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.data == null ? 'Tambah Cashflow Cabang' : 'Edit Cashflow Cabang',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Title
                    Text('TRANSAKSI', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
                    const Divider(color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),

                    // 1. Tanggal & Cabang
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tanggal *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () => _selectDate(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _tanggalController.text.isNotEmpty ? _tanggalController.text : 'Pilih Tanggal',
                                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                                      ),
                                      const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Cabang *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _selectedCabangId,
                                    isExpanded: true,
                                    hint: Text('Pilih Cabang', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B)),
                                    items: widget.cabangList.map((c) {
                                      return DropdownMenuItem<int>(
                                        value: c['id'],
                                        child: Text(c['nama_cabang'] ?? '-'),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedCabangId = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 2. Arus Dropdown & Kategori Kas
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Arus *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedArus,
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                                    items: const [
                                      DropdownMenuItem(value: 'Masuk', child: Text('Masuk (Pemasukan Kas)')),
                                      DropdownMenuItem(value: 'Keluar', child: Text('Keluar (Pengeluaran Kas)')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedArus = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFormInput(
                            label: 'Kategori Kas',
                            controller: _kategoriController,
                            hint: 'mis. Biaya Operasional',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3. Nominal & Metode
                    Row(
                      children: [
                        Expanded(
                          child: _buildFormInput(
                            label: 'Nominal *',
                            controller: _nominalController,
                            hint: 'Rp',
                            keyboardType: TextInputType.number,
                            inputFormatters: [CurrencyInputFormatter()],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFormInput(
                            label: 'Metode',
                            controller: _metodeController,
                            hint: 'mis. Cash, Transfer Bank',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 4. Keterangan
                    _buildFormInput(
                      label: 'Keterangan',
                      controller: _keteranganController,
                      hint: 'Tambahkan catatan jika diperlukan...',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // 5. Bukti
                    Text('Bukti', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickFile,
                          icon: const Icon(Icons.attach_file_rounded, size: 16),
                          label: const Text('Pilih Berkas'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _fileName != null ? _fileName! : (widget.data?['bukti'] != null ? 'Bukti tersimpan' : 'Belum ada berkas'),
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Submit Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -3))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Batal', style: GoogleFonts.inter(color: const Color(0xFF334155), fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Simpan Data', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormInput({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    bool isRequired = label.contains('*');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: isRequired ? (val) => val == null || val.trim().isEmpty ? 'Wajib diisi' : null : null,
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8), fontWeight: FontWeight.normal),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// CURRENCY INPUT FORMATTER
// ---------------------------------------------------------
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }
    String cleanStr = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanStr.isEmpty) cleanStr = '0';
    double value = double.parse(cleanStr);
    final formatter = NumberFormat.currency(
        locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    String newText = formatter.format(value);
    return newValue.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length));
  }
}
