import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/whatsapp_icon.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/data/order_model.dart';
import '../../../core/widgets/weekly_date_picker.dart';
import 'order_detail_screen.dart';
import 'create_order_screen.dart';
import '../services/order_service.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderListScreen extends StatefulWidget {
  final String? initialStatusFilter;
  final bool isTodayOnly;

  const OrderListScreen({
    super.key,
    this.initialStatusFilter,
    this.isTodayOnly = false,
  });

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final OrderService _orderService = OrderService();
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  String _error = '';

  String _query = '';
  String _statusFilter = 'Semua';
  DateTime? _filterStart;
  DateTime? _filterEnd;

  static const _filters = [
    'Semua',
    'draft',
    'assigned',
    'inProgress',
    'finishedByCleaner',
    'waitingPaymentApproval',
    'completed',
    'cancelled',
  ];
  static const _filterLabels = {
    'Semua': 'Semua',
    'draft': 'Draft',
    'assigned': 'Ditugaskan',
    'inProgress': 'Dikerjakan',
    'finishedByCleaner': 'Selesai (Cleaner)',
    'waitingPaymentApproval': 'Menunggu Approve',
    'completed': 'Selesai',
    'cancelled': 'Dibatalkan',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialStatusFilter != null) {
      _statusFilter = widget.initialStatusFilter!;
    }
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final data = await _orderService.fetchOrders();
      setState(() {
        _orders = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<OrderModel> get _filtered {
    return _orders.where((o) {
      final q = _query.toLowerCase();
      final matchQ =
          o.nomorPesanan.toLowerCase().contains(q) ||
          o.customer.name.toLowerCase().contains(q) ||
          o.services.any((s) => s.name.toLowerCase().contains(q));
      final matchF = _statusFilter == 'Semua' || o.status.name == _statusFilter;
      final matchDate =
          _filterStart == null ||
          (!o.scheduleDateTime.isBefore(_filterStart!) &&
              !o.scheduleDateTime.isAfter(_filterEnd!));
      return matchQ && matchF && matchDate;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    WeeklyDatePicker(
                      searchQuery: _query,
                      initialDate: widget.isTodayOnly ? DateTime.now() : null,
                      onSearchChanged: (val) => setState(() => _query = val),
                      onFilterChanged: (start, end) {
                        setState(() {
                          _filterStart = start;
                          _filterEnd = end;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildFilterRow(context),
                    const SizedBox(height: 12),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                                size: 40,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _error,
                                style: GoogleFonts.inter(
                                  color: AppColors.error,
                                ),
                              ),
                              TextButton(
                                onPressed: _fetchData,
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            'Tidak ada pesanan',
                            style: GoogleFonts.inter(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._filtered.map(
                        (o) => _OrderCard(
                          order: o,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderDetailScreen(order: o),
                              ),
                            );
                            _fetchData();
                          },
                          onRefresh: _fetchData,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'order_fab',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
          );
          _fetchData();
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manajemen',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  Text(
                    'Pesanan',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_filtered.length} Pesanan',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Status filter chips
          ..._filters.map((f) {
            final active = _statusFilter == f;
            return GestureDetector(
              onTap: () => setState(() => _statusFilter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  _filterLabels[f]!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onTap,
    required this.onRefresh,
  });
  final OrderModel order;
  final VoidCallback onTap;
  final VoidCallback onRefresh;

  String _fmt(int n) =>
      'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  String _formatDisplayDate(String schedule) {
    if (schedule.isEmpty || schedule == '-') return '-';
    final parts = schedule.split('·');
    final datePart = parts[0].trim();
    String timePart = parts.length > 1 ? parts[1].trim() : '';

    if (timePart.endsWith(':00')) {
      final tParts = timePart.split(':');
      if (tParts.length >= 2) {
        timePart = '${tParts[0]}:${tParts[1]}';
      }
    }

    try {
      final dt = DateTime.parse(datePart);
      final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
      final months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      final dayNameReal = days[dt.weekday == 7 ? 0 : dt.weekday];
      final monthName = months[dt.month - 1];

      final formattedDate = '$dayNameReal, ${dt.day} $monthName ${dt.year}';
      return timePart.isNotEmpty ? '$formattedDate - $timePart' : formattedDate;
    } catch (e) {
      return schedule;
    }
  }

  Future<void> _launchWA(
    BuildContext context,
    String noWa, {
    String? template,
  }) async {
    String phone = noWa.replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('0')) {
      phone = '62${phone.substring(1)}';
    }
    final url = Uri.parse(
      'https://wa.me/$phone${template != null ? '?text=${Uri.encodeComponent(template)}' : ''}',
    );
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = order;
    final isCancelled = o.status == OrderStatus.cancelled;

    // Calculate total price accurately
    final double diskonPersen = o.pembayaran?.diskonPersen ?? 0.0;
    final int diskonValue = (o.total * (diskonPersen / 100)).round();
    final int totalSetelahDiskon = o.total - diskonValue;
    final int ppnPersen = o.ppn ?? o.pembayaran?.ppn ?? 0;
    final int ppnValue = (o.pembayaran != null || o.ppn != null)
        ? (totalSetelahDiskon * (ppnPersen / 100)).round()
        : 0;
    final int totalAkhir = totalSetelahDiskon + ppnValue;

    String dateStr = _formatDisplayDate(o.schedule);
    final bool isDone = o.status == OrderStatus.completed;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [AppColors.cardShadow],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  color: isCancelled
                      ? AppColors.error
                      : (isDone ? AppColors.statusDone : AppColors.primary),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                o.customer.name,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(status: o.status, order: o),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                dateStr,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.border.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                o.paymentMethod.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark.withOpacity(0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Text(
                              _fmt(totalAkhir),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              ' · ',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                o.cleaners.isNotEmpty
                                    ? o.cleaners.map((c) => c.name).join(', ')
                                    : 'Belum ada cleaner',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        child: Text(
                          o.services.map((s) => s.name).join(', '),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFAD6800),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (o.customer.address.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 2,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  o.customer.address,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),
                      const Divider(color: AppColors.border, height: 1),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [

                            InkWell(
                              onTap: () => _launchWA(context, o.customer.phone),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                     const WhatsAppIcon(
                                       size: 18,
                                       color: Colors.white,
                                     ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Cust',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (o.cleaners.isNotEmpty) ...[
                              InkWell(
                                onTap: () {
                                  final withPhone = o.cleaners.firstWhere(
                                    (c) => c.phone.isNotEmpty,
                                    orElse: () => o.cleaners.first,
                                  );
                                  _launchWA(
                                    context,
                                    withPhone.phone.isNotEmpty
                                        ? withPhone.phone
                                        : '',
                                  );
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF25D366),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                       const WhatsAppIcon(
                                         size: 18,
                                         color: Colors.white,
                                       ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Cleaner',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            // Removed Spacer and Edit button
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
