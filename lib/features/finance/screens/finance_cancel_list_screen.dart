import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/data/order_model.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/finance_service.dart';
import 'finance_cancel_detail_screen.dart';

class FinanceCancelListScreen extends StatefulWidget {
  const FinanceCancelListScreen({super.key});

  @override
  State<FinanceCancelListScreen> createState() => _FinanceCancelListScreenState();
}

class _FinanceCancelListScreenState extends State<FinanceCancelListScreen> {
  final FinanceService _financeService = FinanceService();
  bool _isLoading = true;
  String _error = '';
  List<OrderModel> _orders = [];
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
      final orders = await _financeService.fetchPembatalan();
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

  @override
  Widget build(BuildContext context) {
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
                    : _orders.isEmpty
                        ? const Center(child: Text('Tidak ada pesanan yang dibatalkan.'))
                        : RefreshIndicator(
                            onRefresh: _fetchOrders,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _orders.length,
                              itemBuilder: (context, index) {
                                final order = _orders[index];
                                return _buildOrderItem(order, context);
                              },
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
              Text('Daftar Pembatalan', style: GoogleFonts.inter(
                  fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
              Text('Pesanan Batal', style: GoogleFonts.inter(
                  fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(OrderModel order, BuildContext context) {
    final statusColor = order.status == OrderStatus.cancelled ? AppColors.error : const Color(0xFFF59E0B);
    final statusText = order.status == OrderStatus.cancelled ? 'Dibatalkan' : 'Menunggu Approval Batal';
    
    final payment = order.pembayaran;
    final int grandTotal = payment?.total ?? (order.total + (order.total * 0.11).round());
    final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => FinanceCancelDetailScreen(order: order),
        ));
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
                  order.nomorPesanan.isNotEmpty ? order.nomorPesanan : 'Order #${order.id}',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.cancelReason ?? 'Tidak ada alasan penolakan',
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
