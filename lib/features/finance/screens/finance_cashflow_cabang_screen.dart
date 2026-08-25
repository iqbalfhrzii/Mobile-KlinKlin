import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/app_confirmation_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../uang_kas/services/uang_kas_service.dart';

class FinanceCashflowCabangScreen extends StatefulWidget {
  const FinanceCashflowCabangScreen({super.key});

  @override
  State<FinanceCashflowCabangScreen> createState() => _FinanceCashflowCabangScreenState();
}

class _FinanceCashflowCabangScreenState extends State<FinanceCashflowCabangScreen> {
  final _service = UangKasService();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  String _error = '';

  List<dynamic> _cashflows = [];
  List<dynamic> _cabangs = [];
  Map<String, dynamic> _summary = {
    'total_masuk_bulan_ini': 0.0,
    'total_keluar_bulan_ini': 0.0,
    'pengajuan_kas_bulan_ini': 0.0,
    'saldo_kas_sekarang': 0.0,
  };

  int? _selectedCabangId;
  String _selectedArus = 'Semua Arus';
  final List<String> _arusOptions = ['Semua Arus', 'Masuk', 'Keluar'];

  @override
  void initState() {
    super.initState();
    _loadCabangs();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCabangs() async {
    try {
      final list = await _service.getCabangs();
      if (mounted) {
        setState(() => _cabangs = list);
      }
    } catch (_) {}
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final res = await _service.getCashflow(
        search: _searchController.text.trim(),
        cabangId: _selectedCabangId,
        arus: _selectedArus == 'Semua Arus' ? null : _selectedArus,
      );

      if (mounted) {
        setState(() {
          _cashflows = res['data'] is List ? res['data'] : (res['data']?['data'] ?? []);
          if (res['summary'] != null && res['summary'] is Map) {
            _summary = Map<String, dynamic>.from(res['summary']);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatRp(num val) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(val);
  }

  void _showFormModal({dynamic item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CashflowFormModal(
        item: item,
        cabangs: _cabangs,
        onSaved: () {
          _fetchData();
        },
      ),
    );
  }

  Future<void> _confirmDelete(dynamic item) async {
    final confirmed = await AppConfirmationDialog.show(
      context,
      type: ConfirmationDialogType.danger,
      title: 'Hapus Data Cashflow',
      message: 'Apakah Anda yakin ingin menghapus data cashflow sebesar ${_formatRp(num.tryParse(item['nominal'].toString()) ?? 0)}?',
      confirmText: 'Ya, Hapus',
      cancelText: 'Batal',
    );

    if (confirmed == true) {
      try {
        final id = int.tryParse(item['id'].toString()) ?? 0;
        await _service.deleteCashflow(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Data cashflow berhasil dihapus'),
              backgroundColor: Color(0xFF059669),
            ),
          );
          _fetchData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Gagal menghapus: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  void _showBuktiDialog(String rawUrl) {
    String fullUrl = rawUrl;
    if (!fullUrl.startsWith('http')) {
      final baseUrl = ApiClient.baseUrl.replaceAll('/api', '');
      fullUrl = '$baseUrl/$rawUrl'.replaceAll(RegExp(r'(?<!:)/+'), '/');
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bukti Transaksi', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              child: Image.network(
                fullUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text('Gagal memuat gambar bukti', style: GoogleFonts.inter(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 18),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monitoring Cashflow',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kas masuk & keluar seluruh cabang',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _showFormModal(),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_rounded, size: 16, color: Color(0xFF0F52BA)),
                  const SizedBox(width: 4),
                  Text(
                    'Tambah Data',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F52BA),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  // 4 Summary KPI Cards
                  _buildSummaryGrid(),
                  const SizedBox(height: 14),

            // Filters Section
            _buildFilterSection(),
            const SizedBox(height: 16),

            // List Header & Total Count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Riwayat Transaksi',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_cashflows.length} Data',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Content List / Loading / Empty
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_error.isNotEmpty)
              _buildErrorCard()
            else if (_cashflows.isEmpty)
              _buildEmptyCard()
            else
              ..._cashflows.map((item) => _buildCashflowCard(item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid() {
    final masuk = num.tryParse(_summary['total_masuk_bulan_ini']?.toString() ?? '0') ?? 0;
    final keluar = num.tryParse(_summary['total_keluar_bulan_ini']?.toString() ?? '0') ?? 0;
    final pengajuan = num.tryParse(_summary['pengajuan_kas_bulan_ini']?.toString() ?? '0') ?? 0;
    final saldo = num.tryParse(_summary['saldo_kas_sekarang']?.toString() ?? '0') ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Total Masuk (Bulan Ini)',
                value: _formatRp(masuk),
                subtitle: 'Pemasukan cabang',
                icon: Icons.arrow_downward_rounded,
                iconColor: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryCard(
                title: 'Total Keluar (Bulan Ini)',
                value: _formatRp(keluar),
                subtitle: 'Pengeluaran cabang',
                icon: Icons.arrow_upward_rounded,
                iconColor: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEF2F2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Pengajuan Kas (Bulan Ini)',
                value: _formatRp(pengajuan),
                subtitle: 'Dana yang disetujui',
                icon: Icons.check_circle_outline_rounded,
                iconColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saldo Kas Sekarang',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatRp(saldo),
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF34D399)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, size: 10, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Dana aktual cabang',
                            style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF94A3B8)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                child: Icon(icon, size: 12, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF94A3B8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Search Field
          TextField(
            controller: _searchController,
            onSubmitted: (_) => _fetchData(),
            style: GoogleFonts.inter(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Cari keterangan atau kategori...',
              hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        _fetchData();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0F52BA))),
            ),
          ),
          const SizedBox(height: 10),

          // Dropdowns (Cabang & Arus)
          Row(
            children: [
              // Dropdown Cabang
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _selectedCabangId,
                      isExpanded: true,
                      hint: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 11)),
                        ),
                        ..._cabangs.map((c) {
                          return DropdownMenuItem<int?>(
                            value: int.tryParse(c['id'].toString()),
                            child: Text(c['nama_cabang'] ?? '-', style: GoogleFonts.inter(fontSize: 11)),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedCabangId = val);
                        _fetchData();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Dropdown Arus
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedArus,
                      isExpanded: true,
                      items: _arusOptions.map((a) {
                        return DropdownMenuItem<String>(
                          value: a,
                          child: Text(a, style: GoogleFonts.inter(fontSize: 11)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedArus = val);
                          _fetchData();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCashflowCard(dynamic item) {
    final isMasuk = (item['arus'] ?? 'Masuk').toString().toLowerCase().contains('masuk');
    final nominal = num.tryParse(item['nominal']?.toString() ?? '0') ?? 0;
    final cabangName = item['cabang']?['nama_cabang'] ?? '-';
    final kategori = item['kategori_kas']?.toString() ?? '-';
    final keterangan = item['keterangan']?.toString() ?? '-';
    final metode = item['metode']?.toString() ?? 'cash';
    final bukti = item['bukti']?.toString();

    DateTime? tanggal;
    if (item['tanggal'] != null) {
      try {
        tanggal = DateTime.parse(item['tanggal'].toString());
      } catch (_) {}
    }
    final tglStr = tanggal != null ? DateFormat('dd MMM yyyy', 'id_ID').format(tanggal) : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Tanggal & Cabang + Arus Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    tglStr,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  Text(
                    ' • $cabangName',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isMasuk ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isMasuk ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isMasuk ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      size: 10,
                      color: isMasuk ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isMasuk ? 'Masuk' : 'Keluar',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isMasuk ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Nominal & Kategori
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatRp(nominal),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isMasuk ? const Color(0xFF059669) : const Color(0xFFDC2626),
                ),
              ),
              if (kategori.isNotEmpty && kategori != '-')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    kategori,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Keterangan & Metode
          Text(
            keterangan.isEmpty || keterangan == '-' ? '(Tanpa keterangan)' : keterangan,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155)),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Text(
                'Via: $metode',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
              if (bukti != null && bukti.isNotEmpty && bukti != 'null') ...[
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => _showBuktiDialog(bukti),
                  child: Row(
                    children: [
                      const Icon(Icons.attachment_rounded, size: 13, color: Color(0xFF059669)),
                      const SizedBox(width: 2),
                      Text(
                        'Lihat Bukti',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF059669),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Actions (Edit & Hapus)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showFormModal(item: item),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Text(
                          'Edit',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => _confirmDelete(item),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                        const SizedBox(width: 6),
                        Text(
                          'Hapus',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              'Belum Ada Data Cashflow',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              'Tidak ditemukan transaksi cashflow sesuai filter',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 36, color: Color(0xFFDC2626)),
          const SizedBox(height: 8),
          Text(
            'Gagal Memuat Data',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
          ),
          const SizedBox(height: 4),
          Text(_error, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF7F1D1D)), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ======================= MODAL FORM TAMBAH / EDIT CASHFLOW =======================
class _CashflowFormModal extends StatefulWidget {
  final dynamic item;
  final List<dynamic> cabangs;
  final VoidCallback onSaved;

  const _CashflowFormModal({
    this.item,
    required this.cabangs,
    required this.onSaved,
  });

  @override
  State<_CashflowFormModal> createState() => _CashflowFormModalState();
}

class _CashflowFormModalState extends State<_CashflowFormModal> {
  final _service = UangKasService();
  final _picker = ImagePicker();

  bool _isSaving = false;
  final _tanggalController = TextEditingController();
  final _nominalController = TextEditingController();
  final _keteranganController = TextEditingController();

  int? _selectedCabangId;
  String _arus = 'Masuk';
  String _metode = 'cash';
  String? _selectedKategori;
  File? _fileBukti;
  String? _existingBuktiUrl;

  final List<String> _kategoriOptions = [
    'Chemical',
    'Alat',
    'Operasional',
    'Pengajuan Uang Kas',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      final i = widget.item;
      _tanggalController.text = i['tanggal'] != null
          ? DateFormat('yyyy-MM-dd').format(DateTime.parse(i['tanggal'].toString()))
          : DateFormat('yyyy-MM-dd').format(DateTime.now());
      _selectedCabangId = int.tryParse(i['cabang_id']?.toString() ?? '');
      _arus = (i['arus'] ?? 'Masuk').toString().toLowerCase().contains('keluar') ? 'Keluar' : 'Masuk';
      final kat = i['kategori_kas']?.toString();
      if (kat != null && kat.isNotEmpty && kat != '-' && kat != 'null') {
        _selectedKategori = kat;
        if (!_kategoriOptions.contains(kat)) _kategoriOptions.add(kat);
      }
      _nominalController.text = (i['nominal'] ?? '').toString();
      _metode = (i['metode'] ?? 'cash').toString().toLowerCase().contains('transfer') ? 'transfer' : 'cash';
      _keteranganController.text = i['keterangan'] ?? '';
      _existingBuktiUrl = i['bukti']?.toString();
    } else {
      _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (widget.cabangs.isNotEmpty) {
        _selectedCabangId = int.tryParse(widget.cabangs.first['id'].toString());
      }
    }
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _nominalController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _fileBukti = File(picked.path));
    }
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime.now();
    try {
      if (_tanggalController.text.isNotEmpty) {
        initial = DateTime.parse(_tanggalController.text);
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _tanggalController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (_tanggalController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tanggal wajib diisi')));
      return;
    }
    if (_selectedCabangId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cabang wajib dipilih')));
      return;
    }
    final nominal = double.tryParse(_nominalController.text.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (nominal == null || nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nominal harus lebih besar dari 0')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final data = {
        'tanggal': _tanggalController.text,
        'cabang_id': _selectedCabangId,
        'arus': _arus,
        'kategori_kas': _selectedKategori ?? '',
        'nominal': nominal,
        'metode': _metode,
        'keterangan': _keteranganController.text.trim(),
      };

      if (widget.item != null) {
        final id = int.tryParse(widget.item['id'].toString()) ?? 0;
        await _service.updateCashflow(id, data, file: _fileBukti);
      } else {
        await _service.createCashflow(data, file: _fileBukti);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.item != null ? '✅ Data cashflow berhasil diperbarui' : '✅ Data cashflow berhasil ditambahkan'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Gagal menyimpan: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEdit ? 'Edit Data Cashflow Cabang' : 'Tambah Data Cashflow Cabang',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),

            // Tanggal & Cabang
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tanggal *', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _tanggalController.text.isEmpty ? 'Pilih Tanggal' : _tanggalController.text,
                                style: GoogleFonts.inter(fontSize: 12),
                              ),
                              const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cabang *', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _selectedCabangId,
                            isExpanded: true,
                            hint: Text('Pilih Cabang', style: GoogleFonts.inter(fontSize: 12)),
                            items: widget.cabangs.map((c) {
                              return DropdownMenuItem<int?>(
                                value: int.tryParse(c['id'].toString()),
                                child: Text(c['nama_cabang'] ?? '-', style: GoogleFonts.inter(fontSize: 12)),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() => _selectedCabangId = v),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Arus & Kategori
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Arus *', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _arus,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'Masuk', child: Text('Masuk (Pemasukan Kas)', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'Keluar', child: Text('Keluar (Pengeluaran Kas)', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (v) => setState(() => _arus = v ?? 'Masuk'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kategori Kas', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedKategori,
                            isExpanded: true,
                            hint: Text('Pilih Kategori (Opsional)', style: GoogleFonts.inter(fontSize: 12)),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Pilih Kategori (Opsional)', style: TextStyle(fontSize: 12))),
                              ..._kategoriOptions.map((k) => DropdownMenuItem<String?>(value: k, child: Text(k, style: const TextStyle(fontSize: 12)))),
                            ],
                            onChanged: (v) => setState(() => _selectedKategori = v),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Nominal & Metode
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nominal (Rp) *', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nominalController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Contoh: 50000',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Metode', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _metode,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'cash', child: Text('cash', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'transfer', child: Text('transfer', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (v) => setState(() => _metode = v ?? 'cash'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Keterangan
            Text('Keterangan', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _keteranganController,
              maxLines: 2,
              style: GoogleFonts.inter(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Keterangan transaksi...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),

            // Bukti Upload
            Text('Bukti Transaksi', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.camera_alt_outlined, size: 16),
              label: Text(_fileBukti != null ? 'Ganti Foto Bukti' : 'Upload Bukti Foto'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (_fileBukti != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('✅ File terpilih: ${_fileBukti!.path.split('/').last.split('\\').last}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF059669))),
              ),
            const SizedBox(height: 20),

            // Submit Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F52BA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Simpan Data'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
