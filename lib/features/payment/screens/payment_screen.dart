import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/data/order_model.dart';
import '../../../core/widgets/weekly_date_picker.dart';
import '../../orders/services/order_service.dart';
import 'payment_detail_screen.dart';

class PaymentScreen extends StatefulWidget {
  final bool isCancelMode;
  const PaymentScreen({super.key, this.isCancelMode = false});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _query = '';
  DateTime? _filterStart;
  DateTime? _filterEnd;
  String _statusFilter = 'Semua';

  String _fmt(int n) => 'Rp ${n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';


  List<OrderModel> _allOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final svc = OrderService();
      final orders = await svc.fetchOrders();
      setState(() {
        _allOrders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error)
        );
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
      
      // Filter by cancel mode
      bool matchStatus = true;
      if (widget.isCancelMode) {
        matchStatus = o.status == OrderStatus.cancelled || o.status == OrderStatus.waitingCancelApproval;
      } else {
        matchStatus = o.status != OrderStatus.cancelled && o.status != OrderStatus.waitingCancelApproval;
        if (_statusFilter == 'Belum') {
          matchStatus = matchStatus && (o.paymentStatus == 'unpaid' || o.paymentStatus == 'pending') && o.status != OrderStatus.waitingPaymentApproval;
        } else if (_statusFilter == 'Menunggu Approve') {
          matchStatus = matchStatus && (o.status == OrderStatus.waitingPaymentApproval);
        } else if (_statusFilter == 'Lunas') {
          matchStatus = matchStatus && (o.paymentStatus == 'paid' || o.paymentStatus == 'approved');
        }
      }
      
      return matchQ && matchDate && matchStatus;
    }).toList();
  }

  List<OrderModel> get _unpaid =>
      _filtered.where((o) => (o.paymentStatus == 'unpaid' || o.paymentStatus == 'pending') && o.status != OrderStatus.waitingPaymentApproval).toList();
  List<OrderModel> get _waitingApprove =>
      _filtered.where((o) => o.status == OrderStatus.waitingPaymentApproval).toList();
  List<OrderModel> get _paid =>
      _filtered.where((o) => o.paymentStatus == 'paid' || o.paymentStatus == 'approved').toList();
  List<OrderModel> get _cancelled =>
      _filtered.where((o) => o.status == OrderStatus.cancelled || o.status == OrderStatus.waitingCancelApproval || o.paymentStatus == 'cancelled' || o.paymentStatus == 'rejected').toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading 
                ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppColors.primary)))
                : RefreshIndicator(
                    onRefresh: _loadData,
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
                  if (!widget.isCancelMode) ...[
                    _buildFilterRow(context),
                    const SizedBox(height: 14),
                    _buildSummaryCards(),
                  ],
                  const SizedBox(height: 16),
                  if (!widget.isCancelMode && _unpaid.isNotEmpty && (_statusFilter == 'Semua' || _statusFilter == 'Belum')) ...[
                    _sectionLabel('BELUM LUNAS', AppColors.statusPending),
                    const SizedBox(height: 8),
                    ..._unpaid.map((o) => _PaymentCard(
                        order: o, onTap: () => _openDetail(context, o))),
                    const SizedBox(height: 16),
                  ],
                  if (!widget.isCancelMode && _waitingApprove.isNotEmpty && (_statusFilter == 'Semua' || _statusFilter == 'Menunggu Approve')) ...[
                    _sectionLabel('MENUNGGU APPROVE', AppColors.primary),
                    const SizedBox(height: 8),
                    ..._waitingApprove.map((o) => _PaymentCard(
                        order: o, onTap: () => _openDetail(context, o))),
                    const SizedBox(height: 16),
                  ],
                  if (!widget.isCancelMode && _paid.isNotEmpty && (_statusFilter == 'Semua' || _statusFilter == 'Lunas')) ...[
                    _sectionLabel('SUDAH LUNAS', AppColors.statusDone),
                    const SizedBox(height: 8),
                    ..._paid.map((o) => _PaymentCard(
                        order: o, onTap: () => _openDetail(context, o))),
                    const SizedBox(height: 16),
                  ],
                  if (widget.isCancelMode && _cancelled.isNotEmpty) ...[
                    _sectionLabel('DIBATALKAN', AppColors.error),
                    const SizedBox(height: 8),
                    ..._cancelled.map((o) => _PaymentCard(
                        order: o, onTap: () => _openDetail(context, o))),
                  ],
                  if (_filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(child: Text('Tidak ada data',
                          style: GoogleFonts.inter(color: AppColors.textMuted))),
                    ),
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
          HeaderBackButton(onTap: () => Navigator.pop(context)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.isCancelMode ? 'Manajemen' : 'Manajemen', style: GoogleFonts.inter(
                fontSize: 11, color: Colors.white.withOpacity(0.7))),
            Text(widget.isCancelMode ? 'Cancel Pembayaran' : 'Pembayaran', style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
          const Spacer(),
          if (!widget.isCancelMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${_unpaid.length + _waitingApprove.length} Belum Lunas', style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(BuildContext context) {
    const statuses = ['Semua', 'Belum', 'Menunggu Approve', 'Lunas'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (!widget.isCancelMode) ...statuses.map((m) {
            final active = _statusFilter == m;
            return GestureDetector(
              onTap: () => setState(() => _statusFilter = m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? AppColors.primary : AppColors.border),
                ),
                child: Text(m, style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.textMuted,
                )),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalPending = _unpaid.fold<int>(0, (s, o) => s + o.total) + _waitingApprove.fold<int>(0, (s, o) => s + o.total);
    final totalPaid = _paid.fold<int>(0, (s, o) => s + o.total);
    return Row(children: [
      Expanded(child: _SmallCard(
        label: 'Belum Lunas', value: _fmt(totalPending),
        icon: Icons.pending_actions_rounded,
        color: AppColors.statusPending, bg: AppColors.statusPendingBg,
        count: _unpaid.length + _waitingApprove.length,
        isActive: _statusFilter == 'Semua' || _statusFilter == 'Belum' || _statusFilter == 'Menunggu Approve',
        onTap: () => setState(() => _statusFilter = (_statusFilter == 'Belum' || _statusFilter == 'Menunggu Approve') ? 'Semua' : 'Belum'),
      )),
      const SizedBox(width: 10),
      Expanded(child: _SmallCard(
        label: 'Sudah Lunas', value: _fmt(totalPaid),
        icon: Icons.check_circle_rounded,
        color: AppColors.statusDone, bg: AppColors.statusDoneBg,
        count: _paid.length,
        isActive: _statusFilter == 'Semua' || _statusFilter == 'Lunas',
        onTap: () => setState(() => _statusFilter = _statusFilter == 'Lunas' ? 'Semua' : 'Lunas'),
      )),
    ]);
  }

  Widget _sectionLabel(String t, Color c) => Row(children: [
    Container(width: 3, height: 14,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(t, style: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w700, color: c, letterSpacing: 0.5)),
  ]);

  Future<void> _openDetail(BuildContext context, OrderModel order) async {
    final result = await Navigator.push(context, MaterialPageRoute(
      builder: (_) => PaymentDetailScreen(order: order),
    ));
    if (result == true) {
      _loadData();
    }
  }
}

// ── Payment Card ───────────────────────────────────────────────────────────
class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.order, required this.onTap});
  final OrderModel order;
  final VoidCallback onTap;

  String _fmt(int n) => 'Rp ${n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    final isCancelled = order.status == OrderStatus.cancelled || order.paymentStatus == 'cancelled' || order.paymentStatus == 'rejected';
    final isWaitingCancel = order.status == OrderStatus.waitingCancelApproval;
    final isPaid = order.paymentStatus == 'paid' || order.paymentStatus == 'approved';
    final isPending = order.paymentStatus == 'pending' || order.status == OrderStatus.waitingPaymentApproval;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isCancelled
                  ? AppColors.error.withOpacity(0.2)
                  : AppColors.border),
          boxShadow: [AppColors.cardShadow],
        ),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Row(children: [
              Text(order.id,
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontFamily: 'monospace')),
              const SizedBox(width: 6),
              StatusBadge(status: order.status),
            ]),
            const SizedBox(height: 4),
            Text(order.customer.name,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
            Text(order.services.map((s) => s.name).join(', '),
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.payment_rounded,
                  size: 11, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                  order.paymentMethod == '-' 
                      ? 'Belum dipilih' 
                      : order.paymentMethod.replaceAll('_', ' ').split(' ').map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '').join(' '),
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textMuted)),
            ]),
          ])),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_fmt(order.total),
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isCancelled || isWaitingCancel
                    ? AppColors.error.withOpacity(0.1)
                    : isPaid ? AppColors.statusDoneBg : isPending ? AppColors.statusPendingBg : AppColors.surfaceBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isCancelled ? 'Batal' : isWaitingCancel ? 'Menunggu Cancel' : isPaid ? 'Lunas' : isPending ? 'Menunggu Approval' : 'Belum',
                style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: isCancelled || isWaitingCancel
                      ? AppColors.error
                      : isPaid ? AppColors.statusDone : isPending ? AppColors.statusPending : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
          ]),
        ]),
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isActive ? color : AppColors.border),
            boxShadow: [if (isActive) AppColors.cardShadow],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 14)),
              const Spacer(),
              Text('$count transaksi',
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            Text(label,
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
      ),
    );
  }
}
