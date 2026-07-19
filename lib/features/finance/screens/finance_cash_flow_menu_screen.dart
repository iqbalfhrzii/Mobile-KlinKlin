import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/data/order_model.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/weekly_date_picker.dart';
import '../../orders/services/order_service.dart';
import '../services/finance_service.dart';
import 'finance_approval_detail_screen.dart';
import 'finance_cancel_detail_screen.dart';
import 'finance_processed_detail_screen.dart';

class FinanceCashFlowMenuScreen extends StatefulWidget {
  const FinanceCashFlowMenuScreen({super.key});

  @override
  State<FinanceCashFlowMenuScreen> createState() => _FinanceCashFlowMenuScreenState();
}

class _FinanceCashFlowMenuScreenState extends State<FinanceCashFlowMenuScreen> {
  String _query = '';
  DateTime? _filterStart;
  DateTime? _filterEnd;
  String _statusFilter = 'Approve'; // 'Approve', 'Batal', 'Riwayat'

  final OrderService _orderService = OrderService();
  final FinanceService _financeService = FinanceService();

  List<OrderModel> _allOrders = [];
  bool _isLoading = true;
  String _error = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadData(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }

    try {
      List<OrderModel> fetched = [];
      if (_statusFilter == 'Approve') {
        final allOrders = await _orderService.fetchOrders();
        fetched = allOrders.where((o) {
          final pStatus = o.paymentStatus.toLowerCase();
          final pPembayaranStatus = o.pembayaran?.statusPembayaran.toLowerCase() ?? '';
          if (pStatus == 'paid' || pStatus == 'approved' || pStatus == 'lunas' || pStatus == 'settlement') return false;
          if (o.status == OrderStatus.cancelled || pStatus == 'cancelled' || pStatus == 'rejected') return false;
          return o.status == OrderStatus.waitingPaymentApproval ||
              pStatus == 'pending' ||
              pStatus == 'waiting_approval' ||
              pPembayaranStatus == 'pending' ||
              pPembayaranStatus == 'waiting_approval' ||
              (o.paymentProof != null && o.paymentProof!.isNotEmpty);
        }).toList();
      } else if (_statusFilter == 'Batal') {
        fetched = await _financeService.fetchPembatalan(statusPesanan: 'waiting_cancel_approval');
      } else if (_statusFilter == 'Riwayat') {
        fetched = await _financeService.fetchProcessedOrders(statusApproval: 'approved');
      }

      if (mounted) {
        setState(() {
          _allOrders = fetched;
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

  List<OrderModel> get _filtered {
    return _allOrders.where((o) {
      final q = _query.toLowerCase();
      final matchQ = o.id.toLowerCase().contains(q) ||
          o.customer.name.toLowerCase().contains(q) ||
          o.services.any((s) => s.name.toLowerCase().contains(q));
      final matchDate = _filterStart == null || (
        !o.scheduleDateTime.isBefore(_filterStart!) &&
        !o.scheduleDateTime.isAfter(_filterEnd!)
      );
      return matchQ && matchDate;
    }).toList();
  }

  void _changeTab(String tab) {
    if (_statusFilter == tab) return;
    setState(() {
      _statusFilter = tab;
      _allOrders = [];
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading && _allOrders.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    onRefresh: () => _loadData(),
                    color: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          WeeklyDatePicker(
                            searchQuery: _query,
                            onSearchChanged: (val) => setState(() => _query = val),
                            onFilterChanged: (start, end) {
                              setState(() {
                                _filterStart = start;
                                _filterEnd = end;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildFilterRow(),
                          const SizedBox(height: 16),
                          
                          if (_error.isNotEmpty && _allOrders.isEmpty)
                            Center(child: Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Text(_error, style: const TextStyle(color: AppColors.error)),
                            ))
                          else if (_filtered.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Center(child: Text(
                                _statusFilter == 'Approve' ? 'Tidak ada pembayaran yang menunggu approval.' :
                                _statusFilter == 'Batal' ? 'Tidak ada pengajuan pembatalan.' :
                                'Belum ada riwayat pesanan yang diproses.',
                                style: GoogleFonts.inter(color: AppColors.textMuted),
                                textAlign: TextAlign.center,
                              )),
                            )
                          else
                            ..._filtered.map((o) => _buildOrderItem(o)),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Manajemen', style: GoogleFonts.inter(
                  fontSize: 11, color: Colors.white.withOpacity(0.7))),
              Text('Cash Flow', style: GoogleFonts.inter(
                  fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('Approve'),
          const SizedBox(width: 8),
          _filterChip('Batal'),
          const SizedBox(width: 8),
          _filterChip('Riwayat'),
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    final isSelected = _statusFilter == label;
    return GestureDetector(
      onTap: () => _changeTab(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderItem(OrderModel order) {
    if (_statusFilter == 'Approve') {
      return _buildApproveCard(order);
    } else if (_statusFilter == 'Batal') {
      return _buildCancelCard(order);
    } else {
      return _buildRiwayatCard(order);
    }
  }

  Widget _buildApproveCard(OrderModel order) {
    final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final totalAkhir = order.pembayaran?.total ?? (order.total + (order.total * 0.11).round());

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FinanceApprovalDetailScreen(order: order),
          ),
        );
        if (result == true) {
          _loadData();
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
                Text('Order #${order.id}', style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.statusPendingBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Menunggu Approval', style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.statusPending)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Text(order.customer.name, style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Pembayaran', style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textMuted)),
                Text(formatCurrency.format(totalAkhir), style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelCard(OrderModel order) {
    final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final totalAkhir = order.pembayaran?.total ?? (order.total + (order.total * 0.11).round());
    
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FinanceCancelDetailScreen(order: order),
          ),
        );
        if (result == true) {
          _loadData();
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
                Text('Order #${order.id}', style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Menunggu Approval Batal', style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B))),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Text(order.customer.name, style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.cancelReason ?? 'Tidak ada alasan pembatalan',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Tagihan', style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textMuted)),
                Text(formatCurrency.format(totalAkhir), style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiwayatCard(OrderModel order) {
    final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final totalAkhir = order.pembayaran?.total ?? (order.total + (order.total * 0.11).round());
    
    Color statusColor;
    String statusText;
    final payment = order.pembayaran;
    
    if (payment != null) {
      if (payment.statusPembayaran == 'approved') {
        statusColor = AppColors.success;
        statusText = 'Disetujui';
      } else if (payment.statusPembayaran == 'rejected') {
        statusColor = AppColors.error;
        statusText = 'Ditolak';
      } else {
        statusColor = Colors.grey;
        statusText = 'Selesai';
      }
    } else if (order.status == OrderStatus.cancelled) {
      statusColor = AppColors.error;
      statusText = 'Dibatalkan';
    } else {
      statusColor = Colors.grey;
      statusText = 'Selesai';
    }

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FinanceProcessedDetailScreen(order: order),
          ),
        );
        if (result == true) {
          _loadData();
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
                Text('Order #${order.id}', style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(statusText, style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Text(order.customer.name, style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Pembayaran', style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textMuted)),
                Text(formatCurrency.format(totalAkhir), style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
