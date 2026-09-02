import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../uang_kas/services/uang_kas_service.dart';

class FinanceApprovalKasScreen extends StatefulWidget {
  const FinanceApprovalKasScreen({super.key});

  @override
  State<FinanceApprovalKasScreen> createState() => _FinanceApprovalKasScreenState();
}

class _FinanceApprovalKasScreenState extends State<FinanceApprovalKasScreen> {
  final _service = UangKasService();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  String _error = '';

  List<dynamic> _pengajuans = [];
  List<dynamic> _cabangs = [];

  int? _selectedCabangId;
  String _selectedStatus = 'Semua Status';
  final List<String> _statusOptions = ['Semua Status', 'Pending', 'Disetujui', 'Ditolak'];

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
      final res = await _service.getPengajuanKas(
        search: _searchController.text.trim(),
        cabangId: _selectedCabangId,
        status: _selectedStatus == 'Semua Status' ? null : _selectedStatus,
      );

      if (mounted) {
        setState(() {
          _pengajuans = res['data'] is List ? res['data'] : [];
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

  void _showProcessModal(dynamic item) {
    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ApprovalKasProcessModal(
        item: item,
        onProcessed: () {
          _fetchData();
        },
      ),
    );
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
                  Text('Bukti Transfer Kas', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
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
                        Text('Gagal memuat gambar bukti transfer', style: GoogleFonts.inter(color: Colors.grey)),
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
    final pendingCount = _pengajuans.where((p) => (p['status'] ?? '').toString().toLowerCase() == 'pending').length;

    return GradientHeader(
      padding: EdgeInsets.fromLTRB(16, 50, 16, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 14 : 18),
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
                  'Approval Kas',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Persetujuan pengajuan kas CS cabang',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          if (pendingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(12),
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
                  const Icon(Icons.pending_actions_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$pendingCount Pending',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
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
                  // Filters Section
                  _buildFilterSection(),
                  const SizedBox(height: 14),

            // List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daftar Pengajuan Kas',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_pengajuans.length} Data',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Content List
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_error.isNotEmpty)
              _buildErrorCard()
            else if (_pengajuans.isEmpty)
              _buildEmptyCard()
            else
              ..._pengajuans.map((item) => _buildPengajuanCard(item)),
                ],
              ),
            ),
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
              hintText: 'Cari keterangan pengajuan...',
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

          // Dropdowns (Cabang & Status)
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

              // Dropdown Status
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
                      value: _selectedStatus,
                      isExpanded: true,
                      items: _statusOptions.map((s) {
                        return DropdownMenuItem<String>(
                          value: s,
                          child: Text(s, style: GoogleFonts.inter(fontSize: 11)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedStatus = val);
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

  Widget _buildPengajuanCard(dynamic item) {
    final status = (item['status'] ?? 'pending').toString().toLowerCase();
    final nominal = num.tryParse(item['nominal']?.toString() ?? '0') ?? 0;
    final cabangName = item['cabang']?['nama_cabang'] ?? '-';
    final keterangan = item['keterangan']?.toString() ?? '-';
    final buktiTransfer = item['bukti_transfer']?.toString();

    DateTime? tanggal;
    if (item['tanggal'] != null) {
      try {
        tanggal = DateTime.parse(item['tanggal'].toString());
      } catch (_) {}
    }
    final tglStr = tanggal != null ? DateFormat('dd MMM yyyy', 'id_ID').format(tanggal) : '-';

    Color statusBg;
    Color statusBorder;
    Color statusColor;
    String statusLabel;

    if (status == 'disetujui') {
      statusBg = const Color(0xFFECFDF5);
      statusBorder = const Color(0xFFA7F3D0);
      statusColor = const Color(0xFF059669);
      statusLabel = 'Disetujui';
    } else if (status == 'ditolak') {
      statusBg = const Color(0xFFFEF2F2);
      statusBorder = const Color(0xFFFECACA);
      statusColor = const Color(0xFFDC2626);
      statusLabel = 'Ditolak';
    } else {
      statusBg = const Color(0xFFFFFBEB);
      statusBorder = const Color(0xFFFDE68A);
      statusColor = const Color(0xFFD97706);
      statusLabel = 'Pending';
    }

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
          // Header: Cabang & Tanggal + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.storefront_rounded, size: 13, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    cabangName,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  Text(
                    ' • $tglStr',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusBorder),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Nominal
          Text(
            _formatRp(nominal),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),

          // Keterangan
          Text(
            keterangan.isEmpty || keterangan == '-' ? '(Tanpa keterangan)' : keterangan,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155)),
          ),
          const SizedBox(height: 8),

          // Bukti Transfer link if available
          if (buktiTransfer != null && buktiTransfer.isNotEmpty && buktiTransfer != 'null') ...[
            InkWell(
              onTap: () => _showBuktiDialog(buktiTransfer),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, size: 13, color: Color(0xFF059669)),
                  const SizedBox(width: 4),
                  Text(
                    'Lihat Bukti Transfer',
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
            const SizedBox(height: 8),
          ],

          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Full-width Action Button: Proses Pengajuan Kas
          InkWell(
            onTap: () => _showProcessModal(item),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: status == 'pending'
                    ? const Color(0xFF0F52BA)
                    : (status == 'disetujui' ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: status == 'pending'
                      ? const Color(0xFF0F52BA)
                      : (status == 'disetujui' ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_turned_in_rounded,
                    size: 15,
                    color: status == 'pending'
                        ? Colors.white
                        : (status == 'disetujui' ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status == 'pending' ? 'Proses Pengajuan Kas' : 'Ubah Status Approval ($statusLabel)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: status == 'pending'
                          ? Colors.white
                          : (status == 'disetujui' ? const Color(0xFF059669) : const Color(0xFFDC2626)),
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
            const Icon(Icons.fact_check_outlined, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              'Belum Ada Pengajuan Kas',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              'Tidak ditemukan pengajuan uang kas sesuai filter',
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

// ======================= MODAL PROSES APPROVAL KAS =======================
class _ApprovalKasProcessModal extends StatefulWidget {
  final dynamic item;
  final VoidCallback onProcessed;

  const _ApprovalKasProcessModal({
    required this.item,
    required this.onProcessed,
  });

  @override
  State<_ApprovalKasProcessModal> createState() => _ApprovalKasProcessModalState();
}

class _ApprovalKasProcessModalState extends State<_ApprovalKasProcessModal> {
  final _service = UangKasService();
  final _picker = ImagePicker();

  bool _isProcessing = false;
  late String _selectedStatus;
  File? _fileBuktiTransfer;

  @override
  void initState() {
    super.initState();
    final rawStatus = (widget.item['status'] ?? 'pending').toString().toLowerCase();
    if (rawStatus == 'disetujui' || rawStatus == 'ditolak') {
      _selectedStatus = rawStatus;
    } else {
      _selectedStatus = 'pending';
    }
  }

  Future<void> _pickBuktiTransfer() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _fileBuktiTransfer = File(picked.path));
    }
  }

  Future<void> _submitDecision() async {
    final id = int.tryParse(widget.item['id']?.toString() ?? '0') ?? 0;
    if (id == 0) return;

    setState(() => _isProcessing = true);
    try {
      final data = {
        'status': _selectedStatus,
        'tanggal': widget.item['tanggal'] != null
            ? DateFormat('yyyy-MM-dd').format(DateTime.parse(widget.item['tanggal'].toString()))
            : DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'nominal': widget.item['nominal'] ?? 0,
        'keterangan': widget.item['keterangan'] ?? '',
      };

      await _service.updatePengajuanKas(id, data, file: _fileBuktiTransfer);

      if (mounted) {
        Navigator.pop(context);
        widget.onProcessed();
        String msg = '✅ Perubahan status berhasil disimpan';
        if (_selectedStatus == 'disetujui') {
          msg = '✅ Pengajuan kas berhasil disetujui';
        } else if (_selectedStatus == 'ditolak') {
          msg = '❌ Pengajuan kas telah ditolak';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: _selectedStatus == 'disetujui'
                ? const Color(0xFF059669)
                : (_selectedStatus == 'ditolak' ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Gagal memproses: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nominal = num.tryParse(widget.item['nominal']?.toString() ?? '0') ?? 0;
    final nominalStr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(nominal);
    final cabangName = widget.item['cabang']?['nama_cabang'] ?? '-';
    final keterangan = widget.item['keterangan']?.toString() ?? '-';

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
            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.attach_money_rounded, size: 18, color: Color(0xFF059669)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Proses Pengajuan Kas',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),

            // Summary Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Cabang: $cabangName', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                      Text(nominalStr, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F52BA))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Keterangan: $keterangan', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Dropdown Ubah Status (matching Web)
            Text('Ubah Status *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'disetujui', child: Text('Disetujui', style: TextStyle(fontSize: 13, color: Color(0xFF059669), fontWeight: FontWeight.w600))),
                    DropdownMenuItem(value: 'ditolak', child: Text('Ditolak', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626), fontWeight: FontWeight.w600))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatus = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Upload Bukti Transfer (Opsional) (matching Web)
            Text('Upload Bukti Transfer (Opsional)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickBuktiTransfer,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFF8FAFC),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_upload_outlined, size: 16, color: Color(0xFF059669)),
                          const SizedBox(width: 6),
                          Text(
                            'Choose File',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _fileBuktiTransfer != null
                            ? _fileBuktiTransfer!.path.split(r'/').last.split(r'\').last
                            : 'No file chosen',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _fileBuktiTransfer != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                          fontWeight: _fileBuktiTransfer != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_fileBuktiTransfer != null)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() => _fileBuktiTransfer = null),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons: Batal & Simpan Perubahan (matching Web)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isProcessing ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isProcessing ? null : _submitDecision,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F52BA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isProcessing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
