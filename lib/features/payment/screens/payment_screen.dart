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
  String _periodFilter = 'weekly_date';
  DateTimeRange? _customRange;

  String _fmt(int n) =>
      'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

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
      final initialOrders = await svc.fetchOrders(fetchAllPages: false, perPage: 30);
      if (mounted) {
        setState(() {
          _allOrders = initialOrders;
          _isLoading = false;
        });
      }

      svc.fetchOrders(fetchAllPages: true, perPage: 50).then((allOrders) {
        if (mounted && allOrders.length > initialOrders.length) {
          setState(() {
            _allOrders = allOrders;
          });
        }
      }).catchError((_) {});
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<OrderModel> get _allFilteredWithoutStatus {
    return _allOrders.where((o) {
      final q = _query.toLowerCase();
      final matchQ =
          o.nomorPesanan.toLowerCase().contains(q) ||
          o.customer.name.toLowerCase().contains(q) ||
          o.services.any((s) => s.name.toLowerCase().contains(q));

      bool matchDate = true;
      final dt = o.scheduleDateTime;
      final now = DateTime.now();

      if (_periodFilter == 'semua') {
        matchDate = true;
      } else if (_periodFilter == 'weekly_date') {
        matchDate =
            _filterStart == null ||
            (!dt.isBefore(_filterStart!) && !dt.isAfter(_filterEnd!));
      } else if (_periodFilter == 'hari_ini') {
        matchDate =
            dt.year == now.year && dt.month == now.month && dt.day == now.day;
      } else if (_periodFilter == 'kemarin') {
        final yest = now.subtract(const Duration(days: 1));
        matchDate =
            dt.year == yest.year &&
            dt.month == yest.month &&
            dt.day == yest.day;
      } else if (_periodFilter == 'besok') {
        final tmr = now.add(const Duration(days: 1));
        matchDate =
            dt.year == tmr.year && dt.month == tmr.month && dt.day == tmr.day;
      } else if (_periodFilter == 'bulan_ini') {
        matchDate = dt.year == now.year && dt.month == now.month;
      } else if (_periodFilter == 'custom' && _customRange != null) {
        final cStart = DateTime(
          _customRange!.start.year,
          _customRange!.start.month,
          _customRange!.start.day,
        );
        final cEnd = DateTime(
          _customRange!.end.year,
          _customRange!.end.month,
          _customRange!.end.day,
          23,
          59,
          59,
        );
        matchDate = !dt.isBefore(cStart) && !dt.isAfter(cEnd);
      }

      return matchQ && matchDate;
    }).toList();
  }

  List<OrderModel> get _filtered {
    return _allFilteredWithoutStatus.where((o) {
      final isOrderCancelled =
          o.status == OrderStatus.cancelled ||
          o.status == OrderStatus.waitingCancelApproval ||
          o.paymentStatus == 'cancelled';

      if (_statusFilter == 'Dibatalkan') {
        return isOrderCancelled;
      }
      if (_statusFilter == 'Ditolak') {
        return o.paymentStatus == 'rejected';
      }

      if (_statusFilter != 'Semua' && isOrderCancelled) return false;

      if (_statusFilter == 'Belum Lunas') {
        return o.paymentStatus == 'unpaid' &&
            o.status != OrderStatus.waitingPaymentApproval;
      } else if (_statusFilter == 'Pending') {
        return o.status == OrderStatus.waitingPaymentApproval || o.paymentStatus == 'pending';
      } else if (_statusFilter == 'Sudah Lunas') {
        return o.paymentStatus == 'paid' || o.paymentStatus == 'approved';
      }

      return true; // For 'Semua'
    }).toList();
  }

  List<OrderModel> get _unpaid => _filtered
      .where(
        (o) =>
            o.paymentStatus == 'unpaid' &&
            o.status != OrderStatus.waitingPaymentApproval,
      )
      .toList();
  List<OrderModel> get _waitingApprove => _filtered
      .where((o) => o.status == OrderStatus.waitingPaymentApproval || o.paymentStatus == 'pending')
      .toList();
  List<OrderModel> get _paid => _filtered
      .where((o) => o.paymentStatus == 'paid' || o.paymentStatus == 'approved')
      .toList();
  List<OrderModel> get _cancelled => _filtered
      .where(
        (o) =>
            o.status == OrderStatus.cancelled ||
            o.status == OrderStatus.waitingCancelApproval ||
            o.paymentStatus == 'cancelled',
      )
      .toList();
  List<OrderModel> get _rejected => _filtered
      .where((o) => o.paymentStatus == 'rejected')
      .toList();

  int _calculateOrderTotal(OrderModel o) {
    final int baseSubtotal = (o.subtotal > 0)
        ? o.subtotal
        : (o.services.isNotEmpty
            ? o.services.fold(0, (sum, s) => sum + s.subtotal)
            : o.total);
    final double diskonPersen = o.pembayaran?.diskonPersen ?? 0.0;
    final int diskonValue = (baseSubtotal * (diskonPersen / 100)).round();
    final int totalSetelahDiskon = baseSubtotal - diskonValue;
    final int ppnPersen = o.ppn ?? (o.pembayaran?.ppn ?? (o.isWajibPpn ? 11 : 0));
    final int ppnValue = (o.pembayaran != null || o.ppn != null)
        ? (totalSetelahDiskon * (ppnPersen / 100)).round()
        : 0;
    return totalSetelahDiskon + ppnValue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
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
                            onSearchChanged: (val) =>
                                setState(() => _query = val),
                            onFilterChanged: (start, end) {
                              setState(() {
                                _filterStart = start;
                                _filterEnd = end;
                                if (start != null)
                                  _periodFilter = 'weekly_date';
                              });
                            },
                            trailingWidget: _buildFilterButton(),
                          ),
                          const SizedBox(height: 14),
                          _buildSummaryCards(),
                          const SizedBox(height: 16),
                          if (_unpaid.isNotEmpty &&
                              (_statusFilter == 'Semua' ||
                                  _statusFilter == 'Belum Lunas')) ...[
                            _sectionLabel(
                              'BELUM LUNAS',
                              AppColors.statusPending,
                            ),
                            const SizedBox(height: 8),
                            ..._unpaid.map(
                              (o) => _PaymentCard(
                                order: o,
                                onTap: () => _openDetail(context, o),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_waitingApprove.isNotEmpty &&
                              (_statusFilter == 'Semua' ||
                                  _statusFilter == 'Pending')) ...[
                            _sectionLabel('Pending', AppColors.primary),
                            const SizedBox(height: 8),
                            ..._waitingApprove.map(
                              (o) => _PaymentCard(
                                order: o,
                                onTap: () => _openDetail(context, o),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_paid.isNotEmpty &&
                              (_statusFilter == 'Semua' ||
                                  _statusFilter == 'Sudah Lunas')) ...[
                            _sectionLabel('SUDAH LUNAS', AppColors.statusDone),
                            const SizedBox(height: 8),
                            ..._paid.map(
                              (o) => _PaymentCard(
                                order: o,
                                onTap: () => _openDetail(context, o),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_rejected.isNotEmpty &&
                              (_statusFilter == 'Semua' ||
                                  _statusFilter == 'Ditolak')) ...[
                            _sectionLabel('DITOLAK', AppColors.error),
                            const SizedBox(height: 8),
                            ..._rejected.map(
                              (o) => _PaymentCard(
                                order: o,
                                onTap: () => _openDetail(context, o),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_cancelled.isNotEmpty &&
                              (_statusFilter == 'Semua' ||
                                  _statusFilter == 'Dibatalkan')) ...[
                            _sectionLabel('DIBATALKAN', AppColors.error),
                            const SizedBox(height: 8),
                            ..._cancelled.map(
                              (o) => _PaymentCard(
                                order: o,
                                onTap: () => _openDetail(context, o),
                              ),
                            ),
                          ],
                          if (_filtered.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Center(
                                child: Text(
                                  'Tidak ada data',
                                  style: GoogleFonts.inter(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
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
    final unresolvedCount = _allOrders
        .where(
          (o) =>
              o.status != OrderStatus.cancelled &&
              o.status != OrderStatus.waitingCancelApproval &&
              (o.paymentStatus == 'unpaid' ||
                  o.paymentStatus == 'pending' ||
                  o.status == OrderStatus.waitingPaymentApproval),
        )
        .length;

    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Row(
        children: [
          if (Navigator.canPop(context)) ...[
            HeaderBackButton(onTap: () => Navigator.pop(context)),
            const SizedBox(width: 12),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manajemen',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              Text(
                _statusFilter == 'Dibatalkan'
                    ? 'Cancel Pembayaran'
                    : 'Pembayaran',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$unresolvedCount Belum Lunas',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange:
          _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _periodFilter = 'custom';
      });
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            const statuses = [
              'Semua',
              'Belum Lunas',
              'Pending',
              'Sudah Lunas',
              'Ditolak',
              'Dibatalkan',
            ];
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter Cash Flow',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // 1. Status Pembayaran
                    Text(
                      'Status Pembayaran',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: statuses.map((f) {
                        final isSel = _statusFilter == f;
                        return ChoiceChip(
                          label: Text(f == 'Semua' ? 'Semua Status' : f),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => _statusFilter = f);
                              setState(() => _statusFilter = f);
                            }
                          },
                          selectedColor: const Color(0xFFEFF6FF),
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSel
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSel
                                ? const Color(0xFF1D4ED8)
                                : AppColors.textDark,
                          ),
                          side: BorderSide(
                            color: isSel
                                ? const Color(0xFF3B82F6)
                                : Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // 2. Rentang Waktu
                    Text(
                      'Rentang Waktu',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...[
                          {'key': 'semua', 'label': 'Semua Waktu'},
                          {'key': 'hari_ini', 'label': 'Hari Ini'},
                          {'key': 'kemarin', 'label': 'Kemarin'},
                          {'key': 'besok', 'label': 'Besok'},
                          {'key': 'bulan_ini', 'label': 'Bulan Ini'},
                        ].map((item) {
                          final isSel = _periodFilter == item['key'];
                          return ChoiceChip(
                            label: Text(item['label']!),
                            selected: isSel,
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  _periodFilter = item['key']!;
                                  _customRange = null;
                                  if (_periodFilter == 'semua') {
                                    _filterStart = null;
                                    _filterEnd = null;
                                  }
                                });
                                setState(() {
                                  _periodFilter = item['key']!;
                                  _customRange = null;
                                  if (_periodFilter == 'semua') {
                                    _filterStart = null;
                                    _filterEnd = null;
                                  }
                                });
                              } else {
                                setModalState(() {
                                  _periodFilter = 'weekly_date';
                                  _customRange = null;
                                });
                                setState(() {
                                  _periodFilter = 'weekly_date';
                                  _customRange = null;
                                });
                              }
                            },
                            selectedColor: const Color(0xFFECFDF5),
                            labelStyle: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSel
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSel
                                  ? const Color(0xFF047857)
                                  : AppColors.textDark,
                            ),
                            side: BorderSide(
                              color: isSel
                                  ? const Color(0xFF10B981)
                                  : Colors.grey.shade300,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            showCheckmark: false,
                          );
                        }),
                        ActionChip(
                          avatar: const Icon(
                            Icons.calendar_month_rounded,
                            size: 14,
                            color: Color(0xFF4F46E5),
                          ),
                          label: Text(
                            _periodFilter == 'custom' && _customRange != null
                                ? '${_customRange!.start.day}/${_customRange!.start.month} - ${_customRange!.end.day}/${_customRange!.end.month}'
                                : 'Pilih Tanggal',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: _periodFilter == 'custom'
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _periodFilter == 'custom'
                                  ? const Color(0xFF4F46E5)
                                  : AppColors.textDark,
                            ),
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _pickCustomRange();
                          },
                          backgroundColor: _periodFilter == 'custom'
                              ? const Color(0xFFEEF2FF)
                              : Colors.white,
                          side: BorderSide(
                            color: _periodFilter == 'custom'
                                ? const Color(0xFF6366F1)
                                : Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Button Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                _statusFilter = 'Semua';
                                _periodFilter = 'weekly_date';
                                _customRange = null;
                                _filterStart = null;
                                _filterEnd = null;
                              });
                              setState(() {
                                _statusFilter = 'Semua';
                                _periodFilter = 'weekly_date';
                                _customRange = null;
                                _filterStart = null;
                                _filterEnd = null;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Reset',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Terapkan Filter',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterButton() {
    return GestureDetector(
      onTap: _showFilterBottomSheet,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.tune_rounded, size: 16, color: AppColors.textDark),
            const SizedBox(width: 6),
            Text(
              'Filter',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final activeOrders = _allFilteredWithoutStatus;
    final unpaidOrders = activeOrders
        .where(
          (o) =>
              o.status != OrderStatus.cancelled &&
              o.status != OrderStatus.waitingCancelApproval &&
              (o.paymentStatus == 'unpaid' || o.paymentStatus == 'pending') &&
              o.status != OrderStatus.waitingPaymentApproval,
        )
        .toList();
    final waitingOrders = activeOrders
        .where((o) => o.status == OrderStatus.waitingPaymentApproval)
        .toList();
    final paidOrders = activeOrders
        .where(
          (o) => o.paymentStatus == 'paid' || o.paymentStatus == 'approved',
        )
        .toList();
    final cancelledOrders = activeOrders
        .where(
          (o) =>
              o.status == OrderStatus.cancelled ||
              o.status == OrderStatus.waitingCancelApproval ||
              o.paymentStatus == 'cancelled' ||
              o.paymentStatus == 'rejected',
        )
        .toList();

    final totalPending =
        unpaidOrders.fold<int>(0, (s, o) => s + _calculateOrderTotal(o)) +
        waitingOrders.fold<int>(0, (s, o) => s + _calculateOrderTotal(o));
    final totalPaid = paidOrders.fold<int>(
      0,
      (s, o) => s + _calculateOrderTotal(o),
    );
    final totalCancelled = cancelledOrders.fold<int>(
      0,
      (s, o) => s + _calculateOrderTotal(o),
    );

    return Row(
      children: [
        Expanded(
          child: _SmallCard(
            label: 'Belum Lunas',
            value: _fmt(totalPending),
            icon: Icons.pending_actions_rounded,
            color: AppColors.statusPending,
            bg: AppColors.statusPendingBg,
            count: unpaidOrders.length + waitingOrders.length,
            isActive:
                _statusFilter == 'Semua' ||
                _statusFilter == 'Belum Lunas' ||
                _statusFilter == 'Pending',
            onTap: () => setState(
              () => _statusFilter =
                  (_statusFilter == 'Belum Lunas' || _statusFilter == 'Pending')
                  ? 'Semua'
                  : 'Belum Lunas',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SmallCard(
            label: 'Sudah Lunas',
            value: _fmt(totalPaid),
            icon: Icons.check_circle_rounded,
            color: AppColors.statusDone,
            bg: AppColors.statusDoneBg,
            count: paidOrders.length,
            isActive:
                _statusFilter == 'Semua' || _statusFilter == 'Sudah Lunas',
            onTap: () => setState(
              () => _statusFilter = _statusFilter == 'Sudah Lunas'
                  ? 'Semua'
                  : 'Sudah Lunas',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SmallCard(
            label: 'Dibatalkan',
            value: _fmt(totalCancelled),
            icon: Icons.cancel_presentation_rounded,
            color: AppColors.error,
            bg: const Color(0xFFFEF2F2),
            count: cancelledOrders.length,
            isActive: _statusFilter == 'Semua' || _statusFilter == 'Dibatalkan',
            onTap: () => setState(
              () => _statusFilter = _statusFilter == 'Dibatalkan'
                  ? 'Semua'
                  : 'Dibatalkan',
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String t, Color c) => Row(
    children: [
      Container(
        width: 3,
        height: 14,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        t,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: c,
          letterSpacing: 0.5,
        ),
      ),
    ],
  );

  Future<void> _openDetail(BuildContext context, OrderModel order) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaymentDetailScreen(order: order)),
    );
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

  int _calculateCardTotal(OrderModel o) {
    final int baseSubtotal = (o.subtotal > 0)
        ? o.subtotal
        : (o.services.isNotEmpty
            ? o.services.fold(0, (sum, s) => sum + s.subtotal)
            : o.total);
    final double diskonPersen = o.pembayaran?.diskonPersen ?? 0.0;
    final int diskonValue = (baseSubtotal * (diskonPersen / 100)).round();
    final int totalSetelahDiskon = baseSubtotal - diskonValue;
    final int ppnPersen = o.ppn ?? (o.pembayaran?.ppn ?? (o.isWajibPpn ? 11 : 0));
    final int ppnValue = (o.pembayaran != null || o.ppn != null)
        ? (totalSetelahDiskon * (ppnPersen / 100)).round()
        : 0;
    return totalSetelahDiskon + ppnValue;
  }

  String _fmt(int n) =>
      'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  @override
  Widget build(BuildContext context) {
    final isCancelled =
        order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.waitingCancelApproval ||
        order.paymentStatus == 'cancelled' ||
        order.pembatalanId != null;
    final isPaid =
        order.paymentStatus == 'paid' || order.paymentStatus == 'approved';
    final isPending = !isCancelled &&
        (order.paymentStatus == 'pending' ||
        order.status == OrderStatus.waitingPaymentApproval);

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
                ? AppColors.error.withValues(alpha: 0.2)
                : AppColors.border,
          ),
          boxShadow: [AppColors.cardShadow],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        order.nomorPesanan,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 6),
                      StatusBadge(status: order.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.customer.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    order.services.map((s) => s.name).join(', '),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.payment_rounded,
                        size: 11,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.paymentMethod == '-'
                            ? 'Belum dipilih'
                            : order.paymentMethod
                                  .replaceAll('_', ' ')
                                  .split(' ')
                                  .map(
                                    (s) => s.isNotEmpty
                                        ? '${s[0].toUpperCase()}${s.substring(1)}'
                                        : '',
                                  )
                                  .join(' '),
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
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _fmt(order.pembayaran?.total ?? _calculateCardTotal(order)),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? AppColors.error.withValues(alpha: 0.1)
                        : isPaid
                        ? AppColors.statusDoneBg
                        : isPending
                        ? AppColors.statusPendingBg
                        : AppColors.surfaceBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isCancelled
                        ? 'Batal'
                        : isPaid
                        ? 'Lunas'
                        : isPending
                        ? 'Pending'
                        : 'Belum',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isCancelled
                          ? AppColors.error
                          : isPaid
                          ? AppColors.statusDone
                          : isPending
                          ? AppColors.statusPending
                          : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.textMuted,
                ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 12),
                  ),
                  const Spacer(),
                  Text(
                    '$count tx',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
