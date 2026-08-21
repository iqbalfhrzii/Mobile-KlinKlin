import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/operasional_service.dart';

class OperasionalReportKpiScreen extends StatefulWidget {
  final bool hideHeader;
  final VoidCallback? onSwitchToKpiCs;
  const OperasionalReportKpiScreen({super.key, this.hideHeader = false, this.onSwitchToKpiCs});

  @override
  State<OperasionalReportKpiScreen> createState() => _OperasionalReportKpiScreenState();
}

class _OperasionalReportKpiScreenState extends State<OperasionalReportKpiScreen> with SingleTickerProviderStateMixin {
  final _service = OperasionalService();
  late TabController _tabController;

  bool _isLoading = true;
  String _error = '';
  Map<String, dynamic>? _data;

  // Filters for KPI Tab
  String _selectedFilter = 'Bulan Ini';
  final List<String> _filters = ['Bulan Ini', 'Kemarin', 'Hari Ini', 'Besok', 'Kustom Tanggal'];
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // --- STATE FOR SEMUA ORDER TAB ---
  bool _isLoadingOrders = false;
  String _ordersError = '';
  List<dynamic> _ordersList = [];
  List<dynamic> _cabangs = [];
  final TextEditingController _orderSearchController = TextEditingController();
  Timer? _orderDebounce;

  int? _selectedOrderCabangId;
  String? _selectedOrderStatus;
  String _selectedOrderPeriode = 'Semua';
  final List<String> _orderPeriodeFilters = ['Semua', 'Kemarin', 'Hari Ini', 'Besok', 'Rentang Waktu'];
  DateTime? _orderCustomStartDate;
  DateTime? _orderCustomEndDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
        if (_tabController.index == 1 && _ordersList.isEmpty) {
          _fetchOrders();
        }
      }
    });
    _fetchKpiData();
    _fetchCabangs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _orderSearchController.dispose();
    _orderDebounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchCabangs() async {
    try {
      final res = await _service.getCabangs();
      if (mounted) {
        setState(() {
          _cabangs = res['data'] ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoadingOrders = true;
      _ordersError = '';
    });

    try {
      String? start;
      String? end;
      String? periodeParam;

      if (_selectedOrderPeriode == 'Hari Ini') {
        periodeParam = 'hari_ini';
      } else if (_selectedOrderPeriode == 'Kemarin') {
        periodeParam = 'kemarin';
      } else if (_selectedOrderPeriode == 'Besok') {
        periodeParam = 'besok';
      } else if (_selectedOrderPeriode == 'Rentang Waktu') {
        if (_orderCustomStartDate != null) {
          start = DateFormat('yyyy-MM-dd').format(_orderCustomStartDate!);
        }
        if (_orderCustomEndDate != null) {
          end = DateFormat('yyyy-MM-dd').format(_orderCustomEndDate!);
        }
      }

      final res = await _service.getSemuaOrder(
        search: _orderSearchController.text.trim(),
        cabangId: _selectedOrderCabangId,
        status: _selectedOrderStatus,
        periode: periodeParam,
        startDate: start,
        endDate: end,
      );

      if (mounted) {
        final list = res['data'];
        if (list is List) {
          setState(() => _ordersList = list);
        } else if (list is Map && list['data'] is List) {
          setState(() => _ordersList = list['data']);
        } else {
          setState(() => _ordersList = []);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _ordersError = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingOrders = false);
      }
    }
  }

  void _onOrderSearchChanged(String val) {
    if (_orderDebounce?.isActive ?? false) _orderDebounce!.cancel();
    _orderDebounce = Timer(const Duration(milliseconds: 400), () {
      _fetchOrders();
    });
  }

  void _onOrderPeriodeChanged(String filter) async {
    if (filter == 'Rentang Waktu') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      if (picked != null) {
        setState(() {
          _selectedOrderPeriode = filter;
          _orderCustomStartDate = picked.start;
          _orderCustomEndDate = picked.end;
        });
        _fetchOrders();
      }
    } else {
      setState(() {
        _selectedOrderPeriode = filter;
        _orderCustomStartDate = null;
        _orderCustomEndDate = null;
      });
      _fetchOrders();
    }
  }

  Future<void> _fetchKpiData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      String? start;
      String? end;
      final now = DateTime.now();

      if (_selectedFilter == 'Bulan Ini') {
        start = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
        end = DateFormat('yyyy-MM-dd').format(now);
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
          start = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
          end = DateFormat('yyyy-MM-dd').format(now);
        }
      }

      final res = await _service.getReportKpi(startDate: start, endDate: end);
      if (res['status'] == true) {
        setState(() => _data = res['data']);
      } else {
        setState(() => _error = res['message'] ?? 'Unknown error');
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
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
        _fetchKpiData();
      }
    } else {
      setState(() => _selectedFilter = filter);
      _fetchKpiData();
    }
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  String _formatIndoDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      const months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      final day = dt.day.toString().padLeft(2, '0');
      final month = months[dt.month - 1];
      return '$day $month ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          if (!widget.hideHeader)
            GradientHeader(
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Report KPI',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Laporan pencapaian target omzet & daftar transaksi',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildFastButton(0, 'KPI Omzet per Cabang', Icons.storefront_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFastButton(1, 'Semua Order', Icons.receipt_long_rounded),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildKpiTab(),
                _buildSemuaOrderTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiTab() {
    return Column(
      children: [
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
                    ),
                    child: Text(
                      f == 'Kustom Tanggal' && _customStartDate != null && isSelected
                          ? '${DateFormat('dd MMM').format(_customStartDate!)} - ${DateFormat('dd MMM').format(_customEndDate!)}'
                          : f,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Legend & Target Banner
        if (_data != null)
          Builder(
            builder: (context) {
              final double targetAmanGlobal = (_data!['target_aman_global'] is num)
                  ? (_data!['target_aman_global'] as num).toDouble()
                  : 68.0;
              final double kuningMin = (targetAmanGlobal - 20.0).clamp(0.0, 100.0);

              final periode = _data!['periode'] as Map<String, dynamic>?;
              final String startDateStr = _formatIndoDate(periode?['start']?.toString());
              final String endDateStr = _formatIndoDate(periode?['end']?.toString());
              final String prevStartStr = _formatIndoDate(periode?['prev_start']?.toString());
              final String prevEndStr = _formatIndoDate(periode?['prev_end']?.toString());

              return Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // TOP SECTION: Period & Target Aman Pill
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Periode & Target Badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Left: Periode Icon & Text
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Periode Laporan',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                          Text(
                                            '$startDateStr - $endDateStr',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Right: Target Aman Badge Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.flag_rounded, size: 12, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Target: ',
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    Text(
                                      '${targetAmanGlobal.toStringAsFixed(0)}%',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Row 2: Pembanding (-1 bulan) subtle chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.compare_arrows_rounded, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text(
                                  'Pembanding (-1 bln): ',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '$prevStartStr - $prevEndStr',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF334155),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // BOTTOM SECTION: 3 Micro-Cards for Indicators
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      child: Row(
                        children: [
                          _buildIndicatorPill(
                            label: 'Hijau',
                            range: '≥ ${targetAmanGlobal.toStringAsFixed(0)}%',
                            bgColor: const Color(0xFFECFDF5),
                            borderColor: const Color(0xFFA7F3D0),
                            textColor: const Color(0xFF059669),
                          ),
                          const SizedBox(width: 6),
                          _buildIndicatorPill(
                            label: 'Kuning',
                            range: '${kuningMin.toStringAsFixed(0)}% - ${(targetAmanGlobal - 1).clamp(0, 100).toStringAsFixed(0)}%',
                            bgColor: const Color(0xFFFFFBEB),
                            borderColor: const Color(0xFFFDE68A),
                            textColor: const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 6),
                          _buildIndicatorPill(
                            label: 'Merah',
                            range: '< ${kuningMin.toStringAsFixed(0)}%',
                            bgColor: const Color(0xFFFFF1F2),
                            borderColor: const Color(0xFFFECDD3),
                            textColor: const Color(0xFFE11D48),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

        // Table
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
                  ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                  : _buildKpiTable(),
        ),
      ],
    );
  }

  Widget _buildKpiTable() {
    final list = _data!['kpi_per_cabang'] as List;
    if (list.isEmpty) return const Center(child: Text('Tidak ada data'));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final kpiOmzet = (item['kpi_omzet'] as num).toDouble();
        final targetAman = (item['target_aman'] as num).toDouble();
        final growth = (item['growth'] as num).toDouble();

        Color statusColor;
        Color statusBgColor;
        IconData statusIcon;

        final double kuningThreshold = (targetAman - 20.0).clamp(0.0, 100.0);

        if (kpiOmzet >= targetAman) {
          statusColor = const Color(0xFF059669); // Emerald Green
          statusBgColor = const Color(0xFFECFDF5);
          statusIcon = Icons.trending_up_rounded;
        } else if (kpiOmzet >= kuningThreshold) {
          statusColor = const Color(0xFFD97706); // Amber / Yellow
          statusBgColor = const Color(0xFFFEF3C7);
          statusIcon = Icons.trending_flat_rounded;
        } else {
          statusColor = const Color(0xFFE11D48); // Rose / Red
          statusBgColor = const Color(0xFFFFE4E6);
          statusIcon = Icons.trending_down_rounded;
        }

        final omzetDicapai = _formatCurrency(item['omzet_dicapai']);
        final targetOmzet = _formatCurrency(item['target_omzet']);
        final progress = (item['target_omzet'] as num) > 0
            ? ((item['omzet_dicapai'] as num) / (item['target_omzet'] as num)).clamp(0.0, 1.0).toDouble()
            : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Cabang & KPI Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          statusIcon,
                          color: statusColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        item['nama_cabang'].toString().toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${kpiOmzet.toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 14),
              // Body Grid: Omzet Dicapai vs Target Omzet
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OMZET DICAPAI',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          omzetDicapai,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'TARGET OMZET',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          targetOmzet,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 2: Target Aman vs Growth
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Target Aman: ',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        '${item['target_aman']}%',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Growth: ',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (growth >= 0 ? Colors.green : Colors.red).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: growth >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        );
      },
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
              size: 16,
              color: isSelected ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textDark,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorPill({
    required String label,
    required String range,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: textColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              range,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: textColor.withValues(alpha: 0.9),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String title, String subtitle) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: color),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  // --- ORDER TAB FILTER GETTERS & BADGES ---
  int get _activeOrderFiltersCount {
    int count = 0;
    if (_selectedOrderCabangId != null) count++;
    if (_selectedOrderStatus != null && _selectedOrderStatus!.isNotEmpty) count++;
    if (_selectedOrderPeriode != 'Semua' && _selectedOrderPeriode.isNotEmpty) count++;
    return count;
  }

  Widget _buildOrderActiveBadge({required String label, required VoidCallback onRemove}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption({
    required String label,
    required String? value,
    required String? selectedValue,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isSelected = selectedValue == value;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? color : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // --- MODAL FILTER FOR SEMUA ORDER ---
  void _showOrderFilterModal() {
    int? tempCabangId = _selectedOrderCabangId;
    String? tempStatus = _selectedOrderStatus;
    String tempPeriode = _selectedOrderPeriode;
    DateTime? tempCustomStart = _orderCustomStartDate;
    DateTime? tempCustomEnd = _orderCustomEndDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Filter Pencarian Order',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            padding: const EdgeInsets.all(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- 1. CABANG ---
                          Text(
                            'CABANG',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int?>(
                                value: tempCabangId,
                                isExpanded: true,
                                hint: Text(
                                  'Semua Cabang',
                                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
                                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                                items: [
                                  DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('Semua Cabang', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                  ),
                                  ..._cabangs.map((c) {
                                    return DropdownMenuItem<int?>(
                                      value: c['id'],
                                      child: Text(
                                        c['nama_cabang'] ?? '-',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  setModalState(() => tempCabangId = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // --- 2. STATUS ORDER ---
                          Text(
                            'STATUS ORDER',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildStatusOption(
                                label: 'Semua Status',
                                value: null,
                                selectedValue: tempStatus,
                                color: const Color(0xFF0F172A),
                                onTap: () => setModalState(() => tempStatus = null),
                              ),
                              _buildStatusOption(
                                label: 'Process',
                                value: 'process',
                                selectedValue: tempStatus,
                                color: const Color(0xFF0284C7),
                                onTap: () => setModalState(() => tempStatus = 'process'),
                              ),
                              _buildStatusOption(
                                label: 'Done',
                                value: 'done',
                                selectedValue: tempStatus,
                                color: const Color(0xFF16A34A),
                                onTap: () => setModalState(() => tempStatus = 'done'),
                              ),
                              _buildStatusOption(
                                label: 'Pending',
                                value: 'pending',
                                selectedValue: tempStatus,
                                color: const Color(0xFFD97706),
                                onTap: () => setModalState(() => tempStatus = 'pending'),
                              ),
                              _buildStatusOption(
                                label: 'Cancelled',
                                value: 'cancelled',
                                selectedValue: tempStatus,
                                color: const Color(0xFFDC2626),
                                onTap: () => setModalState(() => tempStatus = 'cancelled'),
                              ),
                              _buildStatusOption(
                                label: 'Draft',
                                value: 'draft',
                                selectedValue: tempStatus,
                                color: const Color(0xFF64748B),
                                onTap: () => setModalState(() => tempStatus = 'draft'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // --- 3. PERIODE TANGGAL ---
                          Text(
                            'PERIODE WAKTU',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _orderPeriodeFilters.map((p) {
                              final isSelected = tempPeriode == p;
                              return InkWell(
                                onTap: () async {
                                  if (p == 'Rentang Waktu') {
                                    final picked = await showDateRangePicker(
                                      context: context,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                      initialDateRange: tempCustomStart != null && tempCustomEnd != null
                                          ? DateTimeRange(start: tempCustomStart!, end: tempCustomEnd!)
                                          : null,
                                    );
                                    if (picked != null) {
                                      setModalState(() {
                                        tempPeriode = p;
                                        tempCustomStart = picked.start;
                                        tempCustomEnd = picked.end;
                                      });
                                    }
                                  } else {
                                    setModalState(() {
                                      tempPeriode = p;
                                      tempCustomStart = null;
                                      tempCustomEnd = null;
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    p == 'Rentang Waktu' && tempCustomStart != null && tempCustomEnd != null
                                        ? '${DateFormat('dd MMM').format(tempCustomStart!)} - ${DateFormat('dd MMM').format(tempCustomEnd!)}'
                                        : p,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                      color: isSelected ? AppColors.primary : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Buttons
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedOrderCabangId = null;
                                _selectedOrderStatus = null;
                                _selectedOrderPeriode = 'Semua';
                                _orderCustomStartDate = null;
                                _orderCustomEndDate = null;
                              });
                              Navigator.pop(context);
                              _fetchOrders();
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Reset Filter',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedOrderCabangId = tempCabangId;
                                _selectedOrderStatus = tempStatus;
                                _selectedOrderPeriode = tempPeriode;
                                _orderCustomStartDate = tempCustomStart;
                                _orderCustomEndDate = tempCustomEnd;
                              });
                              Navigator.pop(context);
                              _fetchOrders();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Terapkan Filter',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- TAB 2: SEMUA ORDER ---
  Widget _buildSemuaOrderTab() {
    final activeCount = _activeOrderFiltersCount;
    final bool hasActiveFilters = activeCount > 0;

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      color: AppColors.primary,
      child: Column(
        children: [
          // Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Search Field
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _orderSearchController,
                                onChanged: _onOrderSearchChanged,
                                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w500),
                                decoration: InputDecoration(
                                  hintText: 'Cari customer, ID, atau cleaner...',
                                  hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                                ),
                              ),
                            ),
                            if (_orderSearchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF64748B)),
                                onPressed: () {
                                  _orderSearchController.clear();
                                  _fetchOrders();
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Unified Filter Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showOrderFilterModal,
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: hasActiveFilters ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: hasActiveFilters ? AppColors.primary : const Color(0xFFCBD5E1),
                              width: 1.5,
                            ),
                            boxShadow: hasActiveFilters
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                size: 18,
                                color: hasActiveFilters ? Colors.white : const Color(0xFF334155),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                hasActiveFilters ? 'Filter ($activeCount)' : 'Filter',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: hasActiveFilters ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Active Badges Row (if active)
                if (hasActiveFilters) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (_selectedOrderCabangId != null)
                          _buildOrderActiveBadge(
                            label: _cabangs.firstWhere(
                              (c) => c['id'] == _selectedOrderCabangId,
                              orElse: () => {'nama_cabang': 'Cabang'},
                            )['nama_cabang'],
                            onRemove: () {
                              setState(() => _selectedOrderCabangId = null);
                              _fetchOrders();
                            },
                          ),
                        if (_selectedOrderStatus != null && _selectedOrderStatus!.isNotEmpty)
                          _buildOrderActiveBadge(
                            label: 'Status: ${_selectedOrderStatus!.toUpperCase()}',
                            onRemove: () {
                              setState(() => _selectedOrderStatus = null);
                              _fetchOrders();
                            },
                          ),
                        if (_selectedOrderPeriode != 'Semua')
                          _buildOrderActiveBadge(
                            label: _selectedOrderPeriode == 'Rentang Waktu' && _orderCustomStartDate != null
                                ? '${DateFormat('dd MMM').format(_orderCustomStartDate!)} - ${DateFormat('dd MMM').format(_orderCustomEndDate!)}'
                                : _selectedOrderPeriode,
                            onRemove: () {
                              setState(() {
                                _selectedOrderPeriode = 'Semua';
                                _orderCustomStartDate = null;
                                _orderCustomEndDate = null;
                              });
                              _fetchOrders();
                            },
                          ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedOrderCabangId = null;
                              _selectedOrderStatus = null;
                              _selectedOrderPeriode = 'Semua';
                              _orderCustomStartDate = null;
                              _orderCustomEndDate = null;
                            });
                            _fetchOrders();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Reset Semua',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Orders List
          Expanded(
            child: _isLoadingOrders
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _ordersError.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
                              const SizedBox(height: 10),
                              Text(_ordersError, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.red, fontSize: 13)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _fetchOrders,
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _ordersList.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
                                    child: const Icon(Icons.receipt_long_rounded, size: 40, color: AppColors.primary),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Tidak Ada Data Order',
                                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tidak ditemukan pesanan yang sesuai dengan filter.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _ordersList.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _ordersList[index] as Map<String, dynamic>;
                              return _buildOrderCard(item);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> item) {
    final String idOrder = item['nomor_pesanan'] ?? item['id_order'] ?? (item['id'] != null ? '#${item['id']}' : '-');
    final String cabangName = item['cabang']?['nama_cabang'] ?? '-';
    final String customerName = item['pelanggan']?['nama_pelanggan'] ?? item['nama_customer'] ?? '-';
    
    // Status
    final String status = item['status_order_utama'] ?? item['status_pesanan'] ?? 'Pending';
    Color statusColor = const Color(0xFF64748B);
    Color statusBg = const Color(0xFFF1F5F9);

    final statusLower = status.toLowerCase();
    if (statusLower == 'process' || statusLower.contains('progress')) {
      statusColor = const Color(0xFF0284C7);
      statusBg = const Color(0xFFE0F2FE);
    } else if (statusLower == 'done' || statusLower.contains('selesai')) {
      statusColor = const Color(0xFF16A34A);
      statusBg = const Color(0xFFDCFCE7);
    } else if (statusLower == 'cancelled' || statusLower.contains('batal')) {
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEE2E2);
    } else if (statusLower == 'pending') {
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFEF3C7);
    }

    // Tanggal
    String tanggalStr = '-';
    if (item['tanggal_input'] != null) {
      try {
        tanggalStr = DateFormat('dd MMM yyyy').format(DateTime.parse(item['tanggal_input']));
      } catch (_) {}
    } else if (item['created_at'] != null) {
      try {
        tanggalStr = DateFormat('dd MMM yyyy').format(DateTime.parse(item['created_at']));
      } catch (_) {}
    }

    // Total
    final num totalHarga = num.tryParse(item['subtotal']?.toString() ?? item['total_harga']?.toString() ?? item['total']?.toString() ?? '0') ?? 0;
    final String formattedTotal = _formatCurrency(totalHarga);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: ID Order & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                idOrder,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1D4ED8),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Row 1: Cabang & Tanggal Pengerjaan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    cabangName,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    tanggalStr,
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Customer & Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.person_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        customerName,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formattedTotal,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
