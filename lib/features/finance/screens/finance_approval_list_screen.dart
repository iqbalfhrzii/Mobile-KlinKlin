import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/data/order_model.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/weekly_date_picker.dart';
import '../services/finance_service.dart';
import 'finance_approval_detail_screen.dart';

class FinanceApprovalListScreen extends StatefulWidget {
  const FinanceApprovalListScreen({super.key});

  @override
  State<FinanceApprovalListScreen> createState() => _FinanceApprovalListScreenState();
}

class _FinanceApprovalListScreenState extends State<FinanceApprovalListScreen> {
  final FinanceService _financeService = FinanceService();
  bool _isLoading = true;
  String _error = '';
  List<OrderModel> _orders = [];
  int _limit = 5;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchOrders(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrders({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }
    try {
      final orders = await _financeService.fetchPendingPembayaran();
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  String _periodFilter = 'semua';
  DateTimeRange? _customRange;
  DateTime? _filterStart;
  DateTime? _filterEnd;
  String _searchQuery = '';
  String? _selectedCabangName;

  bool _matchesDateFilter(DateTime dt) {
    if (_periodFilter == 'semua') {
      return true;
    }
    if (_periodFilter == 'weekly_date' && _filterStart != null && _filterEnd != null) {
      final start = DateTime(_filterStart!.year, _filterStart!.month, _filterStart!.day);
      final end = DateTime(_filterEnd!.year, _filterEnd!.month, _filterEnd!.day, 23, 59, 59);
      return !dt.isBefore(start) && !dt.isAfter(end);
    }
    final now = DateTime.now();
    if (_periodFilter == 'hari_ini') {
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    } else if (_periodFilter == 'kemarin') {
      final yest = now.subtract(const Duration(days: 1));
      return dt.year == yest.year && dt.month == yest.month && dt.day == yest.day;
    } else if (_periodFilter == 'besok') {
      final tom = now.add(const Duration(days: 1));
      return dt.year == tom.year && dt.month == tom.month && dt.day == tom.day;
    } else if (_periodFilter == 'bulan_ini') {
      return dt.year == now.year && dt.month == now.month;
    } else if (_periodFilter == 'custom' && _customRange != null) {
      final cStart = DateTime(_customRange!.start.year, _customRange!.start.month, _customRange!.start.day);
      final cEnd = DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day, 23, 59, 59);
      return !dt.isBefore(cStart) && !dt.isAfter(cEnd);
    }
    return true;
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _customRange ?? DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _periodFilter = 'custom';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _orders.where((o) {
      if (!_matchesDateFilter(o.tanggalInput)) return false;
      if (_selectedCabangName != null && _selectedCabangName!.isNotEmpty) {
        if (!o.customer.area.toUpperCase().contains(_selectedCabangName!)) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchCust = o.customer.name.toLowerCase().contains(q);
        final matchId = o.nomorPesanan.toLowerCase().contains(q);
        if (!matchCust && !matchId) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text(_error, style: const TextStyle(color: AppColors.error)))
                    : RefreshIndicator(
                        onRefresh: _fetchOrders,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // WeeklyDatePicker (Papan Tanggal Mingguan)
                              WeeklyDatePicker(
                                showAllMonthButton: false,
                                searchQuery: _searchQuery,
                                onSearchChanged: (val) => setState(() => _searchQuery = val),
                                onFilterChanged: (start, end) {
                                  setState(() {
                                    _filterStart = start;
                                    _filterEnd = end;
                                  });
                                },
                              ),
                              const SizedBox(height: 10),

                              // Row: Dropdown Filter Cabang & Dropdown Filter Waktu (Side-by-Side Bersebelahan)
                              Row(
                                children: [
                                  // 1. Dropdown Filter Cabang
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String?>(
                                          value: _selectedCabangName,
                                          hint: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w600)),
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMuted),
                                          isExpanded: true,
                                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w600),
                                          items: [
                                            DropdownMenuItem<String?>(value: null, child: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600))),
                                            ...['BALIKPAPAN', 'DENPASAR', 'MAKASSAR', 'MALANG', 'SURABAYA'].map((name) => DropdownMenuItem<String?>(
                                              value: name,
                                              child: Text(name, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                                            )),
                                          ],
                                          onChanged: (val) => setState(() => _selectedCabangName = val),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // 2. Dropdown Filter Waktu (Dipindahkan Bersebelahan dengan Filter Cabang!)
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _periodFilter,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMuted),
                                          isExpanded: true,
                                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w600),
                                          items: [
                                            DropdownMenuItem(value: 'semua', child: Text('Semua Waktu', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600))),
                                            DropdownMenuItem(value: 'hari_ini', child: Text('Hari Ini', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600))),
                                            DropdownMenuItem(value: 'kemarin', child: Text('Kemarin', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600))),
                                            DropdownMenuItem(value: 'besok', child: Text('Besok', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600))),
                                            DropdownMenuItem(value: 'bulan_ini', child: Text('Bulan Ini', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600))),
                                            DropdownMenuItem(
                                              value: 'custom',
                                              child: Text(
                                                _customRange != null
                                                    ? '${DateFormat('dd/MM').format(_customRange!.start)} - ${DateFormat('dd/MM').format(_customRange!.end)}'
                                                    : 'Kustom Tanggal...',
                                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                          onChanged: (val) {
                                            if (val == 'custom') {
                                              _pickCustomRange();
                                            } else if (val != null) {
                                              setState(() {
                                                _periodFilter = val;
                                                if (val == 'semua') {
                                                  _filterStart = null;
                                                  _filterEnd = null;
                                                }
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              if (filteredOrders.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 40),
                                  child: Center(child: Text('Tidak ada pembayaran yang sesuai filter.')),
                                )
                              else ...[
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filteredOrders.take(_limit).length,
                                  itemBuilder: (context, index) {
                                    final order = filteredOrders[index];
                                    return _buildOrderItem(order, context);
                                  },
                                ),
                                if (_limit < filteredOrders.length)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: InkWell(
                                      onTap: () => setState(() => _limit += 5),
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: const Color(0xFF0284C7), width: 1.2),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF0284C7)),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Tampilkan Lebih Banyak (${_limit > filteredOrders.length ? filteredOrders.length : _limit} dari ${filteredOrders.length})',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF0284C7),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pending', style: GoogleFonts.inter(
                  fontSize: 11, color: Colors.white.withOpacity(0.7))),
              Text('Pembayaran', style: GoogleFonts.inter(
                  fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(OrderModel order, BuildContext context) {
    final payment = order.pembayaran;
    final int grandTotal = payment?.total ?? (order.total + (order.total * 0.11).round());
    final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(context, MaterialPageRoute(
          builder: (_) => FinanceApprovalDetailScreen(order: order),
        ));
        if (result == true) {
          _fetchOrders();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [AppColors.cardShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.id}',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Menunggu',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Text(order.customer.name, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.payments_outlined, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Text(
                  payment != null ? 'Pembayaran diajukan oleh CS' : '-',
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Tagihan', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                Text(
                  formatCurrency.format(grandTotal),
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
