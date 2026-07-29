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

  List<OrderModel> _approveOrders = [];
  List<OrderModel> _batalOrders = [];
  List<OrderModel> _riwayatOrders = [];

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
      final results = await Future.wait([
        _orderService.fetchOrders(),
        _financeService.fetchPembatalan(statusPesanan: 'waiting_cancel_approval'),
        _financeService.fetchProcessedOrders(statusApproval: 'approved'),
      ]);

      final allOrders = results[0];
      final approveList = allOrders.where((o) {
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

      if (mounted) {
        setState(() {
          _approveOrders = approveList;
          _batalOrders = results[1];
          _riwayatOrders = results[2];
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

  List<OrderModel> _applyFilters(List<OrderModel> list, {bool ignoreDate = false}) {
    return list.where((o) {
      final q = _query.toLowerCase();
      final matchQ = o.nomorPesanan.toLowerCase().contains(q) ||
          o.customer.name.toLowerCase().contains(q) ||
          o.services.any((s) => s.name.toLowerCase().contains(q));
      final matchDate = ignoreDate || _filterStart == null || (
        !o.scheduleDateTime.isBefore(_filterStart!) &&
        !o.scheduleDateTime.isAfter(_filterEnd!)
      );
      return matchQ && matchDate;
    }).toList();
  }

  List<OrderModel> get _currentList {
    if (_statusFilter == 'Approve') return _approveOrders;
    if (_statusFilter == 'Batal') return _batalOrders;
    if (_statusFilter == 'Riwayat') return _riwayatOrders;
    return [..._approveOrders, ..._batalOrders, ..._riwayatOrders];
  }

  List<OrderModel> get _filteredApprove => _applyFilters(_approveOrders, ignoreDate: true);
  List<OrderModel> get _filteredBatal => _applyFilters(_batalOrders, ignoreDate: true);
  List<OrderModel> get _filteredRiwayat => _applyFilters(_riwayatOrders, ignoreDate: false);

  List<OrderModel> get _filtered {
    if (_statusFilter == 'Approve') return _filteredApprove;
    if (_statusFilter == 'Batal') return _filteredBatal;
    if (_statusFilter == 'Riwayat') return _filteredRiwayat;
    return [..._filteredApprove, ..._filteredBatal, ..._filteredRiwayat];
  }

  void _changeTab(String tab) {
    if (_statusFilter == tab) {
      setState(() => _statusFilter = 'Semua');
    } else {
      setState(() => _statusFilter = tab);
    }
  }

  int _calculateOrderTotal(OrderModel o) {
    final double diskonPersen = o.pembayaran?.diskonPersen ?? 0.0;
    final int diskonValue = (o.total * (diskonPersen / 100)).round();
    final int totalSetelahDiskon = o.total - diskonValue;
    final int ppnPersen = o.ppn ?? o.pembayaran?.ppn ?? 0;
    final int ppnValue = (o.pembayaran != null || o.ppn != null)
        ? (totalSetelahDiskon * (ppnPersen / 100)).round()
        : 0;
    return totalSetelahDiskon + ppnValue;
  }

  String _fmt(int n) => 'Rp ${n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading && _currentList.isEmpty
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
                          _buildSummaryCards(),
                          const SizedBox(height: 16),
                          
                          if (_error.isNotEmpty && _currentList.isEmpty)
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
                                _statusFilter == 'Riwayat' ? 'Belum ada riwayat pesanan yang diproses.' :
                                'Tidak ada transaksi.',
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

  Widget _buildSummaryCards() {
    final totalApprove = _filteredApprove.fold<int>(0, (s, o) => s + _calculateOrderTotal(o));
    final totalBatal = _filteredBatal.fold<int>(0, (s, o) => s + _calculateOrderTotal(o));
    final totalRiwayat = _filteredRiwayat.fold<int>(0, (s, o) => s + _calculateOrderTotal(o));

    return Row(children: [
      Expanded(child: _SmallCard(
        label: 'Approve', value: _fmt(totalApprove),
        icon: Icons.pending_actions_rounded,
        color: AppColors.primary, bg: AppColors.surfaceBlue,
        count: _filteredApprove.length,
        isActive: _statusFilter == 'Semua' || _statusFilter == 'Approve',
        onTap: () => _changeTab('Approve'),
      )),
      const SizedBox(width: 8),
      Expanded(child: _SmallCard(
        label: 'Batal', value: _fmt(totalBatal),
        icon: Icons.cancel_presentation_rounded,
        color: const Color(0xFFF59E0B), bg: const Color(0xFFF59E0B).withOpacity(0.1),
        count: _filteredBatal.length,
        isActive: _statusFilter == 'Semua' || _statusFilter == 'Batal',
        onTap: () => _changeTab('Batal'),
      )),
      const SizedBox(width: 8),
      Expanded(child: _SmallCard(
        label: 'Riwayat', value: _fmt(totalRiwayat),
        icon: Icons.history_rounded,
        color: AppColors.statusDone, bg: AppColors.statusDoneBg,
        count: _filteredRiwayat.length,
        isActive: _statusFilter == 'Semua' || _statusFilter == 'Riwayat',
        onTap: () => _changeTab('Riwayat'),
      )),
    ]);
  }

  Widget _buildOrderItem(OrderModel order) {
    if (_approveOrders.any((o) => o.id == order.id)) {
      return _buildApproveCard(order);
    } else if (_batalOrders.any((o) => o.id == order.id)) {
      return _buildCancelCard(order);
    } else {
      return _buildRiwayatCard(order);
    }
  }

  Widget _buildApproveCard(OrderModel order) {
    final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final totalAkhir = _calculateOrderTotal(order);

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
                Text('Order #${order.nomorPesanan}', style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.statusPendingBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Pending', style: GoogleFonts.inter(
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
    final totalAkhir = _calculateOrderTotal(order);
    
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
                Text('Order #${order.nomorPesanan}', style: GoogleFonts.inter(
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
    final totalAkhir = _calculateOrderTotal(order);
    
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
                Text('Order #${order.nomorPesanan}', style: GoogleFonts.inter(
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

class _SmallCard extends StatelessWidget {
  const _SmallCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
    required this.count,
    this.isActive = true,
    this.onTap,
  });
  final String label, value;
  final IconData icon;
  final Color color, bg;
  final int count;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isActive ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isActive ? color : AppColors.border),
            boxShadow: [if (isActive) AppColors.cardShadow],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 12)),
              const Spacer(),
              Text('$count tx',
                  style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
          ]),
        ),
      ),
    );
  }
}
