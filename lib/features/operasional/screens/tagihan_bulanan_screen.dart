import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/api/api_client.dart';
import '../services/operasional_tagihan_service.dart';
import 'tagihan_bulanan_form_screen.dart';

class TagihanBulananScreen extends StatefulWidget {
  const TagihanBulananScreen({super.key});

  @override
  State<TagihanBulananScreen> createState() => _TagihanBulananScreenState();
}

class _TagihanBulananScreenState extends State<TagihanBulananScreen> {
  bool _isLoading = false;
  List<dynamic> _tagihans = [];
  List<dynamic> _cabangs = [];

  int? _selectedCabangId;
  DateTime? _selectedPeriode;
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadCabangs();
    _loadData();
  }

  Future<void> _loadCabangs() async {
    try {
      final cabangs = await OperasionalTagihanService.getCabangs();
      if (mounted) {
        setState(() {
          _cabangs = cabangs;
        });
      }
    } catch (e) {
      debugPrint('Error loading cabangs: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await OperasionalTagihanService.getTagihanBulanan(
        cabangId: _selectedCabangId,
        periode: _selectedPeriode != null ? DateFormat('yyyy-MM-dd').format(_selectedPeriode!) : null,
        statusBayar: _selectedStatus,
      );
      if (mounted) {
        setState(() {
          _tagihans = data;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data tagihan: $e'),
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

  // Helper Stats Calculation
  double get _totalNominal => _tagihans.fold(
      0.0, (sum, item) => sum + (double.tryParse(item['nominal']?.toString() ?? '0') ?? 0.0));
  
  double get _totalLunasNominal => _tagihans.where((item) => item['status_bayar'] == 'Lunas').fold(
      0.0, (sum, item) => sum + (double.tryParse(item['nominal']?.toString() ?? '0') ?? 0.0));

  double get _totalBelumBayarNominal => _tagihans.where((item) => item['status_bayar'] != 'Lunas').fold(
      0.0, (sum, item) => sum + (double.tryParse(item['nominal']?.toString() ?? '0') ?? 0.0));

  int get _countLunas => _tagihans.where((item) => item['status_bayar'] == 'Lunas').length;
  int get _countBelumBayar => _tagihans.where((item) => item['status_bayar'] != 'Lunas').length;

  String _formatCurrency(double value) {
    final formatter = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(value);
  }

  // Category Icon & Color Mapping
  Map<String, dynamic> _getCategoryStyle(String? jenis) {
    switch (jenis?.toLowerCase()) {
      case 'sewa':
        return {
          'icon': Icons.home_work_rounded,
          'color': const Color(0xFF7C3AED),
          'bg': const Color(0xFFF5F3FF),
        };
      case 'listrik':
        return {
          'icon': Icons.bolt_rounded,
          'color': const Color(0xFFD97706),
          'bg': const Color(0xFFFFFBEB),
        };
      case 'air':
        return {
          'icon': Icons.water_drop_rounded,
          'color': const Color(0xFF0284C7),
          'bg': const Color(0xFFF0F9FF),
        };
      case 'internet':
        return {
          'icon': Icons.wifi_rounded,
          'color': const Color(0xFF0D9488),
          'bg': const Color(0xFFF0FDFA),
        };
      case 'telepon':
        return {
          'icon': Icons.phone_in_talk_rounded,
          'color': const Color(0xFF059669),
          'bg': const Color(0xFFECFDF5),
        };
      case 'kebersihan':
        return {
          'icon': Icons.cleaning_services_rounded,
          'color': const Color(0xFFEA580C),
          'bg': const Color(0xFFFFF7ED),
        };
      case 'keamanan':
        return {
          'icon': Icons.security_rounded,
          'color': const Color(0xFF475569),
          'bg': const Color(0xFFF8FAFC),
        };
      case 'pajak':
        return {
          'icon': Icons.account_balance_rounded,
          'color': const Color(0xFFDC2626),
          'bg': const Color(0xFFFEF2F2),
        };
      default:
        return {
          'icon': Icons.receipt_long_rounded,
          'color': AppColors.primary,
          'bg': AppColors.surfaceBlue,
        };
    }
  }

  String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final baseDomain = ApiClient.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    if (cleanPath.startsWith('storage/')) {
      return '$baseDomain/$cleanPath';
    }
    return '$baseDomain/storage/$cleanPath';
  }

  @override
  Widget build(BuildContext context) {
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
                            'Data Tagihan Bulanan',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kelola & pantau tagihan operasional cabang',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${_tagihans.length}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
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

                    const SizedBox(height: 12),

                    // Filter Card
                    _buildFilterCard(),

                    const SizedBox(height: 14),

                    // List Header Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Daftar Tagihan',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          if (_tagihans.isNotEmpty)
                            Text(
                              'Total: ${_formatCurrency(_totalNominal)}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),

                    // List Content
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    else if (_tagihans.isEmpty)
                      _buildEmptyState()
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: _tagihans
                              .map((item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _buildTagihanCard(item),
                                  ))
                              .toList(),
                        ),
                      ),
                    
                    const SizedBox(height: 80), // Space for FAB
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
            MaterialPageRoute(builder: (context) => const TagihanBulananFormScreen()),
          );
          if (result == true) {
            _loadData();
          }
        },
        backgroundColor: AppColors.primary,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: Text(
          'Tambah Tagihan',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Main Card: Total Tagihan (Full Width Hero)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Tagihan',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(_totalNominal),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${_tagihans.length} Data',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Sub 2-Columns: Sudah Lunas & Belum Bayar
          Row(
            children: [
              // Sudah Lunas Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669).withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
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
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_countLunas Lunas',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Sudah Lunas',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(_totalLunasNominal),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Belum Bayar Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97706).withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
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
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.pending_actions_rounded, color: Color(0xFFD97706), size: 16),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_countBelumBayar Belum',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Belum Bayar',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(_totalBelumBayarNominal),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- FILTER CARD ---
  Widget _buildFilterCard() {
    final bool hasFilter = _selectedCabangId != null || _selectedPeriode != null || _selectedStatus != 'all';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Filter & Pencarian',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              if (hasFilter)
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCabangId = null;
                      _selectedPeriode = null;
                      _selectedStatus = 'all';
                    });
                    _loadData();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      'Reset Filter',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Cabang Filter
              Expanded(
                child: _buildModernDropdown(
                  icon: Icons.storefront_rounded,
                  hint: 'Semua Cabang',
                  value: _selectedCabangId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua Cabang')),
                    ..._cabangs.map((c) => DropdownMenuItem(
                          value: c['id'],
                          child: Text(c['nama_cabang'] ?? '-'),
                        ))
                  ],
                  onChanged: (val) {
                    setState(() => _selectedCabangId = val as int?);
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Status Filter
              Expanded(
                child: _buildModernDropdown(
                  icon: Icons.check_circle_outline_rounded,
                  hint: 'Semua Status',
                  value: _selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Semua Status')),
                    DropdownMenuItem(value: 'Belum Bayar', child: Text('Belum Bayar')),
                    DropdownMenuItem(value: 'Lunas', child: Text('Lunas')),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedStatus = val as String);
                    _loadData();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Periode Filter Picker
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedPeriode ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                helpText: 'PILIH PERIODE BULAN',
              );
              if (picked != null) {
                setState(() => _selectedPeriode = picked);
                _loadData();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedPeriode != null ? AppColors.primary : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: _selectedPeriode != null ? AppColors.primary : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedPeriode != null
                          ? DateFormat('MMMM yyyy').format(_selectedPeriode!)
                          : 'Pilih Periode Bulan & Tahun',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: _selectedPeriode != null ? FontWeight.w600 : FontWeight.w400,
                        color: _selectedPeriode != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  if (_selectedPeriode != null)
                    GestureDetector(
                      onTap: () {
                        setState(() => _selectedPeriode = null);
                        _loadData();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, size: 14, color: Colors.red.shade600),
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

  Widget _buildModernDropdown({
    required IconData icon,
    required String hint,
    required dynamic value,
    required List<DropdownMenuItem<dynamic>> items,
    required Function(dynamic) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
          hint: Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hint,
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  // --- CARD ITEM ---
  Widget _buildTagihanCard(dynamic item) {
    final periodeDate = DateTime.tryParse(item['periode'] ?? '');
    final periode = periodeDate != null ? DateFormat('MMMM yyyy').format(periodeDate) : '-';

    final jatuhTempoDate = DateTime.tryParse(item['jatuh_tempo'] ?? '');
    final jatuhTempo = jatuhTempoDate != null ? DateFormat('dd MMM yyyy').format(jatuhTempoDate) : null;

    final isLunas = item['status_bayar'] == 'Lunas';
    final cabang = item['cabang'] != null ? item['cabang']['nama_cabang'] : '-';

    final formatter = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final nominal = formatter.format(double.tryParse(item['nominal']?.toString() ?? '0') ?? 0);

    final catStyle = _getCategoryStyle(item['jenis_tagihan']);
    final hasBukti = item['bukti_bayar'] != null && item['bukti_bayar'].toString().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLunas ? const Color(0xFFE2E8F0) : const Color(0xFFFDE68A),
          width: isLunas ? 1 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isLunas ? Colors.black.withValues(alpha: 0.03) : const Color(0xFFF59E0B).withValues(alpha: 0.06),
            blurRadius: 12,
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
                // Header Tags Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Periode & Cabang Badges
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_month_rounded, size: 12, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  periode,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.storefront_rounded, size: 12, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  cabang,
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
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isLunas ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isLunas ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isLunas ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item['status_bayar'] ?? '-',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isLunas ? const Color(0xFF15803D) : const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Main Info Row
                Row(
                  children: [
                    // Category Icon Container
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: catStyle['bg'] as Color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: (catStyle['color'] as Color).withValues(alpha: 0.2)),
                      ),
                      child: Icon(catStyle['icon'] as IconData, color: catStyle['color'] as Color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    // Title & Nominal
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['jenis_tagihan']?.toString().toUpperCase() ?? 'TAGIHAN',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            nominal,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isLunas ? const Color(0xFF059669) : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
                const SizedBox(height: 10),

                // Bottom Meta & Action Buttons
                Row(
                  children: [
                    // Jatuh tempo / Bukti indicator
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          if (jatuhTempo != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.event_outlined,
                                  size: 13,
                                  color: isLunas ? const Color(0xFF64748B) : const Color(0xFFEA580C),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Tempo: $jatuhTempo',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: isLunas ? FontWeight.w500 : FontWeight.w600,
                                    color: isLunas ? const Color(0xFF64748B) : const Color(0xFFEA580C),
                                  ),
                                ),
                              ],
                            ),
                          if (hasBukti)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.attach_file_rounded, size: 12, color: Color(0xFF2563EB)),
                                  Text(
                                    'Bukti',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Actions: Detail, Edit, Delete
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit Action
                        InkWell(
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => TagihanBulananFormScreen(tagihan: item)),
                            );
                            if (result == true) _loadData();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF475569)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Delete Action
                        InkWell(
                          onTap: () => _confirmDelete(item),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red.shade600),
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

  // --- DETAIL BOTTOM SHEET ---
  void _showDetailSheet(dynamic item) {
    final periodeDate = DateTime.tryParse(item['periode'] ?? '');
    final periode = periodeDate != null ? DateFormat('MMMM yyyy').format(periodeDate) : '-';

    final jatuhTempoDate = DateTime.tryParse(item['jatuh_tempo'] ?? '');
    final jatuhTempo = jatuhTempoDate != null ? DateFormat('dd MMMM yyyy').format(jatuhTempoDate) : '-';

    final tanggalBayarDate = DateTime.tryParse(item['tanggal_bayar'] ?? '');
    final tanggalBayar = tanggalBayarDate != null ? DateFormat('dd MMMM yyyy').format(tanggalBayarDate) : '-';

    final isLunas = item['status_bayar'] == 'Lunas';
    final cabang = item['cabang'] != null ? item['cabang']['nama_cabang'] : '-';

    final formatter = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final nominal = formatter.format(double.tryParse(item['nominal']?.toString() ?? '0') ?? 0);
    final nominalDibayar = item['nominal_dibayar'] != null
        ? formatter.format(double.tryParse(item['nominal_dibayar']?.toString() ?? '0') ?? 0)
        : '-';

    final catStyle = _getCategoryStyle(item['jenis_tagihan']);
    final buktiUrl = _getImageUrl(item['bukti_bayar_url'] ?? item['bukti_bayar']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Top Handle Bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Modal Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: catStyle['bg'] as Color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(catStyle['icon'] as IconData, color: catStyle['color'] as Color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detail Tagihan Bulanan',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          item['jenis_tagihan']?.toString().toUpperCase() ?? 'TAGIHAN',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            const Divider(color: Color(0xFFF1F5F9), height: 1),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Highlight Nominal Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isLunas
                              ? [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)]
                              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isLunas ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TOTAL TAGIHAN',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isLunas ? const Color(0xFF047857) : const Color(0xFF1D4ED8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isLunas ? const Color(0xFF059669) : const Color(0xFFD97706),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  item['status_bayar'] ?? '-',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            nominal,
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: isLunas ? const Color(0xFF065F46) : const Color(0xFF1E3A8A),
                            ),
                          ),
                          if (isLunas && nominalDibayar != '-') ...[
                            const SizedBox(height: 4),
                            Text(
                              'Nominal Dibayar: $nominalDibayar',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF047857),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Information Grid
                    Text(
                      'Informasi Tagihan',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildDetailRow(Icons.storefront_rounded, 'Cabang Operasional', cabang),
                    _buildDetailRow(Icons.calendar_month_rounded, 'Periode Tagihan', periode),
                    _buildDetailRow(Icons.category_rounded, 'Kategori / Jenis', item['jenis_tagihan']?.toString().toUpperCase() ?? '-'),
                    _buildDetailRow(Icons.event_outlined, 'Jatuh Tempo', jatuhTempo),
                    
                    if (isLunas)
                      _buildDetailRow(Icons.check_circle_outline_rounded, 'Tanggal Pelunasan', tanggalBayar),

                    if (item['keterangan'] != null && item['keterangan'].toString().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Keterangan / Catatan',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          item['keterangan'].toString(),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF475569),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],

                    // Bukti Bayar Preview
                    if (buktiUrl.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Bukti Pembayaran',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () => _showFullImage(buktiUrl),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              buktiUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 36),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Gagal memuat gambar',
                                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmDelete(item);
                      },
                      icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600, size: 18),
                      label: Text(
                        'Hapus',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.red.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => TagihanBulananFormScreen(tagihan: item)),
                        );
                        if (result == true) _loadData();
                      },
                      icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                      label: Text(
                        'Edit Tagihan',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
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

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(dynamic item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus Tagihan',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus data tagihan ini secara permanen?',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Hapus',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await OperasionalTagihanService.deleteTagihan(item['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tagihan berhasil dihapus'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Data Tagihan',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Gunakan tombol di bawah untuk menambahkan tagihan operasional baru.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
