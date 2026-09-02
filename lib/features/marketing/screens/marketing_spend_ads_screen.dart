import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/animated_notification_bell.dart';
import '../services/marketing_service.dart';

class MarketingSpendAdsScreen extends StatefulWidget {
  const MarketingSpendAdsScreen({super.key});

  @override
  State<MarketingSpendAdsScreen> createState() => _MarketingSpendAdsScreenState();
}

class _MarketingSpendAdsScreenState extends State<MarketingSpendAdsScreen> {
  final MarketingService _service = MarketingService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = true;
  String _userName = 'Marketing';
  DateTime _selectedPeriode = DateTime.now();
  String _selectedPlatform = 'all';

  List<dynamic> _spendAdsList = [];
  Map<String, dynamic> _summary = {};

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadUser();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userName = prefs.getString('user_name') ?? 'Marketing';
      });
    }
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final periodeStr = DateFormat('yyyy-MM').format(_selectedPeriode);
      final res = await _service.fetchSpendAds(
        periode: periodeStr,
        platform: _selectedPlatform == 'all' ? null : _selectedPlatform,
        search: _searchController.text.trim(),
      );

      if (res['status'] == true && res['data'] != null) {
        final dataObj = res['data'];
        List<dynamic> list = [];
        Map<String, dynamic> sum = {};

        if (dataObj is Map) {
          final rawList = dataObj['spend_ads'];
          if (rawList is List) {
            list = rawList;
          } else if (rawList is Map && rawList['data'] is List) {
            list = rawList['data'];
          } else if (dataObj['data'] is List) {
            list = dataObj['data'];
          }
          if (dataObj['summary'] is Map) {
            sum = Map<String, dynamic>.from(dataObj['summary']);
          }
        } else if (dataObj is List) {
          list = dataObj;
        }

        if (mounted) {
          setState(() {
            _spendAdsList = list;
            _summary = sum;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickPeriodeMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedPeriode,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      helpText: 'PILIH BULAN & TAHUN PERIODE',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedPeriode = picked;
      });
      _fetchData();
    }
  }

  void _openSpendAdFormSheet({dynamic item}) {
    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SpendAdsModalSheet(
        item: item,
        initialPeriode: _selectedPeriode,
        onSuccess: _fetchData,
      ),
    );
  }

  Future<void> _confirmDelete(dynamic item) async {
    final id = item['id'];
    final cabangName = item['cabang']?['nama_cabang'] ?? 'Cabang';
    final platform = (item['platform'] ?? '').toString().toUpperCase();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Data Spend Ads?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Yakin ingin menghapus spend ads $platform untuk cabang $cabangName?', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _service.deleteSpendAd(id);
      if (mounted) {
        if (res['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data spend ads berhasil dihapus'), backgroundColor: Color(0xFF059669)),
          );
          _fetchData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Gagal menghapus data'), backgroundColor: const Color(0xFFDC2626)),
          );
        }
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  String _getFormattedDate() {
    final dt = DateTime.now();
    final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy', 'id_ID').format(_selectedPeriode);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSpendAdFormSheet(),
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text('Tambah Spend Ads', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: const Color(0xFF059669),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. GRADIENT HEADER
            SliverToBoxAdapter(child: _buildHeader(context)),

            // 2. MAIN CONTENT
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Summary Cards Carousel / Grid
                  _buildSummaryCardsSection(monthName),
                  const SizedBox(height: 18),

                  // Filter & Search Controls
                  _buildFilterAndSearchSection(),
                  const SizedBox(height: 14),

                  // Spend Ads Data List
                  if (_isLoading)
                    _buildLoadingList()
                  else if (_spendAdsList.isEmpty)
                    _buildEmptyState()
                  else
                    ..._spendAdsList.map((item) => _buildSpendAdCard(item)),

                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 1. HEADER =================
  Widget _buildHeader(BuildContext context) {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset('assets/images/logo.png', height: 22),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AnimatedNotificationBell(size: 24),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getFormattedDate(),
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_getGreeting()},',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          Text(
            '$_userName ✨',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Kelola laporan spend ads & pengeluaran iklan cabang.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  // ================= 2. SUMMARY CARDS =================
  Widget _buildSummaryCardsSection(String monthName) {
    final sumGoogle = double.tryParse(_summary['sum_google']?.toString() ?? '0') ?? 0;
    final sumMeta = double.tryParse(_summary['sum_meta']?.toString() ?? '0') ?? 0;
    final sumTiktok = double.tryParse(_summary['sum_tiktok']?.toString() ?? '0') ?? 0;
    final totalSpend = double.tryParse(_summary['total_spend']?.toString() ?? '0') ?? (sumGoogle + sumMeta + sumTiktok);
    final totalPlusPajak = double.tryParse(_summary['total_termasuk_pajak']?.toString() ?? '0') ?? (totalSpend * 1.12);

    return Column(
      children: [
        // 3 Cards per Platform
        Row(
          children: [
            Expanded(
              child: _buildPlatformCard(
                platform: 'Google Ads',
                subtitle: 'Platform Google',
                nominal: _currencyFormat.format(sumGoogle),
                color: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
                borderColor: const Color(0xFFA7F3D0),
                icon: Icons.language_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPlatformCard(
                platform: 'Meta Ads',
                subtitle: 'Platform Meta (FB/IG)',
                nominal: _currencyFormat.format(sumMeta),
                color: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                borderColor: const Color(0xFFBFDBFE),
                icon: Icons.hub_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPlatformCard(
                platform: 'TikTok Ads',
                subtitle: 'Platform TikTok',
                nominal: _currencyFormat.format(sumTiktok),
                color: const Color(0xFF0F172A),
                bgColor: const Color(0xFFF1F5F9),
                borderColor: const Color(0xFFCBD5E1),
                icon: Icons.music_note_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Total Banner Card (+ Tax 12%)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Pengeluaran Iklan ($monthName)',
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currencyFormat.format(totalSpend),
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '+ Pajak 12%',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                    ),
                    Text(
                      _currencyFormat.format(totalPlusPajak),
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: const Color(0xFF059669)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformCard({
    required String platform,
    required String subtitle,
    required String nominal,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  platform,
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            nominal,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 9.5, color: color.withValues(alpha: 0.8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ================= 3. FILTER & SEARCH =================
  Widget _buildFilterAndSearchSection() {
    final monthStr = DateFormat('MMMM yyyy', 'id_ID').format(_selectedPeriode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Data Spend Ads Cabang',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            // Periode Selector Button
            InkWell(
              onTap: _pickPeriodeMonth,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF2563EB)),
                    const SizedBox(width: 5),
                    Text(
                      monthStr,
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Search Bar
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Cari nama cabang...',
              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12.5),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                      onPressed: () {
                        _searchController.clear();
                        _fetchData();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Platform Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('all', 'Semua Platform'),
              const SizedBox(width: 8),
              _buildFilterChip('google', 'Google Ads'),
              const SizedBox(width: 8),
              _buildFilterChip('meta', 'Meta Ads'),
              const SizedBox(width: 8),
              _buildFilterChip('tiktok', 'TikTok Ads'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedPlatform == key;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF059669),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
        ),
      ),
      showCheckmark: false,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedPlatform = key);
          _fetchData();
        }
      },
    );
  }

  // ================= 4. SPEND AD CARD =================
  Widget _buildSpendAdCard(dynamic item) {
    final cabang = item['cabang'];
    final cabangName = cabang?['nama_cabang'] ?? 'Cabang';
    final periode = item['periode'] ?? '-';
    final platform = (item['platform'] ?? '').toString().toLowerCase();
    final nominal = double.tryParse(item['nominal']?.toString() ?? '0') ?? 0;

    Color badgeColor = const Color(0xFF059669);
    Color badgeBg = const Color(0xFFECFDF5);
    String platformLabel = 'GOOGLE';
    IconData platformIcon = Icons.language_rounded;

    if (platform == 'meta') {
      badgeColor = const Color(0xFF2563EB);
      badgeBg = const Color(0xFFEFF6FF);
      platformLabel = 'META';
      platformIcon = Icons.hub_rounded;
    } else if (platform == 'tiktok') {
      badgeColor = const Color(0xFF0F172A);
      badgeBg = const Color(0xFFF1F5F9);
      platformLabel = 'TIKTOK';
      platformIcon = Icons.music_note_rounded;
    }

    String formattedPeriode = periode;
    try {
      final parts = periode.split('-');
      if (parts.length == 2) {
        final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
        formattedPeriode = DateFormat('MMMM yyyy', 'id_ID').format(dt);
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Cabang Name + Platform Badge & Nominal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          cabangName,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(platformIcon, size: 10, color: badgeColor),
                            const SizedBox(width: 3),
                            Text(
                              platformLabel,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _currencyFormat.format(nominal),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Bottom Row: Periode on left, full Edit & Hapus Buttons on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_note_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 5),
                    Text(
                      formattedPeriode,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Edit Button
                    InkWell(
                      onTap: () => _openSpendAdFormSheet(item: item),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_rounded, size: 13, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Text(
                              'Edit',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Hapus Button
                    InkWell(
                      onTap: () => _confirmDelete(item),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.delete_outline_rounded, size: 13, color: Color(0xFFDC2626)),
                            const SizedBox(width: 4),
                            Text(
                              'Hapus',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFDC2626),
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
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingList() {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          height: 75,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.payments_outlined, size: 36, color: Color(0xFF059669)),
          ),
          const SizedBox(height: 14),
          Text(
            'Belum Ada Data Spend Ads',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            'Belum ada laporan pengeluaran iklan untuk periode ini.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

// ================= 5. TAMBAH / EDIT SPEND ADS MODAL SHEET =================
class _SpendAdsModalSheet extends StatefulWidget {
  final dynamic item;
  final DateTime initialPeriode;
  final VoidCallback onSuccess;

  const _SpendAdsModalSheet({
    this.item,
    required this.initialPeriode,
    required this.onSuccess,
  });

  @override
  State<_SpendAdsModalSheet> createState() => _SpendAdsModalSheetState();
}

class _SpendAdsModalSheetState extends State<_SpendAdsModalSheet> {
  final MarketingService _service = MarketingService();
  final _nominalController = TextEditingController();

  List<dynamic> _cabangs = [];
  bool _isLoadingCabangs = true;
  bool _isSaving = false;

  int? _selectedCabangId;
  late DateTime _selectedPeriode;
  String _selectedPlatform = 'google';

  @override
  void initState() {
    super.initState();
    _selectedPeriode = widget.initialPeriode;

    if (widget.item != null) {
      _selectedCabangId = widget.item['cabang_id'];
      _selectedPlatform = (widget.item['platform'] ?? 'google').toString().toLowerCase();
      _nominalController.text = (widget.item['nominal'] ?? '').toString();

      final periodeStr = widget.item['periode']?.toString();
      if (periodeStr != null && periodeStr.contains('-')) {
        final parts = periodeStr.split('-');
        if (parts.length == 2) {
          _selectedPeriode = DateTime(int.parse(parts[0]), int.parse(parts[1]));
        }
      }
    }

    _loadCabangs();
  }

  @override
  void dispose() {
    _nominalController.dispose();
    super.dispose();
  }

  Future<void> _loadCabangs() async {
    final list = await _service.fetchCabangs();
    if (mounted) {
      setState(() {
        _cabangs = list;
        _isLoadingCabangs = false;
        if (_selectedCabangId == null && _cabangs.isNotEmpty) {
          _selectedCabangId = _cabangs.first['id'];
        }
      });
    }
  }

  Future<void> _pickPeriodeMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedPeriode,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      helpText: 'PILIH PERIODE IKLAN',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedPeriode = picked;
      });
    }
  }

  Future<void> _submitData() async {
    if (_selectedCabangId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih cabang!'), backgroundColor: Colors.red),
      );
      return;
    }

    final nominal = double.tryParse(_nominalController.text.trim()) ?? 0;
    if (nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal harus lebih besar dari 0!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    final periodeStr = DateFormat('yyyy-MM').format(_selectedPeriode);

    final payload = {
      'cabang_id': _selectedCabangId,
      'periode': periodeStr,
      'platform': _selectedPlatform,
      'nominal': nominal,
    };

    Map<String, dynamic> res;
    if (widget.item != null) {
      res = await _service.updateSpendAd(widget.item['id'], payload);
    } else {
      res = await _service.storeSpendAd(payload);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (res['status'] == true) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.item != null ? 'Spend Ads berhasil diperbarui' : 'Spend Ads berhasil ditambahkan'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal menyimpan data'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final periodeFormatted = DateFormat('MMMM yyyy', 'id_ID').format(_selectedPeriode);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),

            // Header Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.attach_money_rounded, color: Color(0xFF059669), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEdit ? 'Edit Spend Ads' : 'Tambah Spend Ads',
                      style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 14),

            // 1. Cabang Dropdown
            Text('Cabang *', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            _isLoadingCabangs
                ? const LinearProgressIndicator()
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedCabangId,
                        isExpanded: true,
                        hint: Text('Pilih Cabang', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
                        items: _cabangs.map<DropdownMenuItem<int>>((c) {
                          return DropdownMenuItem<int>(
                            value: c['id'],
                            child: Text(c['nama_cabang'] ?? '-', style: GoogleFonts.inter(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedCabangId = val),
                      ),
                    ),
                  ),
            const SizedBox(height: 14),

            // 2. Periode Picker
            Text('Periode *', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickPeriodeMonth,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(periodeFormatted, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A))),
                    const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 3. Platform Dropdown
            Text('Platform *', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPlatform,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'google', child: Text('Google Ads')),
                    DropdownMenuItem(value: 'meta', child: Text('Meta Ads (FB/IG)')),
                    DropdownMenuItem(value: 'tiktok', child: Text('TikTok Ads')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedPlatform = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 4. Nominal Input
            Text('Nominal *', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            TextField(
              controller: _nominalController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                hintText: '0',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 4),
            Text('ⓘ Belum termasuk pajak 12%', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
            const SizedBox(height: 20),

            // 5. Actions (Batal & Simpan)
            if (_isSaving)
              const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
            else
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Batal', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: _submitData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Simpan Data', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
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
