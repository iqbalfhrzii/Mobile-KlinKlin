import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/data/order_model.dart';
import '../../../core/data/hrd_models.dart';
import '../../orders/services/order_service.dart';
import '../../hrd/services/hrd_service.dart';
class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({super.key});

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  final OrderService _orderService = OrderService();
  final HrdService _hrdService = HrdService();

  String _userName = 'Finance';
  List<OrderModel> _orders = [];
  List<CabangModel> _cabangs = [];
  bool _isLoading = true;
  String _error = '';

  // Primary Tabs in Capaian: 'omzet', 'kpi', 'marketing'
  String _mainTab = 'omzet';

  // Secondary Sub-Tabs in Omzet View: 'omzet_cabang', 'ringkasan_layanan', 'detail_layanan', 'statistik'
  String _subTab = 'omzet_cabang';

  // Branch View Format: 'cards' (Mobile Cards) vs 'table' (Compact Table)
  bool _useTableView = false;

  // Period Filter: 'semua' (Bulan Ini), 'kemarin', 'hari_ini', 'besok', 'custom'
  String _periode = 'semua';
  DateTimeRange? _customRange;

  // Marketing Search
  String _marketingQuery = '';

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _fetchData();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userName = prefs.getString('user_name') ?? 'Finance';
      });
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final ordersData = await _orderService.fetchOrders();
      List<CabangModel> cabangsData = [];
      try {
        cabangsData = await _hrdService.fetchCabang();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _orders = ordersData;
          _cabangs = cabangsData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // --- Helper Date Calculation matching CapaianPage.php ---
  Map<String, DateTime> _getPeriodDates() {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    if (_periode == 'hari_ini') {
      startDate = DateTime(now.year, now.month, now.day);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_periode == 'kemarin') {
      final yesterday = now.subtract(const Duration(days: 1));
      startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
      endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
    } else if (_periode == 'besok') {
      final tomorrow = now.add(const Duration(days: 1));
      startDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
      endDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 23, 59, 59);
    } else if (_periode == 'custom' && _customRange != null) {
      startDate = DateTime(_customRange!.start.year, _customRange!.start.month, _customRange!.start.day);
      endDate = DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day, 23, 59, 59);
    } else {
      // 'semua' / 'bulan_ini'
      startDate = DateTime(now.year, now.month, 1);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    }

    // Pembanding (-1 month)
    final compStartDate = DateTime(
      startDate.month == 1 ? startDate.year - 1 : startDate.year,
      startDate.month == 1 ? 12 : startDate.month - 1,
      startDate.day,
    );
    final compEndDate = DateTime(
      endDate.month == 1 ? endDate.year - 1 : endDate.year,
      endDate.month == 1 ? 12 : endDate.month - 1,
      endDate.day,
      endDate.hour,
      endDate.minute,
      endDate.second,
    );

    return {
      'startDate': startDate,
      'endDate': endDate,
      'compStartDate': compStartDate,
      'compEndDate': compEndDate,
    };
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error.isNotEmpty)
                      _buildErrorWidget()
                    else
                      _buildCapaianSection(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Header ---
  Widget _buildHeader() {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selamat Datang,',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userName,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Finance',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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
    );
  }

  // --- ERROR WIDGET ---
  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 40),
            const SizedBox(height: 10),
            Text(_error, style: GoogleFonts.inter(color: AppColors.error)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 1: CAPAIAN & LAPORAN KINERJA (Matching Laravel CapaianPage)
  // ===========================================================================
  Widget _buildCapaianSection() {
    final dates = _getPeriodDates();
    final startDate = dates['startDate']!;
    final endDate = dates['endDate']!;
    final compStartDate = dates['compStartDate']!;
    final compEndDate = dates['compEndDate']!;

    // Filter orders in range
    final periodOrders = _orders.where((o) =>
      !o.tanggalInput.isBefore(startDate) && !o.tanggalInput.isAfter(endDate)
    ).toList();

    final compOrders = _orders.where((o) =>
      !o.tanggalInput.isBefore(compStartDate) && !o.tanggalInput.isAfter(compEndDate)
    ).toList();

    // Top Cards Math
    final omzetThis = periodOrders.where((o) => o.status != OrderStatus.draft && o.status != OrderStatus.cancelled).fold<int>(0, (sum, o) => sum + o.subtotal);
    final omzetLast = compOrders.where((o) => o.status != OrderStatus.draft && o.status != OrderStatus.cancelled).fold<int>(0, (sum, o) => sum + o.subtotal);
    final growthVal = omzetThis - omzetLast;
    final growthPct = omzetLast > 0 ? (growthVal / omzetLast) * 100 : (omzetThis > 0 ? 100.0 : 0.0);
    final cancelCount = periodOrders.where((o) => o.status == OrderStatus.cancelled).length;
    final totalOrdersCount = periodOrders.length;

    final dateFormat = DateFormat('dd MMMM yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Order Count Badge Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.analytics_rounded, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Capaian & Laporan Kinerja',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$totalOrdersCount Order',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Laporan kinerja pendapatan, evaluasi KPI, dan performa pemasaran per cabang.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Primary Tabs (Omzet | KPI | Marketing)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildMainTabButton('Omzet', Icons.payments_outlined, 'omzet'),
              _buildMainTabButton('KPI', Icons.pie_chart_outline_rounded, 'kpi'),
              _buildMainTabButton('Marketing', Icons.campaign_outlined, 'marketing'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (_mainTab == 'omzet') ...[
          _buildMonthPicker(),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [

                _buildPeriodChip('Kemarin', 'kemarin'),
                const SizedBox(width: 8),
                _buildPeriodChip('Hari Ini', 'hari_ini'),
                const SizedBox(width: 8),
                _buildPeriodChip('Besok', 'besok'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Periode Info Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Periode Laporan: ${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E40AF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: Text(
                    'Pembanding (-1 bulan): ${dateFormat.format(compStartDate)} - ${dateFormat.format(compEndDate)}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4 Summary Metrics Cards
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.35,
            children: [
              _buildMetricCard(
                title: 'OMZET PERIODE INI',
                value: _currencyFormat.format(omzetThis),
                color: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
                icon: Icons.account_balance_rounded,
              ),
              _buildMetricCard(
                title: 'OMZET PERIODE LALU',
                value: _currencyFormat.format(omzetLast),
                color: const Color(0xFF4B5563),
                bgColor: Colors.white,
                icon: Icons.history_rounded,
              ),
              _buildMetricCard(
                title: 'GROWTH VS LALU',
                value: '${growthVal >= 0 ? '▲' : '▼'} ${_currencyFormat.format(growthVal.abs())}',
                subtitle: '${growthVal >= 0 ? '+' : ''}${growthPct.toStringAsFixed(1)}%',
                color: growthVal >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                bgColor: growthVal >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                icon: growthVal >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              ),
              _buildMetricCard(
                title: 'JUMLAH CANCEL',
                value: '$cancelCount Order',
                color: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEF2F2),
                icon: Icons.cancel_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildOmzetTabContent(periodOrders, compOrders),
        ] else if (_mainTab == 'kpi')
          _buildKpiTabContent(periodOrders)
        else
          _buildMarketingTabContent(periodOrders),
      ],
    );
  }

  // --- Main Tab Button ---
  Widget _buildMainTabButton(String label, IconData icon, String tabKey) {
    final bool isActive = _mainTab == tabKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _mainTab = tabKey;
            if (tabKey == 'omzet') _subTab = 'omzet_cabang';
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: isActive ? Colors.white : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  color: isActive ? Colors.white : AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  // --- Month Picker ---
  Widget _buildMonthPicker() {
    DateTime current;
    if (_periode == 'kemarin') {
      current = DateTime.now().subtract(const Duration(days: 1));
    } else if (_periode == 'besok') {
      current = DateTime.now().add(const Duration(days: 1));
    } else if (_periode == 'hari_ini') {
      current = DateTime.now();
    } else {
      current = _customRange?.start ?? DateTime.now();
    }
    
    final monthName = DateFormat('MMMM yyyy', 'id_ID').format(current);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.primary),
            onPressed: () {
              setState(() {
                final prev = DateTime(current.year, current.month - 1, 1);
                _periode = 'custom';
                _customRange = DateTimeRange(
                  start: prev,
                  end: DateTime(prev.year, prev.month + 1, 0, 23, 59, 59),
                );
              });
            },
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _periode = 'semua';
                _customRange = null;
              });
            },
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  monthName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.primary),
            onPressed: () {
              setState(() {
                final next = DateTime(current.year, current.month + 1, 1);
                _periode = 'custom';
                _customRange = DateTimeRange(
                  start: next,
                  end: DateTime(next.year, next.month + 1, 0, 23, 59, 59),
                );
              });
            },
          ),
        ],
      ),
    );
  }

  // --- Period Chip ---
  Widget _buildPeriodChip(String label, String value, {VoidCallback? onTap}) {
    final bool isSelected = _periode == value;
    return InkWell(
      onTap: onTap ?? () {
        setState(() {
          _periode = value;
          if (value == 'semua') _customRange = null;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  // --- Metric Card ---
  Widget _buildMetricCard({
    required String title,
    required String value,
    String? subtitle,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // OMZET TAB CONTENT (SubTabs 1..4 matching CapaianPage.blade.php)
  // ===========================================================================
  Widget _buildOmzetTabContent(List<OrderModel> periodOrders, List<OrderModel> compOrders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Secondary Sub-Tabs Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildSubTabButton('1. Omzet per Cabang', 'omzet_cabang'),
              const SizedBox(width: 8),
              _buildSubTabButton('2. Ringkasan Layanan', 'ringkasan_layanan'),
              const SizedBox(width: 8),
              _buildSubTabButton('3. Detail Layanan', 'detail_layanan'),
              const SizedBox(width: 8),
              _buildSubTabButton('4. Ranking & Visualisasi', 'statistik'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (_subTab == 'omzet_cabang')
          _buildMobileOmzetPerCabang(periodOrders, compOrders)
        else if (_subTab == 'ringkasan_layanan')
          _buildRingkasanLayananPerCabang(periodOrders)
        else if (_subTab == 'detail_layanan')
          _buildDetailOmzetPerLayanan(periodOrders)
        else
          _buildRankingVisualisasi(periodOrders),
      ],
    );
  }

  Widget _buildSubTabButton(String label, String key) {
    final bool isActive = _subTab == key;
    return InkWell(
      onTap: () => setState(() => _subTab = key),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? AppColors.primary : Colors.grey.shade300),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            color: isActive ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  // --- SUBTAB 1: Omzet per Cabang ---
  Widget _buildMobileOmzetPerCabang(List<OrderModel> periodOrders, List<OrderModel> compOrders) {
    List<String> sortedCabangNames = [];
    if (_cabangs.isNotEmpty) {
      sortedCabangNames = _cabangs
          .where((c) => !c.namaCabang.toLowerCase().contains('kantor pusat'))
          .map((c) => c.namaCabang.toUpperCase())
          .toList()..sort();
    }

    if (sortedCabangNames.isEmpty) {
      sortedCabangNames = ['BALIKPAPAN', 'DENPASAR', 'MAKASSAR', 'MALANG', 'SURABAYA'];
    }

    int totalPeriodIni = 0;
    int totalPeriodLalu = 0;
    int totalAds = 0;
    int totalOrganik = 0;
    int totalLama = 0;

    final List<Map<String, dynamic>> cabangRows = [];

    for (var name in sortedCabangNames) {
      final cThis = periodOrders.where((o) =>
        (o.customer.area.toUpperCase().contains(name) ||
        (_cabangs.any((c) => c.namaCabang.toUpperCase() == name && o.cabangId == c.id.toString()))) &&
        o.status != OrderStatus.draft && o.status != OrderStatus.cancelled
      ).toList();

      final cLast = compOrders.where((o) =>
        (o.customer.area.toUpperCase().contains(name) ||
        (_cabangs.any((c) => c.namaCabang.toUpperCase() == name && o.cabangId == c.id.toString()))) &&
        o.status != OrderStatus.draft && o.status != OrderStatus.cancelled
      ).toList();

      final pIni = cThis.fold<int>(0, (s, o) => s + o.subtotal);
      final pLalu = cLast.fold<int>(0, (s, o) => s + o.subtotal);
      final growth = pIni - pLalu;
      final growthPct = pLalu > 0 ? (growth / pLalu) * 100 : (pIni > 0 ? 100.0 : 0.0);

      final ads = cThis.where((o) => o.chatDari == ChatSource.ads).fold<int>(0, (s, o) => s + o.subtotal);
      final organik = cThis.where((o) => o.chatDari == ChatSource.organik).fold<int>(0, (s, o) => s + o.subtotal);
      final lama = cThis.where((o) => o.chatDari == ChatSource.lama || o.tipeCustomer == CustomerType.lama).fold<int>(0, (s, o) => s + o.subtotal);

      totalPeriodIni += pIni;
      totalPeriodLalu += pLalu;
      totalAds += ads;
      totalOrganik += organik;
      totalLama += lama;

      cabangRows.add({
        'nama': name,
        'periode_ini': pIni,
        'periode_lalu': pLalu,
        'growth_val': growth,
        'growth_pct': growthPct,
        'terakhir_update': cThis.isNotEmpty ? DateFormat('dd MMM yyyy').format(cThis.first.tanggalInput) : '-',
        'ads': ads,
        'organik': organik,
        'lama': lama,
      });
    }

    final totalGrowth = totalPeriodIni - totalPeriodLalu;
    final totalGrowthPct = totalPeriodLalu > 0 ? (totalGrowth / totalPeriodLalu) * 100 : (totalPeriodIni > 0 ? 100.0 : 0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tabel Omzet per Cabang',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            InkWell(
              onTap: () => setState(() => _useTableView = !_useTableView),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      _useTableView ? Icons.grid_view_rounded : Icons.table_chart_outlined,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _useTableView ? 'Tampilan Kartu' : 'Tampilan Tabel',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Company Total Mobile Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
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
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.corporate_fare_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'TOTAL SELURUH CABANG',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: totalGrowth >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${totalGrowth >= 0 ? '▲ +' : '▼ '}${totalGrowthPct.toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _currencyFormat.format(totalPeriodIni),
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTotalMetaItem('Periode Lalu', _currencyFormat.format(totalPeriodLalu)),
                  _buildTotalMetaItem('Ads', _currencyFormat.format(totalAds)),
                  _buildTotalMetaItem('Organik', _currencyFormat.format(totalOrganik)),
                  _buildTotalMetaItem('Lama', _currencyFormat.format(totalLama)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (_useTableView)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 14,
                headingRowHeight: 38,
                dataRowHeight: 46,
                columns: const [
                  DataColumn(label: Text('CABANG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataColumn(label: Text('PERIODE INI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataColumn(label: Text('PERIODE LALU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataColumn(label: Text('GROWTH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataColumn(label: Text('ADS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataColumn(label: Text('ORGANIK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  DataColumn(label: Text('LAMA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                ],
                rows: cabangRows.map((row) {
                  final gVal = row['growth_val'] as int;
                  final gPct = row['growth_pct'] as double;
                  return DataRow(cells: [
                    DataCell(Text(row['nama'], style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary))),
                    DataCell(Text(_currencyFormat.format(row['periode_ini']), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600))),
                    DataCell(Text(_currencyFormat.format(row['periode_lalu']), style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted))),
                    DataCell(Text('${gVal >= 0 ? '+' : ''}${gPct.toStringAsFixed(1)}%', style: GoogleFonts.inter(fontSize: 11, color: gVal >= 0 ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold))),
                    DataCell(Text(_currencyFormat.format(row['ads']), style: GoogleFonts.inter(fontSize: 11))),
                    DataCell(Text(_currencyFormat.format(row['organik']), style: GoogleFonts.inter(fontSize: 11))),
                    DataCell(Text(_currencyFormat.format(row['lama']), style: GoogleFonts.inter(fontSize: 11))),
                  ]);
                }).toList(),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cabangRows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final row = cabangRows[index];
              final pIni = row['periode_ini'] as int;
              final pLalu = row['periode_lalu'] as int;
              final gVal = row['growth_val'] as int;
              final gPct = row['growth_pct'] as double;
              final lastUpdate = row['terakhir_update'] as String;
              final ads = row['ads'] as int;
              final organik = row['organik'] as int;
              final lama = row['lama'] as int;
              final sharePct = totalPeriodIni > 0 ? (pIni / totalPeriodIni) * 100 : 0.0;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.18)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.storefront_rounded, size: 16, color: AppColors.primary),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              row['nama'],
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: gVal >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: gVal >= 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                          ),
                          child: Text(
                            '${gVal >= 0 ? '▲ +' : '▼ '}${gPct.toStringAsFixed(1)}%',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: gVal >= 0 ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _currencyFormat.format(pIni),
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF047857),
                          ),
                        ),
                        Text(
                          'Share: ${sharePct.toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (sharePct / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade100,
                        color: AppColors.primary,
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Periode Lalu', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                              Text(_currencyFormat.format(pLalu), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Terakhir Update', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                              Text(lastUpdate, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildSourcePill('Ads', ads, const Color(0xFF2563EB), Icons.ad_units_rounded),
                          const SizedBox(width: 6),
                          _buildSourcePill('Organik', organik, const Color(0xFF059669), Icons.eco_rounded),
                          const SizedBox(width: 6),
                          _buildSourcePill('Lama', lama, const Color(0xFF7C3AED), Icons.star_rounded),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTotalMetaItem(String label, String valStr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white70)),
        const SizedBox(height: 2),
        Text(valStr, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildSourcePill(String label, int val, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: ${_currencyFormat.format(val)}',
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // --- SUBTAB 2: Ringkasan Layanan per Cabang (Omzet ▲/▼ & Trx ▲/▼) ---
  Widget _buildRingkasanLayananPerCabang(List<OrderModel> periodOrders) {
    final validOrders = periodOrders.where((o) => o.status != OrderStatus.draft && o.status != OrderStatus.cancelled).toList();

    // Get list of cabangs to display
    List<String> sortedCabangNames = [];
    if (_cabangs.isNotEmpty) {
      sortedCabangNames = _cabangs
          .where((c) => !c.namaCabang.toLowerCase().contains('kantor pusat'))
          .map((c) => c.namaCabang.toUpperCase())
          .toList()..sort();
    }

    if (sortedCabangNames.isEmpty) {
      sortedCabangNames = ['BALIKPAPAN', 'DENPASAR', 'MAKASSAR', 'MALANG', 'SURABAYA'];
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan Layanan per Cabang',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedCabangNames.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final cabangName = sortedCabangNames[index];

              final cOrders = validOrders.where((o) =>
                o.customer.area.toUpperCase().contains(cabangName) ||
                (_cabangs.any((c) => c.namaCabang.toUpperCase() == cabangName && o.cabangId == c.id.toString()))
              ).toList();

              final Map<String, Map<String, dynamic>> svcStats = {};
              for (var o in cOrders) {
                for (var s in o.services) {
                  final name = s.name.isNotEmpty ? s.name : 'General Cleaning';
                  final int itemQty = int.tryParse(s.qty) ?? 1;
                  final int itemTotal = s.price * itemQty;
                  if (!svcStats.containsKey(name)) {
                    svcStats[name] = {'omzet': 0, 'count': 0};
                  }
                  svcStats[name]!['omzet'] = (svcStats[name]!['omzet'] as int) + itemTotal;
                  svcStats[name]!['count'] = (svcStats[name]!['count'] as int) + 1;
                }
              }

              String omzetMaxName = '-';
              int omzetMaxVal = 0;
              String omzetMinName = '-';
              int omzetMinVal = 0;
              String trxMaxName = '-';
              int trxMaxVal = 0;
              String trxMinName = '-';
              int trxMinVal = 0;

              if (svcStats.isNotEmpty) {
                final sortedByOmzet = svcStats.entries.toList()
                  ..sort((a, b) => (b.value['omzet'] as int).compareTo(a.value['omzet'] as int));
                omzetMaxName = sortedByOmzet.first.key;
                omzetMaxVal = sortedByOmzet.first.value['omzet'] as int;
                omzetMinName = sortedByOmzet.last.key;
                omzetMinVal = sortedByOmzet.last.value['omzet'] as int;

                final sortedByTrx = svcStats.entries.toList()
                  ..sort((a, b) => (b.value['count'] as int).compareTo(a.value['count'] as int));
                trxMaxName = sortedByTrx.first.key;
                trxMaxVal = sortedByTrx.first.value['count'] as int;
                trxMinName = sortedByTrx.last.key;
                trxMinVal = sortedByTrx.last.value['count'] as int;
              }

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storefront_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          cabangName,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 2.2,
                      children: [
                        _buildServiceHighlightBox('OMZET ▲ (TERTINGGI)', omzetMaxName, _currencyFormat.format(omzetMaxVal), const Color(0xFF059669)),
                        _buildServiceHighlightBox('OMZET ▼ (TERENDAH)', omzetMinName, _currencyFormat.format(omzetMinVal), const Color(0xFFDC2626)),
                        _buildServiceHighlightBox('TRX ▲ (TERBANYAK)', trxMaxName, '$trxMaxVal trx', const Color(0xFF059669)),
                        _buildServiceHighlightBox('TRX ▼ (TERSEDIKIT)', trxMinName, '$trxMinVal trx', const Color(0xFFD97706)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Keterangan: Omzet ▲/▼ = Layanan dengan omzet tertinggi/terendah per cabang. Trx ▲/▼ = Layanan dengan transaksi terbanyak/tersedikit per cabang.',
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceHighlightBox(String label, String serviceName, String valStr, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(serviceName, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(valStr, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // --- SUBTAB 3: Detail Omzet per Layanan ---
  Widget _buildDetailOmzetPerLayanan(List<OrderModel> periodOrders) {
    final validOrders = periodOrders.where((o) => o.status != OrderStatus.draft && o.status != OrderStatus.cancelled).toList();

    List<String> sortedCabangNames = [];
    if (_cabangs.isNotEmpty) {
      sortedCabangNames = _cabangs
          .where((c) => !c.namaCabang.toLowerCase().contains('kantor pusat'))
          .map((c) => c.namaCabang.toUpperCase())
          .toList()..sort();
    }

    if (sortedCabangNames.isEmpty) {
      sortedCabangNames = ['BALIKPAPAN', 'DENPASAR', 'MAKASSAR', 'MALANG', 'SURABAYA'];
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detail Omzet per Layanan',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedCabangNames.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final cabangName = sortedCabangNames[index];

              final cOrders = validOrders.where((o) =>
                o.customer.area.toUpperCase().contains(cabangName) ||
                (_cabangs.any((c) => c.namaCabang.toUpperCase() == cabangName && o.cabangId == c.id.toString()))
              ).toList();

              final Map<String, Map<String, dynamic>> serviceMap = {};
              int branchTotalOmzet = 0;
              int branchTotalTrx = 0;

              for (var o in cOrders) {
                for (var s in o.services) {
                  final sName = s.name.isNotEmpty ? s.name : 'General Cleaning';
                  final int itemQty = int.tryParse(s.qty) ?? 1;
                  final int subtotal = s.price * itemQty;
                  branchTotalOmzet += subtotal;
                  branchTotalTrx += 1;

                  if (!serviceMap.containsKey(sName)) {
                    serviceMap[sName] = {'omzet': 0, 'trx': 0};
                  }
                  serviceMap[sName]!['omzet'] = (serviceMap[sName]!['omzet'] as int) + subtotal;
                  serviceMap[sName]!['trx'] = (serviceMap[sName]!['trx'] as int) + 1;
                }
              }

              final sortedServices = serviceMap.entries.toList()
                ..sort((a, b) => (b.value['omzet'] as int).compareTo(a.value['omzet'] as int));

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.storefront_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              cabangName,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$branchTotalTrx Trx · ${_currencyFormat.format(branchTotalOmzet)}',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (sortedServices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Belum ada transaksi layanan pada periode ini.',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sortedServices.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, sIdx) {
                          final item = sortedServices[sIdx];
                          final omzet = item.value['omzet'] as int;
                          final trx = item.value['trx'] as int;
                          final pct = branchTotalOmzet > 0 ? (omzet / branchTotalOmzet) * 100 : 0.0;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.key,
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                    ),
                                  ),
                                  Text(
                                    '${trx} trx · ${_currencyFormat.format(omzet)}',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${pct.toStringAsFixed(1)}% dari Omzet Cabang',
                                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (pct / 100).clamp(0.0, 1.0),
                                  backgroundColor: Colors.grey.shade200,
                                  color: const Color(0xFF059669),
                                  minHeight: 4,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- SUBTAB 4: Ranking & Visualisasi (Top 5 Cabang & Top 5 Layanan) ---
  Widget _buildRankingVisualisasi(List<OrderModel> periodOrders) {
    final validOrders = periodOrders.where((o) => o.status != OrderStatus.draft && o.status != OrderStatus.cancelled).toList();

    // 1. Top 5 Cabang by Omzet
    final Map<String, int> cabangOmzet = {};
    for (var o in validOrders) {
      final name = o.customer.area.toUpperCase();
      cabangOmzet[name] = (cabangOmzet[name] ?? 0) + o.subtotal;
    }
    final sortedCabang = cabangOmzet.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5Cabang = sortedCabang.take(5).toList();
    final maxCabangOmzet = top5Cabang.isNotEmpty ? (top5Cabang.first.value > 0 ? top5Cabang.first.value : 1) : 1;

    // 2. Top 5 Layanan by Omzet
    final Map<String, int> serviceOmzet = {};
    int grandServiceOmzet = 0;
    for (var o in validOrders) {
      for (var s in o.services) {
        final sName = s.name.isNotEmpty ? s.name : 'General Cleaning';
        final int itemQty = int.tryParse(s.qty) ?? 1;
        final int itemTotal = s.price * itemQty;
        serviceOmzet[sName] = (serviceOmzet[sName] ?? 0) + itemTotal;
        grandServiceOmzet += itemTotal;
      }
    }
    final sortedServices = serviceOmzet.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5Services = sortedServices.take(5).toList();
    final maxServiceOmzet = top5Services.isNotEmpty ? (top5Services.first.value > 0 ? top5Services.first.value : 1) : 1;

    return Column(
      children: [
        // Top 5 Cabang Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Color(0xFFEAB308), size: 20),
                  const SizedBox(width: 8),
                  Text('Top 5 Cabang — Omzet', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                ],
              ),
              const SizedBox(height: 14),
              if (top5Cabang.isEmpty)
                const Text('Tidak ada data omzet cabang', style: TextStyle(fontSize: 12, color: Colors.grey))
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: top5Cabang.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = top5Cabang[index];
                    final pct = (item.value / maxCabangOmzet);
                    final String medal = index == 0 ? '🥇' : (index == 1 ? '🥈' : (index == 2 ? '🥉' : '${index + 1}.'));
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(medal, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 6),
                                Text(item.key, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                              ],
                            ),
                            Text(_currencyFormat.format(item.value), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct.clamp(0.0, 1.0),
                            backgroundColor: Colors.grey.shade100,
                            color: AppColors.primary,
                            minHeight: 6,
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Top 5 Layanan Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFF059669), size: 20),
                  const SizedBox(width: 8),
                  Text('Top 5 Layanan — Omzet', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                ],
              ),
              const SizedBox(height: 14),
              if (top5Services.isEmpty)
                const Text('Tidak ada data omzet layanan', style: TextStyle(fontSize: 12, color: Colors.grey))
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: top5Services.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = top5Services[index];
                    final pctMax = (item.value / maxServiceOmzet);
                    final pctTotal = grandServiceOmzet > 0 ? (item.value / grandServiceOmzet) * 100 : 0.0;
                    final String medal = index == 0 ? '🥇' : (index == 1 ? '🥈' : (index == 2 ? '🥉' : '${index + 1}.'));
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(medal, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 6),
                                Text(item.key, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                              ],
                            ),
                            Text(
                              '${_currencyFormat.format(item.value)} (${pctTotal.toStringAsFixed(1)}%)',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pctMax.clamp(0.0, 1.0),
                            backgroundColor: Colors.grey.shade100,
                            color: const Color(0xFF059669),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // PRIMARY TAB 2: KPI TAB CONTENT (Matching CapaianPage.blade.php)
  // ===========================================================================
  Widget _buildKpiTabContent(List<OrderModel> periodOrders) {
    final validOrders = periodOrders.where((o) => o.status != OrderStatus.draft && o.status != OrderStatus.cancelled).toList();

    List<String> sortedCabangNames = [];
    if (_cabangs.isNotEmpty) {
      sortedCabangNames = _cabangs
          .where((c) => !c.namaCabang.toLowerCase().contains('kantor pusat'))
          .map((c) => c.namaCabang.toUpperCase())
          .toList()..sort();
    }
    if (sortedCabangNames.isEmpty) {
      sortedCabangNames = ['BALIKPAPAN', 'DENPASAR', 'MAKASSAR', 'MALANG', 'SURABAYA'];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TABEL 1: Ringkasan Nilai KPI per Cabang
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
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
                  Text('Ringkasan Nilai KPI per Cabang', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Urut Total ⇅', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedCabangNames.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final name = sortedCabangNames[index];
                  final cOrders = validOrders.where((o) => o.customer.area.toUpperCase().contains(name)).toList();
                  final omzet = cOrders.fold<int>(0, (s, o) => s + o.subtotal);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        Row(
                          children: [
                            Text(_currencyFormat.format(omzet), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('0%', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                    child: Text('Merah', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                  ),
                  const SizedBox(width: 6),
                  Text('— Belum Capai Minimal Target KPI', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // TABEL 2: KPI Omzet per Cabang
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KPI Omzet per Cabang', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 12),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedCabangNames.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final name = sortedCabangNames[index];
                  final cabangObj = _cabangs.firstWhere(
                    (c) => c.namaCabang.toUpperCase() == name,
                    orElse: () => CabangModel(id: 0, namaCabang: name, status: 'aktif'),
                  );
                  final target = cabangObj.targetOmzet ?? 10000000.0;

                  final cOrders = validOrders.where((o) => o.customer.area.toUpperCase().contains(name)).toList();
                  final actualOmzet = cOrders.fold<int>(0, (s, o) => s + o.subtotal);
                  final capaianPct = target > 0 ? (actualOmzet / target) * 100 : 0.0;

                  final Color badgeBg = capaianPct >= 100 ? Colors.green.shade100 : (capaianPct >= 70 ? Colors.amber.shade100 : Colors.red.shade100);
                  final Color badgeText = capaianPct >= 100 ? Colors.green.shade800 : (capaianPct >= 70 ? Colors.amber.shade900 : Colors.red.shade800);

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${capaianPct.toStringAsFixed(1)}%',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: badgeText),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Target Aman: 100%', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                            Text('Realisasi: ${_currencyFormat.format(actualOmzet)}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Target Omzet: ${_currencyFormat.format(target)}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                            Text('Growth: +0.0%', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (capaianPct / 100).clamp(0.0, 1.0),
                            backgroundColor: Colors.grey.shade300,
                            color: capaianPct >= 100 ? Colors.green : (capaianPct >= 70 ? Colors.amber.shade700 : Colors.red),
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildKpiLegendBadge('Hijau', Colors.green.shade100, Colors.green.shade900, 'target aman (100%)'),
                    const SizedBox(width: 8),
                    _buildKpiLegendBadge('Kuning', Colors.amber.shade100, Colors.amber.shade900, 'kurang s/d 30% (≥70%)'),
                    const SizedBox(width: 8),
                    _buildKpiLegendBadge('Merah', Colors.red.shade100, Colors.red.shade900, 'kurang >30% (<70%)'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiLegendBadge(String label, Color bg, Color text, String desc) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
          child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: text)),
        ),
        const SizedBox(width: 4),
        Text(desc, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
      ],
    );
  }

  // ===========================================================================
  // PRIMARY TAB 3: MARKETING TAB CONTENT (Matching CapaianPage.blade.php)
  // ===========================================================================
  Widget _buildMarketingTabContent(List<OrderModel> periodOrders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search & Filter Bar
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _marketingQuery = val),
                  decoration: InputDecoration(
                    icon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                    hintText: 'Cari...',
                    hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Icon(Icons.filter_list_rounded, size: 20, color: AppColors.textDark),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Empty State Card matching blade
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.inbox_rounded, size: 36, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              Text(
                'Belum ada data',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 4),
              Text(
                'Tambahkan data baru atau ubah filter.',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Spend Summary Bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total spend:', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark)),
                  Text('Rp 0', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pajak 12%:', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark)),
                  Text('Rp 0', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total termasuk pajak:', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark)),
                  Text('Rp 0', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3 Channel Cards (Google, Meta, TikTok)
        Row(
          children: [
            Expanded(child: _buildChannelCard('Google', 'Rp 0')),
            const SizedBox(width: 8),
            Expanded(child: _buildChannelCard('Meta', 'Rp 0')),
            const SizedBox(width: 8),
            Expanded(child: _buildChannelCard('TikTok', 'Rp 0')),
          ],
        ),
      ],
    );
  }

  Widget _buildChannelCard(String name, String amount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          Text(amount, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        ],
      ),
    );
  }
}
