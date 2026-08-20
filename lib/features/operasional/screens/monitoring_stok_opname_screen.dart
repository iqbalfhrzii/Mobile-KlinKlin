import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      'icon': Icons.precision_manufacturing_rounded,
    },
    {
      'code': 'CLA',
      'label': 'Cleaning Alat',
      'icon': Icons.cleaning_services_rounded,
    },
    {
      'code': 'BHP',
      'label': 'Barang Habis Pakai',
      'icon': Icons.inventory_2_rounded,
    },
    {
      'code': 'INV',
      'label': 'Inventaris',
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
      final String formattedPeriode = DateFormat('yyyy-MM').format(_selectedPeriode);

      // Get all sessions for this branch & month
      final sessions = await OperasionalStokOpnameService.getSessions(
        cabangId: _selectedCabangId,
        periodeBulan: formattedPeriode,
      );

      _allMonthSessions = sessions;

      // Find session matching currently active tab
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
      'label': isSelesai ? 'Selesai' : 'Belum Selesai',
      'isSelesai': isSelesai,
      'exists': true,
    };
  }

  String _getImageUrl(dynamic rawPath) {
    if (rawPath == null) return '';
    String p = rawPath.toString().trim().replaceAll(r'\', '/');
    if (p.isEmpty || p == 'null') return '';
    if (p.startsWith('http://') || p.startsWith('https://')) return p;

    // Extract baseDomain from ApiClient
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
                const AppBackButton(),
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

          // Session Type Tabs: Awal Bulan vs Akhir Bulan (Segmented Control)
          _buildTipeSesiSelector(),

          // Main Content View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _currentSession == null
                    ? _buildEmptyState()
                    : Column(
                        children: [
                          // Modern Elevated Category Chips
                          _buildModernCategorySelector(),

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

  // --- MODERN CATEGORY FILTER (Responsive 4-Column Single Label) ---
  Widget _buildModernCategorySelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
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
            final count = _getItemsForCategory(cat['code']!).length;
            final isSelected = _selectedCategoryIndex == index;

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
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          cat['code'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                            color: isSelected ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : (count > 0 ? AppColors.primary.withValues(alpha: 0.12) : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? AppColors.primary
                                  : (count > 0 ? AppColors.primary : const Color(0xFF64748B)),
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

  // --- FILTER BAR: PERIODE & CABANG ---
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
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
                    const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        DateFormat('MMMM yyyy').format(_selectedPeriode),
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
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
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                  items: _cabangs.map((c) {
                    return DropdownMenuItem<int>(
                      value: c['id'] as int,
                      child: Text(
                        c['nama_cabang'] ?? '-',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
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

  // --- TIPE SESI SELECTOR (With Status Badges: Selesai / Belum) ---
  Widget _buildTipeSesiSelector() {
    final statusAwal = _getSessionStatus('tengah_bulan');
    final statusAkhir = _getSessionStatus('akhir_bulan');

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildSesiSegment(
                value: 'tengah_bulan',
                title: 'Awal Bulan',
                status: statusAwal,
                icon: Icons.event_available_rounded,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildSesiSegment(
                value: 'akhir_bulan',
                title: 'Akhir Bulan',
                status: statusAkhir,
                icon: Icons.event_note_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSesiSegment({
    required String value,
    required String title,
    required Map<String, dynamic> status,
    required IconData icon,
  }) {
    final isSelected = _selectedTipeSesi == value;
    final bool isSelesai = status['isSelesai'] == true;
    final bool exists = status['exists'] == true;
    final String statusLabel = status['label'] as String;

    return InkWell(
      onTap: () {
        if (_selectedTipeSesi != value) {
          setState(() => _selectedTipeSesi = value);
          _loadData();
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
                const SizedBox(width: 5),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isSelesai
                        ? const Color(0xFFDCFCE7)
                        : (exists ? const Color(0xFFFEF3C7) : Colors.white.withValues(alpha: 0.2)))
                    : (isSelesai
                        ? const Color(0xFFDCFCE7)
                        : (exists ? const Color(0xFFFEF3C7) : const Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelesai
                        ? Icons.check_circle_rounded
                        : (exists ? Icons.access_time_filled_rounded : Icons.remove_circle_outline_rounded),
                    size: 10,
                    color: isSelesai
                        ? const Color(0xFF15803D)
                        : (exists ? const Color(0xFFB45309) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: isSelesai
                          ? const Color(0xFF15803D)
                          : (exists ? const Color(0xFFB45309) : const Color(0xFF64748B)),
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

  String _getCategoryFullName(String code) {
    switch (code) {
      case 'MSN':
        return 'Mesin Alat (MSN)';
      case 'CLA':
        return 'Cleaning Alat (CLA)';
      case 'BHP':
        return 'Barang Habis Pakai (BHP)';
      case 'INV':
        return 'Inventaris (INV)';
      default:
        return code;
    }
  }

  IconData _getCategoryIcon(String code) {
    switch (code) {
      case 'MSN':
        return Icons.precision_manufacturing_rounded;
      case 'CLA':
        return Icons.cleaning_services_rounded;
      case 'BHP':
        return Icons.inventory_2_rounded;
      case 'INV':
        return Icons.home_repair_service_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  // --- ITEM LIST VIEW PER CATEGORY ---
  Widget _buildItemListView(String kategoriKode) {
    final filtered = _getItemsForCategory(kategoriKode);
    final fullName = _getCategoryFullName(kategoriKode);
    final catIcon = _getCategoryIcon(kategoriKode);

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
                child: Icon(catIcon, size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'Belum Ada Checklist $fullName',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Belum ada data checklist untuk kategori $fullName dari tim CS pada periode terpilih.',
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: filtered.length + 1,
        separatorBuilder: (_, index) => index == 0 ? const SizedBox(height: 8) : const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            // Category Full Name Header
            return Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(catIcon, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        fullName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${filtered.length} Data',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            );
          }
          final item = filtered[index - 1];
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
    Color kondisiBorder = const Color(0xFF86EFAC);

    if (kondisi.toLowerCase() == 'rusak') {
      kondisiColor = const Color(0xFFDC2626);
      kondisiBg = const Color(0xFFFEE2E2);
      kondisiBorder = const Color(0xFFFCA5A5);
    } else if (kondisi.toLowerCase() == 'hilang') {
      kondisiColor = const Color(0xFFD97706);
      kondisiBg = const Color(0xFFFEF3C7);
      kondisiBorder = const Color(0xFFFCD34D);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: QR Code & Kondisi Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 14, color: Color(0xFF475569)),
                      const SizedBox(width: 5),
                      Text(
                        kodeQr,
                        style: GoogleFonts.firaCode(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kondisiBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kondisiBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: kondisiColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        kondisi.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: kondisiColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Item Name & Time
            Text(
              namaAlat,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  waktu,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Photos Row (Aktual & Awal side-by-side)
            Row(
              children: [
                if (fotoAktual.isNotEmpty) ...[
                  Expanded(
                    child: _buildPhotoThumbnailBox(
                      url: fotoAktual,
                      title: 'Foto Aktual',
                      badge: 'AKTUAL',
                      badgeColor: AppColors.primary,
                    ),
                  ),
                ],
                if (fotoAktual.isNotEmpty && fotoAwal.isNotEmpty)
                  const SizedBox(width: 10),
                if (fotoAwal.isNotEmpty) ...[
                  Expanded(
                    child: _buildPhotoThumbnailBox(
                      url: fotoAwal,
                      title: 'Foto Master',
                      badge: 'AWAL',
                      badgeColor: const Color(0xFF64748B),
                    ),
                  ),
                ],
                if (fotoAktual.isEmpty && fotoAwal.isEmpty)
                  Expanded(
                    child: _buildEmptyPhotoBox(),
                  ),
              ],
            ),

            // Catatan
            if (keterangan != '-' && keterangan.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.comment_outlined, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Catatan: $keterangan',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category tag & Sisa Aktual Highlight
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    'BARANG HABIS PAKAI (BHP)',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF1D4ED8)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 13, color: Color(0xFF059669)),
                      const SizedBox(width: 4),
                      Text(
                        'Sisa: $sisaAkhir $satuan',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF059669)),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Item Name & Time
            Text(
              namaBarang,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  waktu,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                ),
              ],
            ),

            if (fotoBhp.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildPhotoThumbnailBox(
                url: fotoBhp,
                title: 'Foto Sisa Barang',
                badge: 'FOTO AKTUAL',
                badgeColor: AppColors.primary,
              ),
            ],

            if (keterangan != '-' && keterangan.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.comment_outlined, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Catatan: $keterangan',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnailBox({
    required String url,
    required String title,
    required String badge,
    required Color badgeColor,
  }) {
    return InkWell(
      onTap: () => _showFullImage(url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 100,
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
                child: SmartNetworkImage(
                  url: url,
                  token: _authToken,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPhotoBox() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported_outlined, color: Color(0xFF94A3B8), size: 18),
            const SizedBox(width: 8),
            Text(
              'Tidak ada foto',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
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
                child: SmartNetworkImage(
                  url: url,
                  token: _authToken,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
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
                          'Gagal memuat gambar',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          url,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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

// --- SMART NETWORK IMAGE WITH AUTO HTTP/HTTPS FALLBACK & AUTH HEADERS ---
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
          const Center(child: Icon(Icons.image_not_supported_rounded, color: Color(0xFF94A3B8), size: 24));
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
            const Center(child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 24));
      },
    );
  }
}
