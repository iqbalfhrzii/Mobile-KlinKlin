import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/api/api_client.dart';
import '../services/operasional_stok_opname_service.dart';

class MonitoringStokOpnameScreen extends StatefulWidget {
  const MonitoringStokOpnameScreen({super.key});

  @override
  State<MonitoringStokOpnameScreen> createState() => _MonitoringStokOpnameScreenState();
}

class _MonitoringStokOpnameScreenState extends State<MonitoringStokOpnameScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  List<dynamic> _cabangs = [];
  Map<String, dynamic>? _currentSession;
  List<dynamic> _sessionDetails = [];

  int? _selectedCabangId;
  DateTime _selectedPeriode = DateTime.now();
  String _selectedTipeSesi = 'tengah_bulan'; // tengah_bulan, akhir_bulan, inventaris

  late TabController _tabController;

  final List<Map<String, String>> _categories = [
    {'code': 'MSN', 'label': 'Mesin Alat (MSN)'},
    {'code': 'CLA', 'label': 'Cleaning Alat (CLA)'},
    {'code': 'BHP', 'label': 'Barang Habis Pakai (BHP)'},
    {'code': 'INV', 'label': 'Inventaris (INV)'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCabangs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCabangs() async {
    try {
      final cabangs = await OperasionalStokOpnameService.getCabangs();
      if (mounted) {
        setState(() {
          _cabangs = cabangs;
          if (cabangs.isNotEmpty) {
            // Find Surabaya or default to first
            final sby = cabangs.firstWhere(
              (c) => (c['nama_cabang'] ?? '').toString().toLowerCase().contains('surabaya'),
              orElse: () => cabangs.first,
            );
            _selectedCabangId = sby['id'];
          }
        });
        if (_selectedCabangId != null) {
          _loadData();
        }
      }
    } catch (e) {
      debugPrint('Error loading cabangs: $e');
    }
  }

  Future<void> _loadData() async {
    if (_selectedCabangId == null) return;

    setState(() => _isLoading = true);
    try {
      // Backend expects 'YYYY-MM' format (e.g. '2026-08')
      final String formattedPeriode = DateFormat('yyyy-MM').format(_selectedPeriode);

      final sessions = await OperasionalStokOpnameService.getSessions(
        cabangId: _selectedCabangId,
        periodeBulan: formattedPeriode,
        tipeSesi: _selectedTipeSesi,
      );

      if (sessions.isNotEmpty) {
        final session = sessions.first;
        final details = await OperasionalStokOpnameService.getSessionDetails(session['id']);
        if (mounted) {
          setState(() {
            _currentSession = details ?? session;
            _sessionDetails = details?['details'] ?? [];
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _currentSession = null;
            _sessionDetails = [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data stok opname: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getImageUrl(dynamic rawPath) {
    if (rawPath == null) return '';
    String p = rawPath.toString().trim().replaceAll(r'\', '/');
    if (p.isEmpty || p == 'null') return '';
    if (p.startsWith('http://') || p.startsWith('https://')) return p;

    // Extract baseDomain from ApiClient
    final baseDomain = ApiClient.baseUrl.replaceAll(RegExp(r'/api/?$'), '');

    if (p.startsWith('/')) p = p.substring(1);
    if (p.startsWith('public/')) p = p.substring(7);
    if (p.startsWith('storage/')) return '$baseDomain/$p';

    return '$baseDomain/storage/$p';
  }

  List<dynamic> _getItemsForCategory(String kategoriKode) {
    return _sessionDetails.where((detail) {
      if (kategoriKode == 'BHP') {
        final kode = detail['barang']?['kategori']?['kode_kategori'] ?? '';
        final hasBarangId = detail['barang_id'] != null;
        final hasBhpId = detail['pembelian_bhp_id'] != null;
        return kode == 'BHP' || hasBarangId || hasBhpId;
      } else {
        final kodeItemFisik = detail['item_fisik']?['barang']?['kategori']?['kode_kategori'] ?? '';
        final kodeBarang = detail['barang']?['kategori']?['kode_kategori'] ?? '';
        return kodeItemFisik == kategoriKode || kodeBarang == kategoriKode;
      }
    }).toList();
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
            child: Row(
              children: [
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monitoring Stok Opname',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pantau hasil checklist aset & bahan habis pakai',
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
          ),

          // Filters: Periode Bulan & Cabang Selector
          _buildFilterBar(),

          // Session Type Tabs: Awal Bulan, Akhir Bulan, Inventaris
          _buildTipeSesiSelector(),

          // Main Content View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _currentSession == null
                    ? _buildEmptyState()
                    : Column(
                        children: [
                          _buildSessionInfoCard(),

                          // Category Tabs
                          Container(
                            color: Colors.white,
                            child: TabBar(
                              controller: _tabController,
                              isScrollable: true,
                              labelColor: AppColors.primary,
                              unselectedLabelColor: const Color(0xFF64748B),
                              indicatorColor: AppColors.primary,
                              indicatorWeight: 3,
                              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                              unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
                              tabs: _categories.map((cat) {
                                final count = _getItemsForCategory(cat['code']!).length;
                                return Tab(
                                  child: Row(
                                    children: [
                                      Text(cat['label']!),
                                      if (count > 0) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '$count',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),

                          // Tab Views
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: _categories.map((cat) {
                                return _buildItemListView(cat['code']!);
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // --- FILTER BAR: PERIODE & CABANG ---
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Periode Date Picker
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedPeriode,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  helpText: 'PILIH BULAN & TAHUN OPNAME',
                );
                if (picked != null) {
                  setState(() => _selectedPeriode = picked);
                  _loadData();
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        DateFormat('MMMM yyyy').format(_selectedPeriode),
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Cabang Dropdown
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedCabangId,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 20),
                  hint: Row(
                    children: [
                      const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text('Pilih Cabang', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                    ],
                  ),
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.w700),
                  items: _cabangs.map((c) {
                    return DropdownMenuItem<int>(
                      value: c['id'] as int,
                      child: Row(
                        children: [
                          const Icon(Icons.storefront_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              c['nama_cabang'] ?? '-',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCabangId = val);
                      _loadData();
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TIPE SESI SELECTOR ---
  Widget _buildTipeSesiSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _buildSesiPill(
              value: 'tengah_bulan',
              title: 'Opname Awal Bulan',
              badge: 'Tgl 15',
              icon: Icons.event_available_rounded,
            ),
            const SizedBox(width: 10),
            _buildSesiPill(
              value: 'akhir_bulan',
              title: 'Opname Akhir Bulan',
              badge: 'Tgl 30',
              icon: Icons.event_note_rounded,
            ),
            const SizedBox(width: 10),
            _buildSesiPill(
              value: 'inventaris',
              title: 'Opname Sesuai Tanggal',
              badge: 'Bebas',
              icon: Icons.assignment_turned_in_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSesiPill({
    required String value,
    required String title,
    required String badge,
    required IconData icon,
  }) {
    final isSelected = _selectedTipeSesi == value;

    return InkWell(
      onTap: () {
        setState(() => _selectedTipeSesi = value);
        _loadData();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SESSION INFO CARD ---
  Widget _buildSessionInfoCard() {
    final status = _currentSession?['status'] ?? 'Draft';
    final isSelesai = status.toString().toLowerCase() == 'selesai';
    final cabangName = _cabangs.firstWhere(
      (c) => c['id'] == _selectedCabangId,
      orElse: () => {'nama_cabang': '-'},
    )['nama_cabang'];

    String sesiName = 'Awal Bulan (Tgl 15)';
    if (_selectedTipeSesi == 'akhir_bulan') sesiName = 'Akhir Bulan (Tgl 30)';
    if (_selectedTipeSesi == 'inventaris') sesiName = 'Sesuai Tanggal (Bebas)';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.fact_check_rounded, color: AppColors.primary, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sesi: $sesiName',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Cabang yang Dipantau: $cabangName',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Status Sesi Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelesai ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelesai ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STATUS SESI CS',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isSelesai ? const Color(0xFF15803D) : const Color(0xFFB45309),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelesai ? Icons.check_circle_rounded : Icons.access_time_filled_rounded,
                      size: 13,
                      color: isSelesai ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSelesai ? 'Telah Diselesaikan' : 'Belum Selesai (Draft)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isSelesai ? const Color(0xFF15803D) : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ITEM LIST VIEW PER CATEGORY ---
  Widget _buildItemListView(String kategoriKode) {
    final filtered = _getItemsForCategory(kategoriKode);

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assignment_outlined, size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'Belum Ada Checklist $kategoriKode',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Belum ada data checklist untuk kategori ini dari tim CS pada periode terpilih.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = filtered[index];
          final bool isBhp = kategoriKode == 'BHP';
          return isBhp ? _buildBhpCard(item) : _buildAlatCard(item);
        },
      ),
    );
  }

  // --- ALAT CARD (MSN, CLA, INV) ---
  Widget _buildAlatCard(dynamic item) {
    final itemFisik = item['item_fisik'] ?? {};
    final barang = itemFisik['barang'] ?? item['barang'] ?? {};
    final waktu = item['created_at'] != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(item['created_at']))
        : '-';
    final kodeQr = itemFisik['kode_qr'] ?? '-';
    final namaAlat = barang['nama_barang'] ?? itemFisik['nama_item'] ?? '-';
    final kondisi = item['kondisi'] ?? 'Baik';

    final String fotoAktual = _getImageUrl(
      item['foto_path'] ?? item['foto_item'] ?? item['foto'] ?? item['foto_url'],
    );
    final String fotoAwal = _getImageUrl(
      itemFisik['foto_path'] ?? itemFisik['foto'] ?? barang['foto'] ?? barang['foto_path'],
    );

    final keterangan = item['keterangan'] ?? '-';

    Color kondisiColor = const Color(0xFF059669);
    Color kondisiBg = const Color(0xFFDCFCE7);
    Color kondisiBorder = const Color(0xFF86EFAC);

    if (kondisi.toString().toLowerCase() == 'rusak') {
      kondisiColor = const Color(0xFFDC2626);
      kondisiBg = const Color(0xFFFEE2E2);
      kondisiBorder = const Color(0xFFFCA5A5);
    } else if (kondisi.toString().toLowerCase() == 'hilang') {
      kondisiColor = const Color(0xFFD97706);
      kondisiBg = const Color(0xFFFEF3C7);
      kondisiBorder = const Color(0xFFFCD34D);
    }

    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Foto Thumbnail Section (Awal & Aktual)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (fotoAwal.isNotEmpty) ...[
                _buildPhotoThumbnail(
                  url: fotoAwal,
                  badge: 'AWAL',
                  badgeColor: const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
              ],
              if (fotoAktual.isNotEmpty) ...[
                _buildPhotoThumbnail(
                  url: fotoAktual,
                  badge: 'AKTUAL',
                  badgeColor: AppColors.primary,
                ),
              ] else if (fotoAwal.isEmpty) ...[
                _buildEmptyThumbnail(),
              ],
            ],
          ),
          const SizedBox(width: 14),

          // Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Waktu & Kondisi Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          waktu,
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kondisiBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kondisiBorder),
                      ),
                      child: Text(
                        kondisi,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: kondisiColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Nama Alat
                Text(
                  namaAlat,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),

                // Kode QR Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.qr_code_2_rounded, size: 12, color: Color(0xFF475569)),
                          const SizedBox(width: 4),
                          Text(
                            kodeQr,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (keterangan != '-' && keterangan.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Catatan: $keterangan',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- BHP CARD (Bahan Habis Pakai) ---
  Widget _buildBhpCard(dynamic item) {
    final barang = item['barang'] ?? {};
    final pembelianBhp = item['pembelian_bhp'] ?? {};
    final waktu = item['created_at'] != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(item['created_at']))
        : '-';
    final namaBarang = barang['nama_barang'] ?? pembelianBhp['nama_barang'] ?? '-';
    final sisaAkhir = item['sisa_akhir'] ?? item['stok_aktual'] ?? '-';
    final satuan = barang['satuan'] ?? pembelianBhp['satuan'] ?? 'Pcs';

    final String fotoBhp = _getImageUrl(
      item['foto_path'] ?? item['foto_kuantitas'] ?? item['foto'] ?? item['foto_url'] ?? barang['foto'],
    );
    final keterangan = item['keterangan'] ?? '-';

    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Foto Thumbnail
          if (fotoBhp.isNotEmpty)
            _buildPhotoThumbnail(
              url: fotoBhp,
              badge: 'FOTO',
              badgeColor: const Color(0xFF1D4ED8),
            )
          else
            _buildEmptyThumbnail(),
          const SizedBox(width: 14),

          // Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          waktu,
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        'BHP',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF1D4ED8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Nama Barang
                Text(
                  namaBarang,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),

                // Sisa Stok Akhir
                Row(
                  children: [
                    Text(
                      'Sisa Aktual: ',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    Text(
                      '$sisaAkhir $satuan',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),

                if (keterangan != '-' && keterangan.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Catatan: $keterangan',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail({
    required String url,
    required String badge,
    required Color badgeColor,
  }) {
    return InkWell(
      onTap: () => _showFullImage(url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
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
                    debugPrint('Error loading image ($url): $error');
                    return Container(
                      color: const Color(0xFFF1F5F9),
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 24),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyThumbnail() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Center(
        child: Icon(Icons.image_not_supported_rounded, color: Color(0xFFCBD5E1), size: 24),
      ),
    );
  }

  void _showFullImage(String url) {
    if (url.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(20),
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
                          'Gagal memuat gambar resolusi penuh',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final cabangName = _cabangs.firstWhere(
      (c) => c['id'] == _selectedCabangId,
      orElse: () => {'nama_cabang': 'Cabang'},
    )['nama_cabang'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.checklist_rtl_rounded, color: AppColors.primary, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak Ada Sesi Stok Opname',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Belum ada sesi stok opname untuk cabang $cabangName pada periode ${DateFormat('MMMM yyyy').format(_selectedPeriode)}.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
