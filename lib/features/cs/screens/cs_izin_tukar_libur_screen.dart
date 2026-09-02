import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/api/api_client.dart';
import '../services/cs_izin_tukar_libur_service.dart';

class CsIzinTukarLiburScreen extends StatefulWidget {
  const CsIzinTukarLiburScreen({super.key});

  @override
  State<CsIzinTukarLiburScreen> createState() => _CsIzinTukarLiburScreenState();
}

class _CsIzinTukarLiburScreenState extends State<CsIzinTukarLiburScreen> with SingleTickerProviderStateMixin {
  final CsIzinTukarLiburService _service = CsIzinTukarLiburService();
  late TabController _tabController;

  // Cuti / Izin State
  bool _isLoadingCuti = false;
  List<Map<String, dynamic>> _cutiList = [];
  String _statusCutiFilter = 'semua'; // 'semua', 'disetujui', 'ditolak'
  DateTime? _selectedBulanCuti;
  final TextEditingController _searchCutiController = TextEditingController();

  // Tukar Libur State
  bool _isLoadingTukar = false;
  List<Map<String, dynamic>> _tukarList = [];
  DateTime? _selectedBulanTukar;
  final TextEditingController _searchTukarController = TextEditingController();

  // Summary Today
  bool _isLoadingSummary = false;
  Map<String, dynamic> _summaryData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    final now = DateTime.now();
    _selectedBulanCuti = DateTime(now.year, now.month);
    _selectedBulanTukar = DateTime(now.year, now.month);

    _loadSummary();
    _loadCutiList();
    _loadTukarList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCutiController.dispose();
    _searchTukarController.dispose();
    super.dispose();
  }

  String _formatMonthParam(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('yyyy-MM').format(dt);
  }

  String _formatMonthDisplay(DateTime? dt) {
    if (dt == null) return 'Semua Bulan';
    return DateFormat('MMMM yyyy', 'id_ID').format(dt);
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoadingSummary = true);
    final data = await _service.fetchSummaryToday();
    if (mounted) {
      setState(() {
        _summaryData = data;
        _isLoadingSummary = false;
      });
    }
  }

  Future<void> _loadCutiList() async {
    setState(() => _isLoadingCuti = true);
    final data = await _service.fetchCutiIzin(
      status: _statusCutiFilter,
      bulan: _formatMonthParam(_selectedBulanCuti),
      search: _searchCutiController.text,
    );
    if (mounted) {
      setState(() {
        _cutiList = data;
        _isLoadingCuti = false;
      });
    }
  }

  Future<void> _loadTukarList() async {
    setState(() => _isLoadingTukar = true);
    final data = await _service.fetchTukarLibur(
      bulan: _formatMonthParam(_selectedBulanTukar),
      search: _searchTukarController.text,
    );
    if (mounted) {
      setState(() {
        _tukarList = data;
        _isLoadingTukar = false;
      });
    }
  }

  Future<void> _pickMonth(bool isCuti) async {
    final current = (isCuti ? _selectedBulanCuti : _selectedBulanTukar) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2023, 1),
      lastDate: DateTime(2030, 12),
      helpText: 'PILIH BULAN & TAHUN',
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      setState(() {
        if (isCuti) {
          _selectedBulanCuti = DateTime(picked.year, picked.month);
        } else {
          _selectedBulanTukar = DateTime(picked.year, picked.month);
        }
      });
      if (isCuti) {
        _loadCutiList();
      } else {
        _loadTukarList();
      }
    }
  }

  void _shiftMonth(bool isCuti, int delta) {
    setState(() {
      final current = (isCuti ? _selectedBulanCuti : _selectedBulanTukar) ?? DateTime.now();
      final updated = DateTime(current.year, current.month + delta);
      if (isCuti) {
        _selectedBulanCuti = updated;
      } else {
        _selectedBulanTukar = updated;
      }
    });
    if (isCuti) {
      _loadCutiList();
    } else {
      _loadTukarList();
    }
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    if (imageUrl.isEmpty) return;
    final fullUrl = imageUrl.startsWith('http')
        ? imageUrl
        : '${ApiClient.baseUrl.replaceAll(RegExp(r'/api/?$'), '')}/storage/${imageUrl.replaceFirst(RegExp(r'^/?storage/'), '')}';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: Image.network(
                  fullUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => Container(
                    padding: const EdgeInsets.all(32),
                    color: Colors.white,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text('Gagal memuat foto lampiran', style: GoogleFonts.inter(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCutiDetailSheet(Map<String, dynamic> item) {
    final karyawan = item['karyawan'] as Map<String, dynamic>? ?? {};
    final nama = karyawan['nama']?.toString() ?? '-';
    final cabang = karyawan['cabang']?['nama_cabang']?.toString() ?? '-';
    final jenis = (item['jenis'] ?? 'cuti').toString().toUpperCase();
    final status = (item['status'] ?? '-').toString().toLowerCase();
    final tglMulai = item['tanggal_mulai']?.toString() ?? '-';
    final tglSelesai = item['tanggal_selesai']?.toString() ?? '-';
    final durasi = item['durasi_hari']?.toString() ?? '1';
    final alasan = item['alasan']?.toString() ?? '-';
    final catatan = item['catatan_hrd'] ?? item['catatan'] ?? '-';
    final tglPengajuan = item['created_at'] != null
        ? DateFormat('d MMMM yyyy, HH:mm', 'id_ID').format(DateTime.tryParse(item['created_at'].toString()) ?? DateTime.now())
        : '-';
    final selfie = item['selfie'] ?? item['foto_selfie'] ?? item['lampiran'] ?? item['bukti'];

    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detail Pengajuan $jenis',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Diajukan pada $tglPengajuan',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              const Divider(height: 28, color: Color(0xFFF1F5F9)),

              _buildDetailInfoRow(Icons.person_rounded, 'Cleaner', nama, subValue: cabang),
              const SizedBox(height: 14),

              _buildDetailInfoRow(
                Icons.calendar_today_rounded,
                'Tanggal Pelaksanaan',
                '${_formatDate(tglMulai)} - ${_formatDate(tglSelesai)}',
                subValue: 'Durasi: $durasi Hari',
                valueColor: AppColors.primary,
              ),
              const SizedBox(height: 14),

              _buildDetailInfoRow(Icons.short_text_rounded, 'Alasan', alasan),
              const SizedBox(height: 14),

              if (catatan != '-' && catatan.toString().trim().isNotEmpty) ...[
                _buildDetailInfoRow(Icons.notes_rounded, 'Catatan HRD', catatan.toString()),
                const SizedBox(height: 14),
              ],

              if (selfie != null && selfie.toString().trim().isNotEmpty && selfie != 'null') ...[
                Text(
                  'Lampiran / Bukti Foto:',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showImagePreview(context, selfie.toString()),
                  child: Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      color: const Color(0xFFF8FAFC),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.network(
                          selfie.toString().startsWith('http')
                              ? selfie.toString()
                              : '${ApiClient.baseUrl.replaceAll(RegExp(r'/api/?$'), '')}/storage/${selfie.toString().replaceFirst(RegExp(r'^/?storage/'), '')}',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_rounded, size: 36, color: Colors.grey),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.zoom_in_rounded, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text('Ketuk untuk Memperbesar', style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Tutup', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == '-') return '-';
    try {
      final dt = DateTime.tryParse(raw);
      if (dt != null) {
        return DateFormat('d MMM yyyy', 'id_ID').format(dt);
      }
    } catch (_) {}
    return raw;
  }

  Widget _buildDetailInfoRow(IconData icon, String label, String value, {String? subValue, Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF475569)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? const Color(0xFF1E293B),
                ),
              ),
              if (subValue != null && subValue.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subValue,
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color text = const Color(0xFF475569);
    String label = status.toUpperCase();

    if (status == 'disetujui' || status == 'approved') {
      bg = const Color(0xFFECFDF5);
      text = const Color(0xFF059669);
      label = 'DISETUJUI';
    } else if (status == 'ditolak' || status == 'rejected') {
      bg = const Color(0xFFFEF2F2);
      text = const Color(0xFFDC2626);
      label = 'DITOLAK';
    } else if (status == 'pending') {
      bg = const Color(0xFFFFFBEB);
      text = const Color(0xFFD97706);
      label = 'MENUNGGU';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: text.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: text),
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
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCutiTab(),
                _buildTukarLiburTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return GradientHeader(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HeaderBackButton(onTap: () => Navigator.pop(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Izin & Libur Cleaner',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Jadwal Cuti & Tukar Libur Cabang',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              HeaderIconButton(
                icon: Icons.refresh_rounded,
                onTap: () {
                  _loadSummary();
                  _loadCutiList();
                  _loadTukarList();
                },
              ),
            ],
          ),

          // Summary Today Banner
          if (!_isLoadingSummary &&
              _summaryData['total_tidak_masuk_today'] != null &&
              (_summaryData['total_tidak_masuk_today'] as int) > 0) ...[
            const SizedBox(height: 8),
            _buildTodaySummaryCard(),
          ],

          const SizedBox(height: 10),

          // Integrated Tab Bar inside Header (Same design as HRD Cuti)
          Container(
            height: 38,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1D4ED8),
              unselectedLabelColor: Colors.white.withValues(alpha: 0.9),
              labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Data Cuti & Izin'),
                Tab(text: 'Riwayat Tukar Libur'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySummaryCard() {
    final int total = _summaryData['total_tidak_masuk_today'] ?? 0;
    final List cutiToday = _summaryData['cuti_today'] as List? ?? [];
    final List tukarToday = _summaryData['tukar_libur_today'] as List? ?? [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: Colors.amberAccent),
              const SizedBox(width: 6),
              Text(
                'Cleaner Libur / Tidak Masuk Hari Ini ($total Orang)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ...cutiToday.map((c) {
                final name = c['karyawan']?['nama']?.toString() ?? 'Cleaner';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.purple[900]?.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '• $name (Cuti)',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                );
              }),
              ...tukarToday.map((t) {
                final p = t['pengaju']?['nama']?.toString() ?? 'Cleaner';
                final tg = t['target']?['nama']?.toString() ?? 'Cleaner';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue[900]?.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '• $p & $tg (Tukar Libur)',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== TAB 1: CUTI & IZIN ====================
  Widget _buildCutiTab() {
    final bool hasActiveFilter = _selectedBulanCuti != null ||
        _statusCutiFilter != 'semua' ||
        _searchCutiController.text.trim().isNotEmpty;

    return RefreshIndicator(
      onRefresh: _loadCutiList,
      child: Column(
        children: [
          // Filter & Search Controls Card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Month Navigation & Search
                Row(
                  children: [
                    // Search Input
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: _searchCutiController,
                          onSubmitted: (_) => _loadCutiList(),
                          decoration: InputDecoration(
                            hintText: 'Cari cleaner...',
                            hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                            suffixIcon: _searchCutiController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchCutiController.clear();
                                      _loadCutiList();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 9),
                          ),
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Month Picker Pill with Prev/Next
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded, size: 18, color: Color(0xFF64748B)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 36),
                            onPressed: () => _shiftMonth(true, -1),
                          ),
                          InkWell(
                            onTap: () => _pickMonth(true),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded, size: 15, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatMonthDisplay(_selectedBulanCuti),
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF64748B)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 36),
                            onPressed: () => _shiftMonth(true, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Status Chips
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('semua', 'Semua Status', _statusCutiFilter == 'semua', (val) {
                              setState(() => _statusCutiFilter = val);
                              _loadCutiList();
                            }),
                            const SizedBox(width: 6),
                            _buildFilterChip('disetujui', 'Disetujui', _statusCutiFilter == 'disetujui', (val) {
                              setState(() => _statusCutiFilter = val);
                              _loadCutiList();
                            }, activeColor: const Color(0xFF059669)),
                            const SizedBox(width: 6),
                            _buildFilterChip('ditolak', 'Ditolak', _statusCutiFilter == 'ditolak', (val) {
                              setState(() => _statusCutiFilter = val);
                              _loadCutiList();
                            }, activeColor: const Color(0xFFDC2626)),
                          ],
                        ),
                      ),
                    ),
                    if (hasActiveFilter) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _statusCutiFilter = 'semua';
                            _selectedBulanCuti = null;
                            _searchCutiController.clear();
                          });
                          _loadCutiList();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.close_rounded, size: 12, color: Color(0xFFDC2626)),
                              const SizedBox(width: 2),
                              Text(
                                'Reset',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // List Data
          Expanded(
            child: _isLoadingCuti
                ? const Center(child: CircularProgressIndicator())
                : _cutiList.isEmpty
                    ? _buildEmptyState(
                        'Belum Ada Pengajuan Cuti / Izin',
                        'Tidak ada data cuti atau izin cleaner pada filter & periode yang dipilih.',
                        onReset: hasActiveFilter
                            ? () {
                                setState(() {
                                  _statusCutiFilter = 'semua';
                                  _selectedBulanCuti = null;
                                  _searchCutiController.clear();
                                });
                                _loadCutiList();
                              }
                            : null,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                        itemCount: _cutiList.length,
                        itemBuilder: (ctx, index) {
                          final item = _cutiList[index];
                          return _buildCutiCard(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, bool isSelected, Function(String) onSelect, {Color? activeColor}) {
    final Color selectedBg = activeColor ?? const Color(0xFF0F172A);
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? selectedBg : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildCutiCard(Map<String, dynamic> item) {
    final karyawan = item['karyawan'] as Map<String, dynamic>? ?? {};
    final nama = karyawan['nama']?.toString() ?? '-';
    final cabang = karyawan['cabang']?['nama_cabang']?.toString() ?? '-';
    final jenis = (item['jenis'] ?? 'cuti').toString().toLowerCase();
    final status = (item['status'] ?? '-').toString().toLowerCase();
    final tglMulai = item['tanggal_mulai']?.toString() ?? '-';
    final tglSelesai = item['tanggal_selesai']?.toString() ?? '-';
    final durasi = item['durasi_hari']?.toString() ?? '1';
    final alasan = item['alasan']?.toString() ?? '-';

    final bool isCutiType = jenis == 'cuti';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showCutiDetailSheet(item),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar, Name, Branch & Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isCutiType ? const Color(0xFFF3E8FF) : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          nama.isNotEmpty ? nama[0].toUpperCase() : 'C',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isCutiType ? const Color(0xFF7E22CE) : const Color(0xFFC2410C),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nama,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cabang,
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(status),
                  ],
                ),
                const SizedBox(height: 12),

                // Date Execution Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF0284C7)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_formatDate(tglMulai)} - ${_formatDate(tglSelesai)}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$durasi Hari',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0369A1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Reason Preview
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alasan: ',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                    ),
                    Expanded(
                      child: Text(
                        alasan,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bottom Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    () {
                      final isKhusus = jenis.contains('khusus');
                      final isCuti = jenis == 'cuti';
                      final Color bg = isKhusus ? const Color(0xFFFAF5FF) : (isCuti ? const Color(0xFFF0F9FF) : const Color(0xFFFFFBEB));
                      final Color border = isKhusus ? const Color(0xFFE9D5FF) : (isCuti ? const Color(0xFFBAE6FD) : const Color(0xFFFDE68A));
                      final Color text = isKhusus ? const Color(0xFF7C3AED) : (isCuti ? const Color(0xFF0284C7) : const Color(0xFFB45309));
                      final String label = isKhusus ? 'CUTI KHUSUS' : (isCuti ? 'CUTI BULANAN' : 'IZIN');

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: border),
                        ),
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: text,
                          ),
                        ),
                      );
                    }(),
                    Row(
                      children: [
                        Text(
                          'Lihat Detail',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primary),
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

  // ==================== TAB 2: TUKAR LIBUR ====================
  Widget _buildTukarLiburTab() {
    final bool hasActiveFilter = _selectedBulanTukar != null || _searchTukarController.text.trim().isNotEmpty;

    return RefreshIndicator(
      onRefresh: _loadTukarList,
      child: Column(
        children: [
          // Filter & Search Controls Card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Search Input
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _searchTukarController,
                      onSubmitted: (_) => _loadTukarList(),
                      decoration: InputDecoration(
                        hintText: 'Cari cleaner...',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                        suffixIcon: _searchTukarController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchTukarController.clear();
                                  _loadTukarList();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Month Picker Pill with Prev/Next
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, size: 18, color: Color(0xFF64748B)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 36),
                        onPressed: () => _shiftMonth(false, -1),
                      ),
                      InkWell(
                        onTap: () => _pickMonth(false),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded, size: 15, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                _formatMonthDisplay(_selectedBulanTukar),
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF64748B)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 36),
                        onPressed: () => _shiftMonth(false, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List Data
          Expanded(
            child: _isLoadingTukar
                ? const Center(child: CircularProgressIndicator())
                : _tukarList.isEmpty
                    ? _buildEmptyState(
                        'Belum Ada Riwayat Tukar Libur',
                        'Tidak ada jadwal tukar libur cleaner yang disetujui pada periode ini.',
                        onReset: hasActiveFilter
                            ? () {
                                setState(() {
                                  _selectedBulanTukar = null;
                                  _searchTukarController.clear();
                                });
                                _loadTukarList();
                              }
                            : null,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                        itemCount: _tukarList.length,
                        itemBuilder: (ctx, index) {
                          final item = _tukarList[index];
                          return _buildTukarCard(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTukarCard(Map<String, dynamic> item) {
    final pengaju = item['pengaju'] as Map<String, dynamic>? ?? {};
    final target = item['target'] as Map<String, dynamic>? ?? {};
    final hrd = item['hrd'] as Map<String, dynamic>? ?? {};

    final namaPengaju = pengaju['nama']?.toString() ?? 'Cleaner A';
    final tglPengaju = item['tanggal_pengaju']?.toString() ?? '-';

    final namaTarget = target['nama']?.toString() ?? 'Cleaner B';
    final tglTarget = item['tanggal_target']?.toString() ?? '-';

    final alasan = item['alasan']?.toString() ?? '-';
    final hrdNama = hrd['nama']?.toString() ?? 'HRD';

    final tglPengajuan = item['created_at'] != null
        ? DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(DateTime.tryParse(item['created_at'].toString()) ?? DateTime.now())
        : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status & Tanggal Pengajuan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Diajukan: $tglPengajuan',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
              _buildStatusBadge('disetujui'),
            ],
          ),
          const SizedBox(height: 12),

          // Pertukaran Cleaner A <-> Cleaner B
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                // Cleaner A (Pengaju)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pengaju (Cleaner A)',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        namaPengaju,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Libur Asal:',
                        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                      ),
                      Text(
                        _formatDate(tglPengaju),
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                ),

                // Exchange Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, size: 20, color: AppColors.primary),
                ),

                // Cleaner B (Target)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Target (Cleaner B)',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        namaTarget,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Libur Asal:',
                        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                      ),
                      Text(
                        _formatDate(tglTarget),
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0284C7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Alasan
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alasan: ',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
              ),
              Expanded(
                child: Text(
                  alasan,
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Approver
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFF059669)),
              const SizedBox(width: 4),
              Text(
                'Disetujui oleh $hrdNama',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF059669)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String message, {VoidCallback? onReset}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.event_available_rounded, size: 36, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), height: 1.4),
            ),
            if (onReset != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text('Tampilkan Semua Periode', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
