import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../services/finance_service.dart';
import '../../operasional/services/operasional_service.dart';
import '../../../core/widgets/gradient_header.dart';
import 'finance_cashflow_cabang_screen.dart';
import 'finance_approval_kas_screen.dart';
import 'finance_audit_screen.dart';
import 'finance_gaji_screen.dart';
import 'finance_download_screen.dart';
import '../../operasional/screens/operasional_permintaan_design_screen.dart';
import '../../operasional/screens/operasional_pengumuman_screen.dart';

class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({super.key});

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _service = FinanceService();
  final _operasionalService = OperasionalService();
  late TabController _tabController;

  bool _isLoading = true;
  String _error = '';

  String _userName = 'Finance';
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
    'Kustom Tanggal',
  ];

  DateTime? _customStartDate;
  DateTime? _customEndDate;

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
      String? start;
      String? end;

      final now = DateTime.now();

      if (_selectedFilter == 'Bulan Ini') {
        start = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime(now.year, now.month, 1));
        end = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime(now.year, now.month + 1, 0));
      } else if (_selectedFilter == 'Hari Ini') {
        start = DateFormat('yyyy-MM-dd').format(now);
        end = DateFormat('yyyy-MM-dd').format(now);
      } else if (_selectedFilter == 'Kemarin') {
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateFormat('yyyy-MM-dd').format(yesterday);
        end = DateFormat('yyyy-MM-dd').format(yesterday);
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
          ).format(DateTime(now.year, now.month + 1, 0));
        }
      }

      final results = await Future.wait([
        _service.getLaporanOmzet(
          startDate: start,
          endDate: end,
        ),
        _operasionalService.getReportKpi(
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
        if (res['status'] == true) {
          final d = res['data'];
          setState(() {
            _spendAdsList = d['spend_ads'] ?? [];
            _spendAdsSummary = d['summary'];
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

  String _formatCurrency(num value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
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
                      'Selamat Datang,',
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

  Widget _buildContent() {
    final global = _data!['global'];
    final growth = (global['growth'] as num).toDouble();
    final isGrowthPos = growth >= 0;

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
                          _formatCurrency(global['omzet_periode_ini']),
                          null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          'OMZET PERIODE LALU',
                          _formatCurrency(global['omzet_periode_lalu']),
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
                          _formatCurrency(
                            global['omzet_periode_ini'] -
                                global['omzet_periode_lalu'],
                          ),
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
                          '${global['jumlah_cancel']} Order',
                          null,
                          valueColor: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                const SizedBox(height: 12),

                // Menu Pintas Keuangan (Fast Action Buttons)
                _buildQuickMenuSection(),

                const SizedBox(height: 12),

                // Fast Buttons Grid (Sub-Tabs Omzet)
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

  Widget _buildQuickMenuSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Menu Pintas Keuangan',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFFD97706)),
                    const SizedBox(width: 2),
                    Text(
                      'Fast Actions',
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionBtn(
                  title: 'Cashflow Cabang',
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF059669),
                  bgColor: const Color(0xFFECFDF5),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FinanceCashflowCabangScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionBtn(
                  title: 'Approval Kas',
                  icon: Icons.assignment_turned_in_rounded,
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFFFBEB),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FinanceApprovalKasScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionBtn(
                  title: 'Audit Order',
                  icon: Icons.fact_check_rounded,
                  color: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEFF6FF),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FinanceAuditScreen()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionBtn(
                  title: 'Manajemen Gaji',
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF4F46E5),
                  bgColor: const Color(0xFFEEF2FF),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FinanceGajiScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionBtn(
                  title: 'Download Data',
                  icon: Icons.file_download_rounded,
                  color: const Color(0xFF0891B2),
                  bgColor: const Color(0xFFECFEFF),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FinanceDownloadScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionBtn(
                  title: 'Spend Ads',
                  icon: Icons.campaign_rounded,
                  color: const Color(0xFFE11D48),
                  bgColor: const Color(0xFFFFF1F2),
                  onTap: () {
                    setState(() => _mainTab = 'marketing');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionBtn(
                  title: 'Permintaan Design',
                  icon: Icons.palette_rounded,
                  color: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFF5F3FF),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OperasionalPermintaanDesignScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionBtn(
                  title: 'Pengumuman',
                  icon: Icons.notifications_active_rounded,
                  color: const Color(0xFFEA580C),
                  bgColor: const Color(0xFFFFF7ED),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OperasionalPengumumanScreen()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn({
    required String title,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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

  Widget _buildTabOmzetCabang() {
    final list = _data!['omzet_per_cabang'] as List;
    if (list.isEmpty) return const Center(child: Text('Tidak ada data'));

    double totalIni = 0;
    double totalLalu = 0;
    double totalAds = 0;
    double totalOrganik = 0;
    double totalLama = 0;

    for (var item in list) {
      totalIni += (item['periode_ini'] as num? ?? 0).toDouble();
      totalLalu += (item['periode_lalu'] as num? ?? 0).toDouble();
      totalAds += (item['ads'] as num? ?? 0).toDouble();
      totalOrganik += (item['organik'] as num? ?? 0).toDouble();
      totalLama += (item['lama'] as num? ?? 0).toDouble();
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
          final pIni = (item['periode_ini'] as num? ?? 0).toDouble();
          final pLalu = (item['periode_lalu'] as num? ?? 0).toDouble();
          final growth = (item['growth'] as num? ?? 0).toDouble();
          final isPos = growth >= 0;
          final ads = (item['ads'] as num? ?? 0).toDouble();
          final organik = (item['organik'] as num? ?? 0).toDouble();
          final lama = (item['lama'] as num? ?? 0).toDouble();

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
                          child: Icon(
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

  Widget _buildTabRingkasanLayanan() {
    final list = _data!['ringkasan_layanan'] as List;
    if (list.isEmpty) return const Center(child: Text('Tidak ada data'));

    Map<String, dynamic>? overallHighest;
    Map<String, dynamic>? overallLowest;
    Map<String, dynamic>? overallMost;
    Map<String, dynamic>? overallLeast;

    for (var item in list) {
      final h = item['omzet_tertinggi'];
      if (h != null &&
          (overallHighest == null ||
              (h['total'] as num? ?? 0) >
                  (overallHighest['total'] as num? ?? 0))) {
        overallHighest = h;
      }
      final l = item['omzet_terendah'];
      if (l != null &&
          (overallLowest == null ||
              (l['total'] as num? ?? 0) <
                  (overallLowest['total'] as num? ?? 0))) {
        overallLowest = l;
      }
      final m = item['trx_terbanyak'];
      if (m != null &&
          (overallMost == null ||
              (m['trx'] as num? ?? 0) > (overallMost['trx'] as num? ?? 0))) {
        overallMost = m;
      }
      final le = item['trx_tersedikit'];
      if (le != null &&
          (overallLeast == null ||
              (le['trx'] as num? ?? 0) < (overallLeast['trx'] as num? ?? 0))) {
        overallLeast = le;
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
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
                const SizedBox(height: 14),
                Divider(color: Colors.grey.shade100, height: 1),
                const SizedBox(height: 12),
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
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRekorItem(String label, dynamic data, {required bool isTrx}) {
    if (data == null) return Container();
    final name = data['nama_layanan']?.toString() ?? '-';
    final val = isTrx ? '${data['trx']} trx' : _formatCurrency(data['total']);
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
    if (data == null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '-',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
        ),
      );
    }
    final name = data['nama_layanan']?.toString() ?? '-';
    final val = isTrx ? '${data['trx']} trx' : _formatCurrency(data['total']);
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

  Widget _buildTabDetailLayanan() {
    final list = _data!['detail_layanan'] as List;
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
                            _formatCurrency(s['omzet'] as num),
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
    if (val is Map) return (val['omzet'] as num? ?? 0).toDouble();
    return 0.0;
  }

  int _getLayananTrx(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val > 0 ? 1 : 0;
    if (val is Map) return (val['trx'] as num? ?? 0).toInt();
    return 0;
  }

  Widget _buildTabRankingVisualisasi() {
    final listCabang = List<Map<String, dynamic>>.from(
      _data!['omzet_per_cabang'] as List,
    );
    listCabang.sort(
      (a, b) => (b['periode_ini'] as num).compareTo(a['periode_ini'] as num),
    );
    final maxCabang = listCabang.isEmpty
        ? 1.0
        : (listCabang.first['periode_ini'] as num).toDouble();

    final mapLayananTotal = <String, double>{};
    for (var item in (_data!['detail_layanan'] as List)) {
      final lMap = item['layanan'] as Map;
      lMap.forEach((k, v) {
        mapLayananTotal[k.toString()] =
            (mapLayananTotal[k.toString()] ?? 0) + _getLayananOmzet(v);
      });
    }
    final sortedLayanan = mapLayananTotal.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxLayanan = sortedLayanan.isEmpty ? 1.0 : sortedLayanan.first.value;

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
            final val = (item['periode_ini'] as num).toDouble();
            final pct = maxCabang > 0 ? val / maxCabang : 0.0;
            return _buildRankingCard(
              idx,
              item['nama_cabang'],
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
    if (rank == 1)
      badgeColor = const Color(0xFFEAA100); // Gold
    else if (rank == 2)
      badgeColor = const Color(0xFF9E9E9E); // Silver
    else if (rank == 3)
      badgeColor = const Color(0xFFCD7F32); // Bronze
    else
      badgeColor = Colors.grey.shade300;

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
        final aVal = ((a['omzet_dicapai'] ?? a['omzet'] ?? a['periode_ini']) as num? ?? 0).toDouble();
        final bVal = ((b['omzet_dicapai'] ?? b['omzet'] ?? b['periode_ini']) as num? ?? 0).toDouble();
        return _kpiSortDesc ? bVal.compareTo(aVal) : aVal.compareTo(bVal);
      });
    } else {
      list.sort((a, b) {
        final aVal = ((a['kpi_omzet'] ?? a['kpi_omzet_pct']) as num? ?? 0).toDouble();
        final bVal = ((b['kpi_omzet'] ?? b['kpi_omzet_pct']) as num? ?? 0).toDouble();
        return _kpiSortDesc ? bVal.compareTo(aVal) : aVal.compareTo(bVal);
      });
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
    final omzet = ((item['omzet_dicapai'] ?? item['omzet'] ?? item['periode_ini']) as num? ?? 0).toDouble();
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
    final omzet = ((item['omzet_dicapai'] ?? item['omzet'] ?? item['periode_ini']) as num? ?? 0).toDouble();
    final targetOmzet = (item['target_omzet'] as num? ?? 0).toDouble();
    final pct = ((item['kpi_omzet'] ?? item['kpi_omzet_pct'] ?? (targetOmzet > 0 ? (omzet / targetOmzet) * 100 : 0)) as num? ?? 0).toDouble();
    final growth = ((item['growth'] ?? item['growth_pct']) as num? ?? 0).toDouble();
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

    final sumGoogle = (summary['sum_google'] as num? ?? 0).toDouble();
    final sumMeta = (summary['sum_meta'] as num? ?? 0).toDouble();
    final sumTiktok = (summary['sum_tiktok'] as num? ?? 0).toDouble();
    final totalSpend = (summary['total_spend'] as num? ?? 0).toDouble();
    final pajak12 = (summary['pajak_12'] as num? ?? 0).toDouble();
    final totalTermasukPajak = (summary['total_termasuk_pajak'] as num? ?? 0).toDouble();

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
    final nominal = (ad['nominal'] as num? ?? 0).toDouble();
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
