import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  List<dynamic> _allMonthSessions = [];
  Map<String, dynamic>? _currentSession;
  List<dynamic> _sessionDetails = [];
  String? _authToken;

  int? _selectedCabangId;
  DateTime _selectedPeriode = DateTime.now();
  String _selectedTipeSesi = 'tengah_bulan'; // tengah_bulan, akhir_bulan
  int _selectedCategoryIndex = 0;

  late TabController _tabController;

  final List<Map<String, dynamic>> _categories = [
    {
      'code': 'MSN',
      'label': 'Mesin Alat',
      'short': 'MSN',
      'icon': Icons.precision_manufacturing_rounded,
    },
    {
      'code': 'CLA',
      'label': 'Cleaning Alat',
      'short': 'CLA',
      'icon': Icons.cleaning_services_rounded,
    },
    {
      'code': 'BHP',
      'label': 'Habis Pakai',
      'short': 'BHP',
      'icon': Icons.inventory_2_rounded,
    },
    {
      'code': 'INV',
      'label': 'Inventaris',
      'short': 'INV',
      'icon': Icons.home_repair_service_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _selectedCategoryIndex) {
        if (mounted) {
          setState(() {
            _selectedCategoryIndex = _tabController.index;
          });
        }
      }
    });
    _loadAuthTokenAndCabangs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAuthTokenAndCabangs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('auth_token');
    } catch (_) {}
    _loadCabangs();
  }

  Future<void> _loadCabangs() async {
    try {
      final cabangs = await OperasionalStokOpnameService.getCabangs();
      if (mounted) {
        setState(() {
          _cabangs = cabangs;
          if (cabangs.isNotEmpty) {
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
      final String formattedPeriode = DateFormat('yyyy-MM').format(_selectedPeriode);

      final sessions = await OperasionalStokOpnameService.getSessions(
        cabangId: _selectedCabangId,
        periodeBulan: formattedPeriode,
      );

      _allMonthSessions = sessions;

      final matchingSession = sessions.firstWhere(
        (s) => s['tipe_sesi'] == _selectedTipeSesi,
        orElse: () => null,
      );

      if (matchingSession != null) {
        final details = await OperasionalStokOpnameService.getSessionDetails(matchingSession['id']);
        if (mounted) {
          setState(() {
            _currentSession = details ?? matchingSession;
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

  Map<String, dynamic> _getSessionStatus(String tipeSesi) {
    final s = _allMonthSessions.firstWhere(
      (session) => session['tipe_sesi'] == tipeSesi,
      orElse: () => null,
    );
    if (s == null) {
      return {'label': 'Belum Ada', 'isSelesai': false, 'exists': false};
    }
    final isSelesai = (s['status'] ?? '').toString().toLowerCase() == 'selesai';
    return {
      'label': isSelesai ? 'Selesai' : 'Sedang Berjalan',
      'isSelesai': isSelesai,
      'exists': true,
    };
  }

  String _getImageUrl(dynamic rawPath) {
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

  String _formatBulanTahun(DateTime dt) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April',
      'Mei', 'Juni', 'Juli', 'Agustus',
      'September', 'Oktober', 'November', 'Desember'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
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
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 18),
            child: Row(
              children: [
                if (Navigator.canPop(context)) ...[
                  const AppBackButton(),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monitoring Stok Opname',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pantau hasil checklist aset cabang',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                  tooltip: 'Segarkan',
                ),
              ],
            ),
          ),

          // Filters: Periode Bulan & Cabang Selector
          _buildFilterBar(),

          // Integrated Hero Overview & Session Switcher
          _buildHeroOverviewCard(),

          // Category Pills
          _buildCategoryPillsBar(),

          // Main Content View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _currentSession == null
                    ? _buildEmptyState()
                    : TabBarView(
                        controller: _tabController,
                        children: _categories.map((cat) {
                          return _buildItemListView(cat['code']!);
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }

  // --- 1. FILTER BAR ---
  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          // Periode Date Picker
          Expanded(
            flex: 5,
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 15, color: Color(0xFF0284C7)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _formatBulanTahun(_selectedPeriode),
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Cabang Dropdown
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedCabangId,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
                  hint: Text(
                    'Pilih Cabang',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.w700),
                  items: _cabangs.map((c) {
                    return DropdownMenuItem<int>(
                      value: c['id'] as int,
                      child: Text(
                        c['nama_cabang'] ?? '-',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.w700),
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

  // --- 2. HERO OVERVIEW & SESSION SWITCHER ---
  Widget _buildHeroOverviewCard() {
    final statusAwal = _getSessionStatus('tengah_bulan');
    final statusAkhir = _getSessionStatus('akhir_bulan');

    final totalItems = _sessionDetails.length;
    final int baikCount = _sessionDetails.where((d) => (d['kondisi'] ?? '').toString().toLowerCase() == 'baik').length;
    final int rusakCount = _sessionDetails.where((d) => (d['kondisi'] ?? '').toString().toLowerCase().contains('rusak') || (d['kondisi'] ?? '').toString().toLowerCase().contains('service')).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1E293B).withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Switcher Sesi
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSessionTab(
                    value: 'tengah_bulan',
                    title: 'Awal Bulan',
                    sub: 'Tgl 15',
                    status: statusAwal,
                  ),
                ),
                Expanded(
                  child: _buildSessionTab(
                    value: 'akhir_bulan',
                    title: 'Akhir Bulan',
                    sub: 'Tgl 30',
                    status: statusAkhir,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Mini Stats Row
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  label: 'Total Data',
                  value: '$totalItems Item',
                  icon: Icons.checklist_rounded,
                  color: const Color(0xFF0284C7),
                  bg: const Color(0xFFF0F9FF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricItem(
                  label: 'Kondisi Baik',
                  value: '$baikCount Item',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF16A34A),
                  bg: const Color(0xFFF0FDF4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricItem(
                  label: 'Perlu Servis',
                  value: '$rusakCount Item',
                  icon: Icons.build_circle_outlined,
                  color: rusakCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                  bg: rusakCount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTab({
    required String value,
    required String title,
    required String sub,
    required Map<String, dynamic> status,
  }) {
    final isSelected = _selectedTipeSesi == value;
    final bool isSelesai = status['isSelesai'] == true;
    final bool exists = status['exists'] == true;

    return InkWell(
      onTap: () {
        if (_selectedTipeSesi != value) {
          setState(() => _selectedTipeSesi = value);
          _loadData();
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
                ]
              : [],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '($sub)',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isSelesai ? const Color(0xFF16A34A) : (exists ? const Color(0xFFEAB308) : const Color(0xFFCBD5E1)),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  status['label'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isSelesai ? const Color(0xFF15803D) : (exists ? const Color(0xFFB45309) : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  // --- 3. CATEGORY PILLS BAR (Non-Scrollable 4-Segment Bar) ---
  Widget _buildCategoryPillsBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: List.generate(_categories.length, (index) {
            final cat = _categories[index];
            final short = cat['short'] as String;
            final icon = cat['icon'] as IconData;
            final isSelected = _selectedCategoryIndex == index;
            final count = _getItemsForCategory(cat['code']!).length;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedCategoryIndex = index);
                    _tabController.animateTo(index);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: 14,
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          short,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                            color: isSelected ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : (count > 0 ? const Color(0xFFE2E8F0) : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$count',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // --- 4. EMPTY STATE ---
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fact_check_outlined, size: 40, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 14),
            Text(
              'Belum Ada Sesi Opname',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 5),
            Text(
              'Belum ada data checklist stok opname untuk cabang dan periode yang dipilih.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // --- 5. ITEM LIST VIEW PER CATEGORY ---
  Widget _buildItemListView(String kategoriKode) {
    final filtered = _getItemsForCategory(kategoriKode);
    final catMap = _categories.firstWhere((c) => c['code'] == kategoriKode, orElse: () => _categories.first);
    final fullName = '${catMap['label']} ($kategoriKode)';
    final catIcon = catMap['icon'] as IconData;

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(catIcon, size: 40, color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 14),
              Text(
                'Belum Ada Checklist $fullName',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 5),
              Text(
                'Belum ada data checklist untuk kategori $fullName pada sesi terpilih.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12, height: 1.4),
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
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
    final kondisi = (item['kondisi'] ?? 'Baik').toString();

    final String fotoAktual = _getImageUrl(
      item['foto_path'] ?? item['foto_item'] ?? item['foto'] ?? item['foto_url'],
    );
    final String fotoAwal = _getImageUrl(
      itemFisik['foto_path'] ?? itemFisik['foto'] ?? barang['foto'] ?? barang['foto_path'],
    );

    final keterangan = item['keterangan'] ?? '-';

    Color kondisiColor = const Color(0xFF059669);
    Color kondisiBg = const Color(0xFFDCFCE7);

    if (kondisi.toLowerCase().contains('service') || kondisi.toLowerCase().contains('diservice')) {
      kondisiColor = const Color(0xFF0D9488);
      kondisiBg = const Color(0xFFCCFBF1);
    } else if (kondisi.toLowerCase() == 'rusak') {
      kondisiColor = const Color(0xFFDC2626);
      kondisiBg = const Color(0xFFFEE2E2);
    } else if (kondisi.toLowerCase() == 'hilang') {
      kondisiColor = const Color(0xFFD97706);
      kondisiBg = const Color(0xFFFEF3C7);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1E293B).withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: QR Code & Condition Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 13, color: Color(0xFF475569)),
                    const SizedBox(width: 4),
                    Text(
                      kodeQr,
                      style: GoogleFonts.firaCode(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: kondisiBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  kondisi.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: kondisiColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Item Name & Time
          Text(
            namaAlat,
            style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                'Waktu Checklist: $waktu',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
              ),
            ],
          ),

          // Photos Row
          if (fotoAktual.isNotEmpty || fotoAwal.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (fotoAktual.isNotEmpty)
                  Expanded(child: _buildPhotoThumbnail(url: fotoAktual, title: 'Foto Bukti Aktual', label: 'AKTUAL', isAktual: true)),
                if (fotoAktual.isNotEmpty && fotoAwal.isNotEmpty) const SizedBox(width: 8),
                if (fotoAwal.isNotEmpty)
                  Expanded(child: _buildPhotoThumbnail(url: fotoAwal, title: 'Foto Master Barang', label: 'MASTER', isAktual: false)),
              ],
            ),
          ],

          if (keterangan.isNotEmpty && keterangan != '-') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Catatan: $keterangan',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569), fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- BHP CARD (100% Web Parity) ---
  Widget _buildBhpCard(dynamic item) {
    final barang = item['barang'] ?? {};
    final pembelianBhp = item['pembelian_bhp'] ?? {};
    final kodeBhp = pembelianBhp['kode_pembelian'] ?? barang['kode_barang'] ?? '-';
    final namaBarang = barang['nama_barang'] ?? pembelianBhp['nama_barang'] ?? 'BHP Item';
    final merkBarang = pembelianBhp['merk_barang'] ?? '';
    final toko = pembelianBhp['toko_pembelian'] ?? '-';
    final tglBeli = pembelianBhp['tanggal_pembelian'] != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.tryParse(pembelianBhp['tanggal_pembelian'].toString()) ?? DateTime.now())
        : '-';
    final dynamic qtyBeli = pembelianBhp['qty'] ?? '-';
    final dynamic sisaAkhir = item['sisa_akhir'] ?? item['jumlah_fisik'] ?? item['stok_aktual'] ?? '-';
    final satuan = barang['satuan'] ?? pembelianBhp['satuan'] ?? 'pcs';

    final String fotoBhp = _getImageUrl(
      item['foto_path'] ?? item['foto_kuantitas'] ?? item['foto'] ?? item['foto_url'] ?? barang['foto'],
    );
    final keterangan = item['keterangan'] ?? '-';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1.2),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1E293B).withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Kode & Qty Beli
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  kodeBhp,
                  style: GoogleFonts.firaCode(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  'Qty Beli: $qtyBeli $satuan',
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Item Name & Merk
          Text(
            '$namaBarang ${merkBarang.isNotEmpty ? '($merkBarang)' : ''}',
            style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 3),

          // Toko & Tgl Pembelian
          Row(
            children: [
              const Icon(Icons.storefront_rounded, size: 12, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text('Toko: $toko', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
              const SizedBox(width: 8),
              const Icon(Icons.calendar_today_rounded, size: 10, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(tglBeli, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
            ],
          ),

          const SizedBox(height: 10),

          // Sisa Akhir Opname Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SISA FISIK DIOPNAME',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0284C7),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$sisaAkhir $satuan',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0369A1),
                      ),
                    ),
                  ],
                ),
                if (fotoBhp.isNotEmpty) ...[
                  _buildSmallThumbnail(fotoBhp),
                ],
              ],
            ),
          ),

          if (keterangan != '-' && keterangan.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Catatan: $keterangan', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail({
    required String url,
    required String title,
    required String label,
    required bool isAktual,
  }) {
    return InkWell(
      onTap: () => _showPhotoDialog(url),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isAktual ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                headers: _authToken != null ? {'Authorization': 'Bearer $_authToken'} : null,
                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 20)),
              ),
              Positioned(
                bottom: 3,
                left: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isAktual ? const Color(0xFF0284C7) : Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(label, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallThumbnail(String url) {
    return InkWell(
      onTap: () => _showPhotoDialog(url),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFBAE6FD)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, size: 18, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  void _showPhotoDialog(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(url, fit: BoxFit.contain),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }
}
