import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../services/ceo_service.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/animated_notification_bell.dart';
import '../../operasional/screens/operasional_approval_pengajuan_screen.dart';
import '../../operasional/screens/operasional_purchase_order_screen.dart';
import '../../operasional/screens/monitoring_stok_opname_screen.dart';
import '../../operasional/screens/operasional_cashflow_cabang_screen.dart';

class CeoDashboardScreen extends StatefulWidget {
  const CeoDashboardScreen({super.key});

  @override
  State<CeoDashboardScreen> createState() => _CeoDashboardScreenState();
}

class _CeoDashboardScreenState extends State<CeoDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _service = CeoService();
  late TabController _tabController;

  bool _isLoading = true;
  String _error = '';

  String _userName = 'CEO / Owner';
  String _mainTab = 'omzet'; // 'omzet', 'kpi', 'marketing'
  int _kpiSubTab = 0; // 0 = Ringkasan Nilai KPI, 1 = KPI Omzet per Cabang
  bool _kpiSortDesc = true;

  // API Data
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _kpiData;

  // Marketing Spend Ads State
  bool _isLoadingMarketing = false;
  String _marketingError = '';
  List<dynamic> _spendAdsList = [];
  Map<String, dynamic>? _spendAdsSummary;
  final TextEditingController _marketingSearchController = TextEditingController();
  String _marketingSelectedPlatform = ''; // '', 'google', 'meta', 'tiktok'
  String _marketingPeriode = DateFormat('yyyy-MM').format(DateTime.now());
  Timer? _marketingSearchDebounce;

  // Filters
  String _selectedFilter = 'Bulan Ini';
  final List<String> _filters = [
    'Bulan Ini',
    'Kemarin',
    'Hari Ini',
    'Besok',
    'Kustom Tanggal',
  ];

  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Safe parsing helper functions
  double _parseDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? fallback;
    return fallback;
  }

  int _parseInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchData();
    _fetchMarketingData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _marketingSearchController.dispose();
    _marketingSearchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userName = prefs.getString('user_name') ?? 'CEO / Owner';
      });
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      String? start;
      String? end;

      final now = DateTime.now();

      if (_selectedFilter == 'Bulan Ini') {
        start = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime(now.year, now.month, 1));
        end = DateFormat(
          'yyyy-MM-dd',
        ).format(now);
      } else if (_selectedFilter == 'Hari Ini') {
        start = DateFormat('yyyy-MM-dd').format(now);
        end = DateFormat('yyyy-MM-dd').format(now);
      } else if (_selectedFilter == 'Kemarin') {
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateFormat('yyyy-MM-dd').format(yesterday);
        end = DateFormat('yyyy-MM-dd').format(yesterday);
      } else if (_selectedFilter == 'Besok') {
        final tomorrow = now.add(const Duration(days: 1));
        start = DateFormat('yyyy-MM-dd').format(tomorrow);
        end = DateFormat('yyyy-MM-dd').format(tomorrow);
      } else if (_selectedFilter == 'Kustom Tanggal') {
        if (_customStartDate != null && _customEndDate != null) {
          start = DateFormat('yyyy-MM-dd').format(_customStartDate!);
          end = DateFormat('yyyy-MM-dd').format(_customEndDate!);
        } else {
          start = DateFormat(
            'yyyy-MM-dd',
          ).format(DateTime(now.year, now.month, 1));
          end = DateFormat(
            'yyyy-MM-dd',
          ).format(now);
        }
      }

      final results = await Future.wait([
        _service.getLaporanOmzet(
          startDate: start,
          endDate: end,
        ),
        _service.getReportKpi(
          startDate: start,
          endDate: end,
        ),
      ]);

      final resOmzet = results[0];
      final resKpi = results[1];

      if (resOmzet['status'] == true) {
        setState(() {
          _data = resOmzet['data'];
          if (resKpi['status'] == true) {
            _kpiData = resKpi['data'];
          }
        });
      } else {
        setState(() => _error = resOmzet['message'] ?? 'Unknown error');
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMarketingData() async {
    setState(() {
      _isLoadingMarketing = true;
      _marketingError = '';
    });

    try {
      final res = await _service.getSpendAds(
        periode: _marketingPeriode,
        search: _marketingSearchController.text.trim(),
        platform: _marketingSelectedPlatform.isNotEmpty
            ? _marketingSelectedPlatform
            : null,
      );

      if (mounted) {
        if (res['status'] == true && res['data'] != null) {
          final rawData = res['data'];
          List<dynamic> list = [];
          Map<String, dynamic>? summary;

          if (rawData is Map) {
            if (rawData['spend_ads'] is List) {
              list = rawData['spend_ads'];
            } else if (rawData['data'] is List) {
              list = rawData['data'];
            }
            if (rawData['summary'] is Map) {
              summary = Map<String, dynamic>.from(rawData['summary']);
            }
          } else if (rawData is List) {
            list = rawData;
          }

          setState(() {
            _spendAdsList = list;
            _spendAdsSummary = summary;
          });
        } else {
          setState(() => _marketingError = res['message'] ?? 'Gagal mengambil data spend ads');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _marketingError = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMarketing = false);
      }
    }
  }

  void _onFilterChanged(String filter) async {
    if (filter == 'Kustom Tanggal') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      if (picked != null) {
        setState(() {
          _selectedFilter = filter;
          _customStartDate = picked.start;
          _customEndDate = picked.end;
        });
        _fetchData();
      }
    } else {
      setState(() => _selectedFilter = filter);
      _fetchData();
    }
  }

  String _formatCurrency(dynamic value) {
    final num numValue = _parseDouble(value);
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(numValue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildHeader(),
          _buildMainTabBar(),

          if (_mainTab == 'marketing')
            Expanded(child: _buildMarketingContent())
          else ...[
            // Filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: _filters.map((f) {
                  final isSelected = _selectedFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => _onFilterChanged(f),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          f == 'Kustom Tanggal' &&
                                  _customStartDate != null &&
                                  isSelected
                              ? '${DateFormat('dd MMM').format(_customStartDate!)} - ${DateFormat('dd MMM').format(_customEndDate!)}'
                              : f,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error.isNotEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 40,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _error,
                        style: GoogleFonts.inter(color: AppColors.error),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _fetchData,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_mainTab == 'kpi')
              Expanded(child: _buildKpiContent())
            else if (_data != null)
              Expanded(child: _buildContent()),
          ],
        ],
      ),
    );
  }

  Widget _buildMainTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildMainTabBtn('Omzet', 'omzet', Icons.grid_view_rounded),
          _buildMainTabBtn('KPI', 'kpi', Icons.analytics_rounded),
          _buildMainTabBtn('Marketing', 'marketing', Icons.campaign_rounded),
        ],
      ),
    );
  }

  Widget _buildMainTabBtn(String label, String key, IconData icon) {
    final isSelected = _mainTab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _mainTab = key;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 24,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Executive Dashboard,',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _userName,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AnimatedNotificationBell(size: 24),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.shield_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'CEO',
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
        ],
      ),
    );
  }

  Widget _buildContent() {
    final global = _data?['global'] ?? {};
    final num omzetIni = _parseDouble(global['omzet_periode_ini']);
    final num omzetLalu = _parseDouble(global['omzet_periode_lalu']);
    final growth = _parseDouble(global['growth']);
    final isGrowthPos = growth >= 0;
    final num cancelOrder = _parseInt(global['jumlah_cancel']);

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Summary Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'OMZET PERIODE INI',
                          _formatCurrency(omzetIni),
                          null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          'OMZET PERIODE LALU',
                          _formatCurrency(omzetLalu),
                          null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'GROWTH VS LALU',
                          _formatCurrency(omzetIni - omzetLalu),
                          isGrowthPos
                              ? '+${growth.toStringAsFixed(1)}%'
                              : '${growth.toStringAsFixed(1)}%',
                          valueColor: isGrowthPos ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          'JUMLAH CANCEL',
                          '$cancelOrder Order',
                          null,
                          valueColor: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Menu Eksekutif: Kontrol Cabang & Pengadaan (Style Dashboard CS / Cleaner)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
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
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.grid_view_rounded, size: 16, color: AppColors.primary),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Kontrol Cabang & Pengadaan',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Executive Hub',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildDashboardMenuIcon(
                                title: 'Stok Opname',
                                icon: Icons.fact_check_rounded,
                                iconColor: const Color(0xFF6366F1),
                                bgColor: const Color(0xFFEEF2FF),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const MonitoringStokOpnameScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildDashboardMenuIcon(
                                title: 'Cashflow',
                                icon: Icons.account_balance_wallet_rounded,
                                iconColor: const Color(0xFF059669),
                                bgColor: const Color(0xFFECFDF5),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const OperasionalCashflowCabangScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildDashboardMenuIcon(
                                title: 'Pengajuan CS',
                                icon: Icons.assignment_turned_in_rounded,
                                iconColor: const Color(0xFFD97706),
                                bgColor: const Color(0xFFFEF3C7),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const OperasionalApprovalPengajuanScreen(isReadOnly: true),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildDashboardMenuIcon(
                                title: 'Pembelian / PO',
                                icon: Icons.receipt_long_rounded,
                                iconColor: const Color(0xFF8B5CF6),
                                bgColor: const Color(0xFFF5F3FF),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const OperasionalPurchaseOrderScreen(isReadOnly: true),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Fast Sub-Tabs Omzet (1. Omzet Cabang, 2. Ringkasan Layanan, 3. Detail Layanan, 4. Ranking & Visual)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildFastButton(
                              0,
                              'Omzet Cabang',
                              Icons.storefront_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFastButton(
                              1,
                              'Ringkasan Layanan',
                              Icons.design_services_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFastButton(
                              2,
                              'Detail Layanan',
                              Icons.list_alt_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFastButton(
                              3,
                              'Ranking & Visual',
                              Icons.insights_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabOmzetCabang(),
          _buildTabRingkasanLayanan(),
          _buildTabDetailLayanan(),
          _buildTabRankingVisualisasi(),
        ],
      ),
    );
  }

  Widget _buildDashboardMenuIcon({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: iconColor.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String? subValue, {
    Color valueColor = AppColors.textDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (subValue != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: valueColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subValue,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: valueColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFastButton(int index, String label, IconData icon) {
    final isSelected = _tabController.index == index;
    return InkWell(
      onTap: () {
        setState(() {
          _tabController.animateTo(index);
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SUB-TAB 1: OMZET PER CABANG (Exact Rich Layout Matching Finance)
  // ===========================================================================
  Widget _buildTabOmzetCabang() {
    final list = (_data?['omzet_per_cabang'] as List?) ?? [];
    if (list.isEmpty) return const Center(child: Text('Tidak ada data'));

    double totalIni = 0;
    double totalLalu = 0;
    double totalAds = 0;
    double totalOrganik = 0;
    double totalLama = 0;

    for (var item in list) {
      totalIni += _parseDouble(item['periode_ini']);
      totalLalu += _parseDouble(item['periode_lalu']);
      totalAds += _parseDouble(item['ads']);
      totalOrganik += _parseDouble(item['organik']);
      totalLama += _parseDouble(item['lama']);
    }
    double totalGrowth = totalLalu > 0
        ? ((totalIni - totalLalu) / totalLalu) * 100
        : 0;
    final isTotalPos = totalGrowth >= 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 🎯 GRAND TOTAL BANNER CARD
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
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
                  Text(
                    'TOTAL OMZET GABUNGAN',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isTotalPos
                          ? Colors.green.shade400.withValues(alpha: 0.3)
                          : Colors.red.shade400.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isTotalPos
                            ? Colors.green.shade200
                            : Colors.red.shade200,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isTotalPos
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${totalGrowth.toStringAsFixed(1)}%',
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
              const SizedBox(height: 8),
              Text(
                _formatCurrency(totalIni),
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Periode Lalu: ${_formatCurrency(totalLalu)}',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMiniStatWhite('ADS', _formatCurrency(totalAds)),
                    Container(width: 1, height: 28, color: Colors.white24),
                    _buildMiniStatWhite(
                      'ORGANIK',
                      _formatCurrency(totalOrganik),
                    ),
                    Container(width: 1, height: 28, color: Colors.white24),
                    _buildMiniStatWhite('LAMA', _formatCurrency(totalLama)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'PERFORMA CABANG',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),

        // 🏢 CABANG CARDS
        ...list.map((item) {
          final pIni = _parseDouble(item['periode_ini']);
          final pLalu = _parseDouble(item['periode_lalu']);
          final growth = _parseDouble(item['growth']);
          final isPos = growth >= 0;
          final ads = _parseDouble(item['ads']);
          final organik = _parseDouble(item['organik']);
          final lama = _parseDouble(item['lama']);

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          item['nama_cabang']?.toString().toUpperCase() ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPos
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPos ? Icons.trending_up : Icons.trending_down,
                            size: 14,
                            color: isPos
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${isPos ? '+' : ''}${growth.toStringAsFixed(1)}%',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isPos
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Omzet Periode Ini',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatCurrency(pIni),
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Periode Lalu',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatCurrency(pLalu),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: Colors.grey.shade100, height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSourceChip(
                      'Ads',
                      _formatCurrency(ads),
                      Colors.blue.shade700,
                    ),
                    _buildSourceChip(
                      'Organik',
                      _formatCurrency(organik),
                      Colors.green.shade700,
                    ),
                    _buildSourceChip(
                      'Lama',
                      _formatCurrency(lama),
                      Colors.orange.shade700,
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMiniStatWhite(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSourceChip(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SUB-TAB 2: RINGKASAN LAYANAN (National Record + Branch Summaries)
  // ===========================================================================
  Widget _buildTabRingkasanLayanan() {
    final list = (_data?['ringkasan_layanan'] as List?) ?? [];
    if (list.isEmpty) return const Center(child: Text('Tidak ada data'));

    final detailList = (_data?['detail_layanan'] as List?) ?? [];
    final Map<String, double> nasionalOmzet = {};
    final Map<String, int> nasionalTrx = {};

    for (var item in detailList) {
      final lMap = item['layanan'] as Map? ?? {};
      lMap.forEach((k, v) {
        final name = k.toString();
        nasionalOmzet[name] = (nasionalOmzet[name] ?? 0.0) + _getLayananOmzet(v);
        nasionalTrx[name] = (nasionalTrx[name] ?? 0) + _getLayananTrx(v);
      });
    }

    Map<String, dynamic>? overallHighest;
    Map<String, dynamic>? overallLowest;
    Map<String, dynamic>? overallMost;
    Map<String, dynamic>? overallLeast;

    if (nasionalOmzet.isNotEmpty) {
      final sortedByOmzet = nasionalOmzet.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final highestEntry = sortedByOmzet.first;
      overallHighest = {
        'nama_layanan': highestEntry.key,
        'total': highestEntry.value,
        'trx': nasionalTrx[highestEntry.key] ?? 0,
      };

      final activeByOmzet = sortedByOmzet.where((e) => e.value > 0).toList();
      final lowestEntry = activeByOmzet.isNotEmpty ? activeByOmzet.last : sortedByOmzet.last;
      overallLowest = {
        'nama_layanan': lowestEntry.key,
        'total': lowestEntry.value,
        'trx': nasionalTrx[lowestEntry.key] ?? 0,
      };
    }

    if (nasionalTrx.isNotEmpty) {
      final sortedByTrx = nasionalTrx.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final mostEntry = sortedByTrx.first;
      overallMost = {
        'nama_layanan': mostEntry.key,
        'trx': mostEntry.value,
        'total': nasionalOmzet[mostEntry.key] ?? 0.0,
      };

      final activeByTrx = sortedByTrx.where((e) => e.value > 0).toList();
      final leastEntry = activeByTrx.isNotEmpty ? activeByTrx.last : sortedByTrx.last;
      overallLeast = {
        'nama_layanan': leastEntry.key,
        'trx': leastEntry.value,
        'total': nasionalOmzet[leastEntry.key] ?? 0.0,
      };
    }

    if (overallHighest == null) {
      for (var item in list) {
        final h = item['omzet_tertinggi'];
        if (h != null &&
            (overallHighest == null ||
                _parseDouble(h['total']) > _parseDouble(overallHighest['total']))) {
          overallHighest = h;
        }
        final l = item['omzet_terendah'];
        if (l != null &&
            (overallLowest == null ||
                _parseDouble(l['total']) < _parseDouble(overallLowest['total']))) {
          overallLowest = l;
        }
        final m = item['trx_terbanyak'];
        if (m != null &&
            (overallMost == null ||
                _parseInt(m['trx']) > _parseInt(overallMost['trx']))) {
          overallMost = m;
        }
        final le = item['trx_tersedikit'];
        if (le != null &&
            (overallLeast == null ||
                _parseInt(le['trx']) < _parseInt(overallLeast['trx']))) {
          overallLeast = le;
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 🏆 REKOR TOTAL NASIONAL CARD
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.amber.shade700, Colors.orange.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.3),
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
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'REKOR TOTAL NASIONAL',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildRekorItem(
                      'Omzet Tertinggi',
                      overallHighest,
                      isTrx: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRekorItem(
                      'Trx Terbanyak',
                      overallMost,
                      isTrx: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildRekorItem(
                      'Omzet Terendah',
                      overallLowest,
                      isTrx: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRekorItem(
                      'Trx Tersedikit',
                      overallLeast,
                      isTrx: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'RINGKASAN PER CABANG',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),

        // 🏢 BRANCH SUMMARY CARDS
        ...list.map((item) {
          final highest = item['omzet_tertinggi'];
          final lowest = item['omzet_terendah'];
          final most = item['trx_terbanyak'];
          final least = item['trx_tersedikit'];
          final bool hasAnyData = highest != null || lowest != null || most != null || least != null;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.insights_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          item['nama_cabang']?.toString().toUpperCase() ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    if (!hasAnyData)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          '0 Transaksi',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: Colors.grey.shade100, height: 1),
                const SizedBox(height: 12),
                if (!hasAnyData)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 15, color: Colors.grey.shade400),
                        const SizedBox(width: 6),
                        Text(
                          'Belum ada transaksi layanan pada periode ini',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryBox(
                          'Omzet Tertinggi',
                          highest,
                          Colors.green,
                          isTrx: false,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSummaryBox(
                          'Trx Terbanyak',
                          most,
                          Colors.orange,
                          isTrx: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryBox(
                          'Omzet Terendah',
                          lowest,
                          Colors.grey,
                          isTrx: false,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSummaryBox(
                          'Trx Tersedikit',
                          least,
                          Colors.blueGrey,
                          isTrx: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRekorItem(String label, dynamic data, {required bool isTrx}) {
    final name = data != null ? (data['nama_layanan']?.toString() ?? '-') : '-';
    final val = data != null
        ? (isTrx ? '${data['trx']} trx' : _formatCurrency(data['total'] ?? 0))
        : '-';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            val,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox(
    String label,
    dynamic data,
    MaterialColor color, {
    required bool isTrx,
  }) {
    final name = data != null ? (data['nama_layanan']?.toString() ?? '-') : '-';
    final val = data != null
        ? (isTrx ? '${data['trx']} trx' : _formatCurrency(data['total'] ?? 0))
        : '-';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: color.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            val,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUB-TAB 3: DETAIL OMZET PER LAYANAN (Active Services List & Progress)
  // ===========================================================================
  Widget _buildTabDetailLayanan() {
    final list = (_data?['detail_layanan'] as List?) ?? [];
    if (list.isEmpty) return const Center(child: Text('Tidak ada data'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final namaCabang = item['nama_cabang'].toString();
        final layananMap = item['layanan'] as Map;

        // Collect active services (> 0 omzet or > 0 trx)
        final activeServices = <Map<String, dynamic>>[];
        double totalOmzet = 0.0;
        int totalTrx = 0;

        layananMap.forEach((key, val) {
          final omzet = _getLayananOmzet(val);
          final trx = _getLayananTrx(val);
          if (omzet > 0 || trx > 0) {
            activeServices.add({
              'name': key.toString(),
              'omzet': omzet,
              'trx': trx,
            });
            totalOmzet += omzet;
            totalTrx += trx;
          }
        });

        // Sort active services descending by omzet
        activeServices.sort(
          (a, b) => (b['omzet'] as double).compareTo(a['omzet'] as double),
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.store_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            namaCabang.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${activeServices.length} Layanan Aktif • $totalTrx Trx',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatCurrency(totalOmzet),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // Active Services List
              if (activeServices.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Belum ada transaksi di cabang ini',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: activeServices.length,
                  separatorBuilder: (context, i) =>
                      Divider(color: Colors.grey.shade100, height: 20),
                  itemBuilder: (context, i) {
                    final s = activeServices[i];
                    return Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            s['name'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${s['trx']} trx',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 110,
                          child: Text(
                            _formatCurrency(s['omzet']),
                            textAlign: TextAlign.right,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
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
    );
  }

  double _getLayananOmzet(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    if (val is Map) {
      return _parseDouble(val['omzet']);
    }
    return 0.0;
  }

  int _getLayananTrx(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    if (val is Map) {
      return _parseInt(val['trx']);
    }
    return 0;
  }

  // ===========================================================================
  // SUB-TAB 4: RANKING & VISUALISASI (Gold, Silver, Bronze & Top Lists)
  // ===========================================================================
  Widget _buildTabRankingVisualisasi() {
    final listCabang = List<Map<String, dynamic>>.from(
      (_data?['omzet_per_cabang'] as List?) ?? [],
    );
    listCabang.sort(
      (a, b) => _parseDouble(b['periode_ini']).compareTo(_parseDouble(a['periode_ini'])),
    );
    final maxCabang = listCabang.isEmpty
        ? 1.0
        : _parseDouble(listCabang.first['periode_ini']);

    final mapLayananTotal = <String, double>{};
    for (var item in ((_data?['detail_layanan'] as List?) ?? [])) {
      final lMap = item['layanan'] as Map;
      lMap.forEach((k, v) {
        mapLayananTotal[k.toString()] =
            (mapLayananTotal[k.toString()] ?? 0) + _getLayananOmzet(v);
      });
    }
    final sortedLayanan = mapLayananTotal.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxLayanan = sortedLayanan.isEmpty ? 1.0 : (sortedLayanan.first.value > 0 ? sortedLayanan.first.value : 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRankingSectionTitle(
            '🏆 Top Cabang Tertinggi (Omzet)',
            AppColors.primary,
          ),
          const SizedBox(height: 12),
          ...listCabang.take(5).toList().asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final item = entry.value;
            final val = _parseDouble(item['periode_ini']);
            final pct = maxCabang > 0 ? val / maxCabang : 0.0;
            return _buildRankingCard(
              idx,
              item['nama_cabang']?.toString() ?? '-',
              _formatCurrency(val),
              pct,
              AppColors.primary,
            );
          }),
          const SizedBox(height: 24),
          _buildRankingSectionTitle(
            '⚡ Top Layanan Terlaris (Omzet)',
            Colors.green.shade700,
          ),
          const SizedBox(height: 12),
          ...sortedLayanan.take(5).toList().asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final item = entry.value;
            final val = item.value;
            final pct = maxLayanan > 0 ? val / maxLayanan : 0.0;
            return _buildRankingCard(
              idx,
              item.key,
              _formatCurrency(val),
              pct,
              Colors.green.shade700,
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRankingSectionTitle(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildRankingCard(
    int rank,
    String title,
    String value,
    double progress,
    Color color,
  ) {
    Color badgeColor;
    if (rank == 1) {
      badgeColor = const Color(0xFFEAA100); // Gold
    } else if (rank == 2) {
      badgeColor = const Color(0xFF9E9E9E); // Silver
    } else if (rank == 3) {
      badgeColor = const Color(0xFFCD7F32); // Bronze
    } else {
      badgeColor = Colors.grey.shade300;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
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
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '#$rank',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: rank <= 3 ? Colors.white : AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // KPI VIEW (Matching Web CapaianPage)
  // ===========================================================================
  Widget _buildKpiContent() {
    final rawList = (_kpiData?['kpi_per_cabang'] as List?) ??
        (_data?['omzet_per_cabang'] as List?) ??
        [];
    if (rawList.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada data KPI.',
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    final list = List<Map<String, dynamic>>.from(rawList);
    if (_kpiSubTab == 0) {
      list.sort((a, b) {
        final aVal = _parseDouble(a['omzet_dicapai'] ?? a['omzet'] ?? a['periode_ini']);
        final bVal = _parseDouble(b['omzet_dicapai'] ?? b['omzet'] ?? b['periode_ini']);
        return _kpiSortDesc ? bVal.compareTo(aVal) : aVal.compareTo(bVal);
      });
    } else {
      list.sort((a, b) {
        final aVal = _parseDouble(a['kpi_omzet'] ?? a['kpi_omzet_pct']);
        final bVal = _parseDouble(b['kpi_omzet'] ?? b['kpi_omzet_pct']);
        return _kpiSortDesc ? bVal.compareTo(aVal) : aVal.compareTo(bVal);
      });
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 20 : 24),
      children: [
        // Sub Tab Selector
        Row(
          children: [
            Expanded(
              child: _buildKpiSubTabBtn(
                'Ringkasan Nilai KPI',
                0,
                Icons.fact_check_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildKpiSubTabBtn(
                'KPI Omzet per Cabang',
                1,
                Icons.analytics_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Section Title with Sort Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _kpiSubTab == 0
                  ? 'RINGKASAN NILAI KPI PER CABANG'
                  : 'KPI OMZET PER CABANG',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
                letterSpacing: 0.3,
              ),
            ),
            InkWell(
              onTap: () => setState(() => _kpiSortDesc = !_kpiSortDesc),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _kpiSubTab == 0 ? 'Urut Omzet' : 'Urut % KPI',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _kpiSortDesc
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Cards List
        if (_kpiSubTab == 0)
          ...list.map((item) => _buildRingkasanKpiCard(item))
        else
          ...list.map((item) => _buildKpiOmzetCard(item)),

        const SizedBox(height: 12),

        // Legend Box (Matching Web)
        if (_kpiSubTab == 0)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Merah',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '— Belum Capai Minimal Target KPI',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLegendItem(
                  'Hijau',
                  'target aman (100%)',
                  Colors.green.shade50,
                  Colors.green.shade700,
                ),
                const SizedBox(height: 6),
                _buildLegendItem(
                  'Kuning',
                  'kurang s/d 30% (≥70%)',
                  Colors.amber.shade50,
                  Colors.amber.shade800,
                ),
                const SizedBox(height: 6),
                _buildLegendItem(
                  'Merah',
                  'kurang >30% (<70%)',
                  Colors.red.shade50,
                  Colors.red.shade700,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildKpiSubTabBtn(String label, int index, IconData icon) {
    final isSelected = _kpiSubTab == index;
    return InkWell(
      onTap: () => setState(() => _kpiSubTab = index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRingkasanKpiCard(Map<String, dynamic> item) {
    final omzet = _parseDouble(item['omzet_dicapai'] ?? item['omzet'] ?? item['periode_ini']);
    final namaCabang = item['nama_cabang']?.toString().toUpperCase() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    namaCabang,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '0%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade100, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Omzet Dicapai',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatCurrency(omzet),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: omzet > 0 ? Colors.green.shade700 : AppColors.textDark,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Target Nilai KPI',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '—',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiOmzetCard(Map<String, dynamic> item) {
    final omzet = _parseDouble(item['omzet_dicapai'] ?? item['omzet'] ?? item['periode_ini']);
    final targetOmzet = _parseDouble(item['target_omzet']);
    final pct = _parseDouble(item['kpi_omzet'] ?? item['kpi_omzet_pct'] ?? (targetOmzet > 0 ? (omzet / targetOmzet) * 100 : 0));
    final growth = _parseDouble(item['growth'] ?? item['growth_pct']);
    final isGrowthPos = growth >= 0;
    final namaCabang = item['nama_cabang']?.toString().toUpperCase() ?? '';

    Color bgBadge;
    Color textBadge;
    if (pct >= 100) {
      bgBadge = Colors.green.shade50;
      textBadge = Colors.green.shade700;
    } else if (pct >= 70) {
      bgBadge = Colors.amber.shade50;
      textBadge = Colors.amber.shade800;
    } else {
      bgBadge = Colors.red.shade50;
      textBadge = Colors.red.shade700;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    namaCabang,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: bgBadge,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textBadge,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isGrowthPos ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${isGrowthPos ? '+' : ''}${growth.toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isGrowthPos ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Omzet Dicapai',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatCurrency(omzet),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: omzet > 0 ? Colors.green.shade700 : AppColors.textDark,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Target Omzet',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatCurrency(targetOmzet),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: Colors.grey.shade100, height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target Aman: 100%',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    String badgeText,
    String desc,
    Color bgColor,
    Color textColor,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badgeText,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          desc,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // MARKETING / SPEND ADS VIEW (Mobile Friendly & Web Aligned)
  // ===========================================================================
  Widget _buildMarketingContent() {
    final summary = _spendAdsSummary ?? {
      'sum_google': 0.0,
      'sum_meta': 0.0,
      'sum_tiktok': 0.0,
      'total_spend': 0.0,
      'pajak_12': 0.0,
      'total_termasuk_pajak': 0.0,
      'periode': _marketingPeriode,
    };

    final sumGoogle = _parseDouble(summary['sum_google']);
    final sumMeta = _parseDouble(summary['sum_meta']);
    final sumTiktok = _parseDouble(summary['sum_tiktok']);
    final totalSpend = _parseDouble(summary['total_spend'], sumGoogle + sumMeta + sumTiktok);
    final pajak12 = _parseDouble(summary['pajak_12'], totalSpend * 0.12);
    final totalTermasukPajak = _parseDouble(summary['total_termasuk_pajak'], totalSpend + pajak12);

    DateTime parsedMonth;
    try {
      final parts = _marketingPeriode.split('-');
      parsedMonth = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) {
      parsedMonth = DateTime.now();
    }
    final formattedMonth = DateFormat('MMMM yyyy', 'id_ID').format(parsedMonth);

    return RefreshIndicator(
      onRefresh: _fetchMarketingData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // 1. Top Hero Summary Card (Modern Fintech Design)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Label & Month Picker Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL SPEND MARKETING',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    InkWell(
                      onTap: _pickMarketingMonth,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              formattedMonth,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 14,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Big Total Including Tax
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        _formatCurrency(totalTermasukPajak),
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Total termasuk PPN 12%',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 16),

                // 2 Sub-metrics (Spend Net & Pajak 12%)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Spend Net',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatCurrency(totalSpend),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pajak PPN (12%)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatCurrency(pajak12),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF38BDF8),
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
          ),
          const SizedBox(height: 16),

          // 2. Interactive Platform Spend Cards
          Row(
            children: [
              Expanded(
                child: _buildPlatformMetricCard(
                  title: 'Google',
                  amount: sumGoogle,
                  platformKey: 'google',
                  iconColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5),
                  borderColor: const Color(0xFFA7F3D0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPlatformMetricCard(
                  title: 'Meta',
                  amount: sumMeta,
                  platformKey: 'meta',
                  iconColor: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEFF6FF),
                  borderColor: const Color(0xFFBFDBFE),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPlatformMetricCard(
                  title: 'TikTok',
                  amount: sumTiktok,
                  platformKey: 'tiktok',
                  iconColor: const Color(0xFF0F172A),
                  bgColor: const Color(0xFFF1F5F9),
                  borderColor: const Color(0xFFCBD5E1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Search Bar
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _marketingSearchController,
              onChanged: (val) {
                _marketingSearchDebounce?.cancel();
                _marketingSearchDebounce = Timer(
                  const Duration(milliseconds: 350),
                  _fetchMarketingData,
                );
              },
              decoration: InputDecoration(
                hintText: 'Cari nama cabang...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                suffixIcon: _marketingSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                        onPressed: () {
                          _marketingSearchController.clear();
                          _fetchMarketingData();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 4. Platform Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPlatformChip('Semua Platform', ''),
                _buildPlatformChip('Google Ads', 'google'),
                _buildPlatformChip('Meta Ads', 'meta'),
                _buildPlatformChip('TikTok Ads', 'tiktok'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daftar Spend Ads Cabang',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              if (!_isLoadingMarketing && _marketingError.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_spendAdsList.length} Data',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 6. Spend Ads Content / Empty State / Loading
          if (_isLoadingMarketing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_marketingError.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Column(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    _marketingError,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.error),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _fetchMarketingData,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Muat Ulang'),
                  ),
                ],
              ),
            )
          else if (_spendAdsList.isEmpty)
            // Empty State Card
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.inbox_rounded,
                      size: 28,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada data',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Belum ada pengeluaran iklan di filter/periode ini.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            )
          else
            // Spend Ads Items
            ..._spendAdsList.map((ad) => _buildSpendAdCard(ad)),
        ],
      ),
    );
  }

  Widget _buildPlatformMetricCard({
    required String title,
    required double amount,
    required String platformKey,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    final isSelected = _marketingSelectedPlatform == platformKey;
    return InkWell(
      onTap: () {
        setState(() {
          _marketingSelectedPlatform = isSelected ? '' : platformKey;
        });
        _fetchMarketingData();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? iconColor : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? iconColor : AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _formatCurrency(amount),
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformChip(String label, String value) {
    final isSelected = _marketingSelectedPlatform == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          setState(() => _marketingSelectedPlatform = value);
          _fetchMarketingData();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpendAdCard(dynamic ad) {
    final cabangName = ad['cabang']?['nama_cabang']?.toString().toUpperCase() ?? '-';
    final platform = (ad['platform']?.toString() ?? 'google').toLowerCase();
    final nominal = _parseDouble(ad['nominal']);
    final periode = ad['periode']?.toString() ?? '';

    Color badgeBg;
    Color badgeText;
    IconData platformIcon;
    if (platform == 'google') {
      badgeBg = const Color(0xFFECFDF5);
      badgeText = const Color(0xFF059669);
      platformIcon = Icons.campaign_rounded;
    } else if (platform == 'meta') {
      badgeBg = const Color(0xFFEFF6FF);
      badgeText = const Color(0xFF2563EB);
      platformIcon = Icons.share_rounded;
    } else {
      badgeBg = const Color(0xFFF1F5F9);
      badgeText = const Color(0xFF0F172A);
      platformIcon = Icons.music_note_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Platform Icon Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              platformIcon,
              size: 20,
              color: badgeText,
            ),
          ),
          const SizedBox(width: 12),

          // Center: Branch & Platform / Period
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cabangName,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        platform.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: badgeText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      periode,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right: Amount
          Text(
            _formatCurrency(nominal),
            style: GoogleFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _pickMarketingMonth() async {
    DateTime current;
    try {
      final parts = _marketingPeriode.split('-');
      current = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) {
      current = DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'PILIH PERIODE BULAN',
    );

    if (picked != null) {
      setState(() {
        _marketingPeriode = DateFormat('yyyy-MM').format(picked);
      });
      _fetchMarketingData();
    }
  }
}
