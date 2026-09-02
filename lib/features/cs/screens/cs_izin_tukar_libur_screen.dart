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
  String _bulanCutiFilter = ''; // 'YYYY-MM'
  final TextEditingController _searchCutiController = TextEditingController();

  // Tukar Libur State
  bool _isLoadingTukar = false;
  List<Map<String, dynamic>> _tukarList = [];
  String _bulanTukarFilter = ''; // 'YYYY-MM'
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

    // Default current month
    final now = DateTime.now();
    _bulanCutiFilter = DateFormat('yyyy-MM').format(now);
    _bulanTukarFilter = DateFormat('yyyy-MM').format(now);

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
      bulan: _bulanCutiFilter,
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
      bulan: _bulanTukarFilter,
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
    final currentStr = isCuti ? _bulanCutiFilter : _bulanTukarFilter;
    DateTime initial = DateTime.now();
    if (currentStr.isNotEmpty) {
      try {
        final parts = currentStr.split('-');
        if (parts.length == 2) {
          initial = DateTime(int.parse(parts[0]), int.parse(parts[1]));
        }
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2023, 1),
      lastDate: DateTime(2030, 12),
      helpText: 'PILIH BULAN & TAHUN',
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      final formatted = DateFormat('yyyy-MM').format(picked);
      setState(() {
        if (isCuti) {
          _bulanCutiFilter = formatted;
        } else {
          _bulanTukarFilter = formatted;
        }
      });
      if (isCuti) {
        _loadCutiList();
      } else {
        _loadTukarList();
      }
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
    final nama = karyawan['nama'] ?? '-';
    final cabang = karyawan['cabang']?['nama_cabang'] ?? '-';
    final jenis = (item['jenis'] ?? 'cuti').toString().toUpperCase();
    final status = (item['status'] ?? '-').toString().toLowerCase();
    final tglMulai = item['tanggal_mulai'] ?? '-';
    final tglSelesai = item['tanggal_selesai'] ?? '-';
    final durasi = item['durasi_hari']?.toString() ?? '1';
    final alasan = item['alasan'] ?? '-';
    final catatan = item['catatan_hrd'] ?? item['catatan'] ?? '-';
    final tglPengajuan = item['created_at'] != null
        ? DateFormat('d MMMM yyyy, HH:mm', 'id_ID').format(DateTime.tryParse(item['created_at']) ?? DateTime.now())
        : '-';
    final selfie = item['selfie'] ?? item['foto_selfie'] ?? item['lampiran'] ?? item['bukti'];

    showModalBottomSheet(
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

              // Info Karyawan
              _buildDetailInfoRow(Icons.person_rounded, 'Cleaner', nama, subValue: cabang),
              const SizedBox(height: 14),

              // Tanggal Pelaksanaan
              _buildDetailInfoRow(
                Icons.calendar_today_rounded,
                'Tanggal Pelaksanaan',
                '${_formatDate(tglMulai)} - ${_formatDate(tglSelesai)}',
                subValue: 'Durasi: $durasi Hari',
                valueColor: AppColors.primary,
              ),
              const SizedBox(height: 14),

              // Alasan
              _buildDetailInfoRow(Icons.short_text_rounded, 'Alasan', alasan),
              const SizedBox(height: 14),

              // Catatan HRD
              if (catatan != '-' && catatan.toString().trim().isNotEmpty) ...[
                _buildDetailInfoRow(Icons.notes_rounded, 'Catatan HRD', catatan),
                const SizedBox(height: 14),
              ],

              // Lampiran / Selfie jika ada
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
          _buildTabBar(),
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
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Jadwal Cuti & Tukar Libur Cabang',
                      style: GoogleFonts.inter(
                        fontSize: 12,
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

          // Summary Today Banner (if available)
          if (!_isLoadingSummary &&
              _summaryData['total_tidak_masuk_today'] != null &&
              (_summaryData['total_tidak_masuk_today'] as int) > 0) ...[
            const SizedBox(height: 14),
            _buildTodaySummaryCard(),
          ],
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
                'Cleaner Tidak Masuk Hari Ini ($total Orang)',
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
                final name = c['karyawan']?['nama'] ?? 'Cleaner';
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
                final p = t['pengaju']?['nama'] ?? 'Cleaner';
                final tg = t['target']?['nama'] ?? 'Cleaner';
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

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(4),
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
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Data Cuti & Izin'),
          Tab(text: 'Riwayat Tukar Libur'),
        ],
      ),
    );
  }

  // ==================== TAB 1: CUTI & IZIN ====================
  Widget _buildCutiTab() {
    return RefreshIndicator(
      onRefresh: _loadCutiList,
      child: Column(
        children: [
          // Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
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
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Month Picker Button
                    InkWell(
                      onTap: () => _pickMonth(true),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              _bulanCutiFilter.isNotEmpty ? _bulanCutiFilter : 'Bulan',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Status Filter Chips
                SingleChildScrollView(
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
                      }),
                      const SizedBox(width: 6),
                      _buildFilterChip('ditolak', 'Ditolak', _statusCutiFilter == 'ditolak', (val) {
                        setState(() => _statusCutiFilter = val);
                        _loadCutiList();
                      }),
                      if (_bulanCutiFilter.isNotEmpty || _statusCutiFilter != 'semua' || _searchCutiController.text.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _statusCutiFilter = 'semua';
                              _bulanCutiFilter = '';
                              _searchCutiController.clear();
                            });
                            _loadCutiList();
                          },
                          child: Text(
                            'Reset',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red[600]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List Data
          Expanded(
            child: _isLoadingCuti
                ? const Center(child: CircularProgressIndicator())
                : _cutiList.isEmpty
                    ? _buildEmptyState('Belum ada data cuti & izin pada periode ini.')
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

  Widget _buildFilterChip(String value, String label, bool isSelected, Function(String) onSelect) {
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildCutiCard(Map<String, dynamic> item) {
    final karyawan = item['karyawan'] as Map<String, dynamic>? ?? {};
    final nama = karyawan['nama'] ?? '-';
    final cabang = karyawan['cabang']?['nama_cabang'] ?? '-';
    final jenis = (item['jenis'] ?? 'cuti').toString().toLowerCase();
    final status = (item['status'] ?? '-').toString().toLowerCase();
    final tglMulai = item['tanggal_mulai'] ?? '-';
    final tglSelesai = item['tanggal_selesai'] ?? '-';
    final durasi = item['durasi_hari']?.toString() ?? '1';
    final alasan = item['alasan'] ?? '-';

    final bool isCutiType = jenis == 'cuti';

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
          // Header Cleaner & Jenis
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isCutiType ? const Color(0xFFF3E8FF) : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
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
              const SizedBox(width: 10),
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

          // Tanggal Pelaksanaan
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          const SizedBox(height: 8),

          // Alasan
          Text(
            alasan,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 12),

          // Footer Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCutiType ? const Color(0xFFFAF5FF) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCutiType ? const Color(0xFFE9D5FF) : const Color(0xFFFDE68A),
                  ),
                ),
                child: Text(
                  jenis.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isCutiType ? const Color(0xFF7E22CE) : const Color(0xFFB45309),
                  ),
                ),
              ),
              InkWell(
                onTap: () => _showCutiDetailSheet(item),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== TAB 2: TUKAR LIBUR ====================
  Widget _buildTukarLiburTab() {
    return RefreshIndicator(
      onRefresh: _loadTukarList,
      child: Column(
        children: [
          // Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      controller: _searchTukarController,
                      onSubmitted: (_) => _loadTukarList(),
                      decoration: InputDecoration(
                        hintText: 'Cari nama cleaner...',
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
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Month Picker Button
                InkWell(
                  onTap: () => _pickMonth(false),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          _bulanTukarFilter.isNotEmpty ? _bulanTukarFilter : 'Bulan',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                        ),
                      ],
                    ),
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
                    ? _buildEmptyState('Belum ada riwayat tukar libur pada periode ini.')
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

    final namaPengaju = pengaju['nama'] ?? 'Cleaner A';
    final tglPengaju = item['tanggal_pengaju'] ?? '-';

    final namaTarget = target['nama'] ?? 'Cleaner B';
    final tglTarget = item['tanggal_target'] ?? '-';

    final alasan = item['alasan'] ?? '-';
    final hrdNama = hrd['nama'] ?? 'HRD';

    final tglPengajuan = item['created_at'] != null
        ? DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(DateTime.tryParse(item['created_at']) ?? DateTime.now())
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
                tglPengajuan,
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_available_rounded, size: 48, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak Ada Data',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
