import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/data/order_model.dart';
import '../../orders/services/order_service.dart';
import '../../../core/widgets/weekly_date_picker.dart';

class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({super.key});

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  final OrderService _orderService = OrderService();
  String _userName = 'Finance';
  List<OrderModel> _orders = [];
  bool _isLoading = false;
  String _error = '';
  DateTime? _filterStart;
  DateTime? _filterEnd;
  String _query = ''; // DatePicker requires this

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _fetchData();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Finance';
    });
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final data = await _orderService.fetchOrders();
      if (mounted) {
        setState(() {
          _orders = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _fmt(int n) =>
      'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
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
                    Text(
                      'Ringkasan Keuangan',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatsContent(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsContent() {
    if (_isLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.only(top: 40),
        child: CircularProgressIndicator(),
      ));
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 40),
            const SizedBox(height: 10),
            Text(_error, style: GoogleFonts.inter(color: AppColors.error)),
            TextButton(
              onPressed: _fetchData,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    int countWaiting = 0;
    int countApproved = 0;
    int countRejected = 0;
    
    int totalApproved = 0;
    int totalRejected = 0;

    for (final o in _orders) {
      // Date filter
      if (_filterStart != null && _filterEnd != null) {
        if (o.scheduleDateTime.isBefore(_filterStart!) || o.scheduleDateTime.isAfter(_filterEnd!)) {
          continue;
        }
      }

      // Calc math
      final double diskonPersen = o.pembayaran?.diskonPersen ?? 0.0;
      final int diskonValue = (o.total * (diskonPersen / 100)).round();
      final int totalSetelahDiskon = o.total - diskonValue;
      final int ppnPersen = o.pembayaran?.ppn ?? 11;
      final int ppnValue = (totalSetelahDiskon * (ppnPersen / 100)).round();
      final int totalAkhir = totalSetelahDiskon + ppnValue;

      // Classify
      bool isRejected = o.status == OrderStatus.cancelled || o.pembayaran?.statusPembayaran == 'rejected';
      bool isApproved = o.status == OrderStatus.completed || o.pembayaran?.statusPembayaran == 'approved';
      bool isWaiting = o.status == OrderStatus.waitingPaymentApproval || o.status == OrderStatus.waitingCancelApproval;

      if (isRejected) {
        countRejected++;
        totalRejected += totalAkhir;
      } else if (isApproved) {
        countApproved++;
        totalApproved += totalAkhir;
      } else if (isWaiting) {
        countWaiting++;
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total Disetujui\n($countApproved Pesanan)',
                value: _fmt(totalApproved),
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success,
                bg: AppColors.success.withOpacity(0.1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Menunggu Approve',
                value: '$countWaiting',
                icon: Icons.pending_actions_rounded,
                color: const Color(0xFFF59E0B),
                bg: const Color(0xFFFEF3C7),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Total Ditolak\n($countRejected Pesanan)',
                value: _fmt(totalRejected),
                icon: Icons.cancel_outlined,
                color: AppColors.error,
                bg: AppColors.error.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selamat Datang,',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userName,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Finance',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
