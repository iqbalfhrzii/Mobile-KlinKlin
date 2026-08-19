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
  final List<String> _filters = ['Bulan Ini', 'Kemarin', 'Hari Ini', 'Kustom Tanggal'];
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
        end = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month + 1, 0));
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
          start = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
          end = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month + 1, 0));
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
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
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
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.06),
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
                    Icon(Icons.flag_rounded, color: AppColors.primary, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Target Aman Global: ',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                    ),
                    Text(
                      '${_data!['target_aman_global']}%',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildLegendItem(Colors.green, 'Hijau', '≥100%'),
                    _buildLegendItem(Colors.amber.shade700, 'Kuning', '70%-99%'),
                    _buildLegendItem(Colors.red, 'Merah', '<70%'),
                  ],
                ),
              ],
            ),
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

        if (kpiOmzet >= targetAman) {
          statusColor = Colors.green;
          statusBgColor = Colors.green.withValues(alpha: 0.1);
          statusIcon = Icons.trending_up_rounded;
        } else if (kpiOmzet >= 70.0) {
          statusColor = Colors.amber.shade700;
          statusBgColor = Colors.amber.withValues(alpha: 0.15);
          statusIcon = Icons.trending_flat_rounded;
        } else {
          statusColor = Colors.red;
          statusBgColor = Colors.red.withValues(alpha: 0.1);
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

  Widget _buildLegendItem(Color color, String title, String subtitle) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
      ],
    );
  }

  // --- TAB 2: SEMUA ORDER ---
  Widget _buildSemuaOrderTab() {
    return RefreshIndicator(
      onRefresh: _fetchOrders,
      color: AppColors.primary,
      child: Column(
        children: [
          // Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Field
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 10),

                // Cabang & Status Order Dropdowns
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedOrderCabangId,
                            isExpanded: true,
                            hint: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 20),
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                            items: [
                              DropdownMenuItem<int>(value: null, child: Text('Semua Cabang', style: GoogleFonts.inter(fontWeight: FontWeight.normal))),
                              ..._cabangs.map((c) => DropdownMenuItem<int>(value: c['id'], child: Text(c['nama_cabang'] ?? '-'))),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedOrderCabangId = val);
                              _fetchOrders();
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedOrderStatus,
                            isExpanded: true,
                            hint: Text('Semua Status', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 20),
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('Semua Status')),
                              DropdownMenuItem(value: 'process', child: Text('Process')),
                              DropdownMenuItem(value: 'done', child: Text('Done')),
                              DropdownMenuItem(value: 'pending', child: Text('Pending')),
                              DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                              DropdownMenuItem(value: 'draft', child: Text('Draft')),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedOrderStatus = val);
                              _fetchOrders();
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Periode Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _orderPeriodeFilters.map((f) {
                      final isSelected = _selectedOrderPeriode == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => _onOrderPeriodeChanged(f),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              f == 'Rentang Waktu' && _orderCustomStartDate != null && isSelected
                                  ? '${DateFormat('dd MMM').format(_orderCustomStartDate!)} - ${DateFormat('dd MMM').format(_orderCustomEndDate!)}'
                                  : f,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
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
    final String idOrder = item['id_order'] ?? (item['id'] != null ? '#${item['id']}' : '-');
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
