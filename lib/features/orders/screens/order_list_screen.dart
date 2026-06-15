import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/data/order_model.dart';
import 'order_detail_screen.dart';
import 'create_order_screen.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  String _query = '';
  String _statusFilter = 'Semua';
  DateTimeRange? _dateRange;

  static const _filters = ['Semua', 'pending', 'assigned', 'in_progress', 'completed', 'cancelled'];
  static const _filterLabels = {
    'Semua': 'Semua',
    'pending': 'Menunggu',
    'assigned': 'Ditugaskan',
    'in_progress': 'Dikerjakan',
    'completed': 'Selesai',
    'cancelled': 'Dibatalkan',
  };

  List<OrderModel> get _filtered {
    return mockOrders.where((o) {
      final q = _query.toLowerCase();
      final matchQ = o.id.toLowerCase().contains(q) ||
          o.customer.name.toLowerCase().contains(q) ||
          o.services.any((s) => s.name.toLowerCase().contains(q));
      final matchF = _statusFilter == 'Semua' || o.status == _statusFilter;
      final matchDate = _dateRange == null || (
        !o.scheduleDateTime.isBefore(_dateRange!.start) &&
        !o.scheduleDateTime.isAfter(_dateRange!.end)
      );
      return matchQ && matchF && matchDate;
    }).toList();
  }

  String _fmtDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    return '${d.day} ${m[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  _buildFilterRow(context),
                  const SizedBox(height: 12),
                  ..._filtered.map((o) => _OrderCard(
                    order: o,
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(order: o),
                      ));
                      setState(() {});
                    },
                  )),
                  if (_filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(child: Text('Tidak ada pesanan', style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                      ))),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'order_fab',
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOrderScreen()));
          setState(() {});
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
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Manajemen', style: GoogleFonts.inter(
                  fontSize: 11, color: Colors.white.withOpacity(0.7))),
                Text('Pesanan', style: GoogleFonts.inter(
                  fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_filtered.length} Pesanan', style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600,
                )),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Cari pesanan, pelanggan...',
              hintStyle: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.5), fontSize: 14),
              filled: true,
              fillColor: Colors.white.withOpacity(0.12),
              prefixIcon: Icon(Icons.search,
                  color: Colors.white.withOpacity(0.5), size: 18),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(BuildContext context) {
    final hasDate = _dateRange != null;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Date chip — same height as other chips
          DateChip(
            active: hasDate,
            label: hasDate
                ? '${_fmtDate(_dateRange!.start)} - ${_fmtDate(_dateRange!.end)}'
                : 'Tanggal',
            onTap: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2025),
                lastDate: DateTime(2027),
                initialDateRange: _dateRange,
                useRootNavigator: false,
                locale: const Locale('id'),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: AppColors.primary,
                      onPrimary: Colors.white,
                      surface: AppColors.surface,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (range != null) setState(() => _dateRange = range);
            },
            onClear: hasDate ? () => setState(() => _dateRange = null) : null,
          ),
          const SizedBox(width: 8),
          // Status filter chips
          ..._filters.map((f) {
            final active = _statusFilter == f;
            return GestureDetector(
              onTap: () => setState(() => _statusFilter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: active ? AppColors.primary : AppColors.border),
                ),
                child: Text(_filterLabels[f]!, style: GoogleFonts.inter(
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
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});
  final OrderModel order;
  final VoidCallback onTap;

  String _fmt(int n) => 'Rp ${n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    final o = order;
    final isCancelled = o.status == 'cancelled';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isCancelled
                  ? AppColors.error.withOpacity(0.2)
                  : AppColors.border),
          boxShadow: [AppColors.cardShadow],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(o.id,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontFamily: 'monospace')),
            const Spacer(),
            StatusBadge(status: o.status),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            InitialsAvatar(name: o.customer.name, size: 36),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(o.customer.name,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark)),
                  Text(o.services.map((s) => s.name).join(', '),
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textMuted),
                      overflow: TextOverflow.ellipsis),
                ])),
            Text(_fmt(o.total),
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.schedule_rounded,
                size: 12, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Expanded(
                child: Text(o.schedule,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textMuted))),
            if (o.cleaners.isNotEmpty)
              Text(o.cleaners.map((c) => c.name).join(', '),
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textMuted)),
          ]),
        ]),
      ),
    );
  }
}
