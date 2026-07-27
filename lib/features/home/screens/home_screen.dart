import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';
import 'dart:io';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../orders/screens/order_list_screen.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/services/auth_service.dart';
import '../../orders/screens/create_order_screen.dart';
import '../../customers/screens/customer_list_screen.dart';
import '../../orders/services/order_service.dart';
import '../../../core/data/order_model.dart';
import '../../orders/screens/order_detail_screen.dart';
import '../../profile/screens/kpi_screen.dart';
import '../../attendance/screens/attendance_screen.dart';
import 'chat_harian_screen.dart';
import '../services/dashboard_service.dart';
import 'package:fl_chart/fl_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoadingStats = true;
  int _omzetThisMonth = 0;
  int _omzetToday = 0;
  double _rataRataOrder = 0;
  int _targetOmzet = 15000000;
  int _ordersToday = 0;
  int _waiting = 0;
  int _active = 0;
  int _doneToday = 0;
  List<dynamic> _grafikHarian = [];
  List<dynamic> _grafikBulanan = [];
  List<OrderModel> _recentOrders = [];

  String _userName = 'Memuat...';
  String _userRole = 'Customer Service';
  String _userBranch = '-';
  String? _userPhoto;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadStats();
    AuthService.profileUpdateNotifier.addListener(_loadProfile);
  }

  Future<void> _loadStats() async {
    _loadProfile();
    try {
      final dbData = await DashboardService().fetchCsDashboard();
      final orders = await OrderService()
          .fetchOrders(); // Only fetch for recent orders or we can leave it

      if (mounted) {
        setState(() {
          if (dbData.isNotEmpty) {
            _omzetThisMonth = dbData['omzet_bulan_ini'] ?? 0;
            _omzetToday = dbData['omzet_hari_ini'] ?? 0;
            _rataRataOrder = (dbData['rata_rata_order'] ?? 0).toDouble();
            _targetOmzet = dbData['target_omzet'] ?? 15000000;
            _ordersToday = dbData['pesanan_hari_ini'] ?? 0;
            _waiting = dbData['menunggu_approve'] ?? 0;
            _active = dbData['dikerjakan'] ?? 0;
            _doneToday = dbData['selesai_hari_ini'] ?? 0;
            _grafikHarian = dbData['grafik_harian'] ?? [];
            _grafikBulanan = dbData['grafik_bulanan'] ?? [];
          } else {
            // Fallback for when VPS API is not yet updated
            int omzetBulan = 0;
            int omzetHari = 0;
            int countToday = 0;
            int waiting = 0;
            int active = 0;
            int done = 0;
            final now = DateTime.now();

            for (var o in orders) {
              bool isToday =
                  o.scheduleDateTime.year == now.year &&
                  o.scheduleDateTime.month == now.month &&
                  o.scheduleDateTime.day == now.day;
              bool isThisMonth =
                  o.scheduleDateTime.year == now.year &&
                  o.scheduleDateTime.month == now.month;

              if (isThisMonth) omzetBulan += o.total;
              if (isToday) {
                omzetHari += o.total;
                countToday++;
                if (o.status == OrderStatus.completed) done++;
              }
              if (o.status == OrderStatus.waitingPaymentApproval) waiting++;
              if (o.status == OrderStatus.assigned ||
                  o.status == OrderStatus.inProgress ||
                  o.status == OrderStatus.draft)
                active++;
            }

            _omzetThisMonth = omzetBulan;
            _omzetToday = omzetHari;
            _rataRataOrder = orders.isNotEmpty
                ? (omzetBulan / orders.length).toDouble()
                : 0;
            _targetOmzet = 15000000;
            _ordersToday = countToday;
            _waiting = waiting;
            _active = active;
            _doneToday = done;
            _grafikHarian = [];
            _grafikBulanan = [];
          }

          _recentOrders = orders.take(3).toList();
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  @override
  void dispose() {
    AuthService.profileUpdateNotifier.removeListener(_loadProfile);
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'CS';
      _userRole = prefs.getString('user_role') ?? 'Customer Service';
      _userBranch = prefs.getString('user_branch') ?? '-';
      _userPhoto = prefs.getString('user_photo');
    });

    try {
      final meResponse = await AuthService.getMe();
      final me = meResponse['data'] ?? meResponse;
      if (mounted) {
        setState(() {
          _userName = me['nama'] ?? _userName;
          _userPhoto = me['foto_profil'];
          _userRole = me['jabatan'] is Map
              ? me['jabatan']['nama_jabatan'] ?? _userRole
              : _userRole;
          _userBranch = me['cabang'] is Map
              ? me['cabang']['nama_cabang'] ?? _userBranch
              : _userBranch;
        });
      }
    } catch (_) {}
  }

  String _formatRupiah(int n) =>
      'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoadingStats
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadStats,
                    color: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatCards(),
                          const SizedBox(height: 16),
                          _buildOmzetCard(),
                          const SizedBox(height: 16),
                          _buildGrafikHarian(),
                          const SizedBox(height: 16),
                          _buildGrafikBulanan(),
                          const SizedBox(height: 16),
                          _buildQuickActions(),
                          const SizedBox(height: 16),
                          _buildRecentOrders(),
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
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Selamat Pagi'
        : hour < 15
        ? 'Selamat Siang'
        : hour < 18
        ? 'Selamat Sore'
        : 'Selamat Malam';

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
                  Image.asset('assets/images/logo.png', height: 24),
                  const SizedBox(height: 4),
                  Text(
                    greeting + ',',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '$_userName ✨',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _userRole,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (_userBranch != '-') ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '📍 $_userBranch',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const Spacer(),
              _buildAvatar(),
            ],
          ),
          const SizedBox(height: 16),
          // Omzet mini
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Omzet Hari Ini',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      _formatRupiah(_omzetToday),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Aktif',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (_userPhoto == null || _userPhoto!.isEmpty) {
      return InitialsAvatar(
        name: _userName,
        size: 48,
        backgroundColor: Colors.white.withOpacity(0.2),
        textColor: Colors.white,
        borderColor: Colors.white.withOpacity(0.35),
      );
    }

    if (_userPhoto!.startsWith('data:image')) {
      try {
        final base64Str = _userPhoto!.split(',').last;
        return ClipOval(
          child: Image.memory(
            base64Decode(base64Str),
            width: 48,
            height: 48,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        return InitialsAvatar(
          name: _userName,
          size: 48,
          backgroundColor: Colors.white.withOpacity(0.2),
          textColor: Colors.white,
          borderColor: Colors.white.withOpacity(0.35),
        );
      }
    }

    if (_userPhoto!.startsWith('http')) {
      return ClipOval(
        child: Image.network(
          _userPhoto!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => InitialsAvatar(
            name: _userName,
            size: 48,
            backgroundColor: Colors.white.withOpacity(0.2),
            textColor: Colors.white,
            borderColor: Colors.white.withOpacity(0.35),
          ),
        ),
      );
    }

    if (_userPhoto!.startsWith('/')) {
      return ClipOval(
        child: Image.file(
          File(_userPhoto!),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => InitialsAvatar(
            name: _userName,
            size: 48,
            backgroundColor: Colors.white.withOpacity(0.2),
            textColor: Colors.white,
            borderColor: Colors.white.withOpacity(0.35),
          ),
        ),
      );
    }

    return ClipOval(
      child: Image.network(
        'http://192.168.1.242:8000/storage/$_userPhoto',
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => InitialsAvatar(
          name: _userName,
          size: 48,
          backgroundColor: Colors.white.withOpacity(0.2),
          textColor: Colors.white,
          borderColor: Colors.white.withOpacity(0.35),
        ),
      ),
    );
  }

  Widget _buildStatCards() {
    final items = [
      _Stat(
        'Pesanan Hari Ini',
        '$_ordersToday',
        Icons.receipt_long_rounded,
        AppColors.primaryMid,
        hint: 'Total Order Hari Ini',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const OrderListScreen(isTodayOnly: true),
            ),
          );
        },
      ),
      _Stat(
        'Menunggu Approve',
        '$_waiting',
        Icons.hourglass_empty_rounded,
        AppColors.statusPending,
        hint: 'Payment Approval',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const OrderListScreen(
                initialStatusFilter: 'waitingPaymentApproval',
              ),
            ),
          );
        },
      ),
      _Stat(
        'Dikerjakan',
        '$_active',
        Icons.cleaning_services_rounded,
        AppColors.statusProgress,
        hint: 'Process & Pending',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const OrderListScreen(initialStatusFilter: 'inProgress'),
            ),
          );
        },
      ),
      _Stat(
        'Selesai',
        '$_doneToday',
        Icons.check_circle_rounded,
        AppColors.statusDone,
        hint: 'Status Done',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const OrderListScreen(initialStatusFilter: 'completed'),
            ),
          );
        },
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.map((s) => _StatCard(stat: s)).toList(),
    );
  }

  Widget _buildOmzetCard() {
    final omzet = _omzetThisMonth;
    final target = _targetOmzet;
    final pct = (omzet / (target > 0 ? target : 1)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.35),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.trending_up_rounded, color: Color(0xFF34D399), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'OMZET BULAN BERJALAN',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF34D399),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatRupiah(omzet),
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rata-rata Order',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatRupiah(_rataRataOrder.toInt()),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target Bulanan: ${_formatRupiah(target)}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              Text(
                '${(pct * 100).round()}%',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF34D399),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF10B981),
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrafikHarian() {
    if (_grafikHarian.isEmpty) return const SizedBox();

    List<FlSpot> spots = [];
    for (int i = 0; i < _grafikHarian.length; i++) {
      double val = double.tryParse(_grafikHarian[i]['omzet'].toString()) ?? 0;
      spots.add(FlSpot(i.toDouble(), val));
    }

    double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (maxY == 0) maxY = 1000000;

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
          Text(
            'Omzet 7 Hari Terakhir',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= _grafikHarian.length) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _grafikHarian[index]['hari'] ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: maxY / 4,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox();
                        return Text(
                          '${(value / 1000).toStringAsFixed(0)}K',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (_grafikHarian.length - 1).toDouble(),
                minY: 0,
                maxY: maxY * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrafikBulanan() {
    if (_grafikBulanan.isEmpty) return const SizedBox();

    List<BarChartGroupData> barGroups = [];
    double maxY = 0;

    for (int i = 0; i < _grafikBulanan.length; i++) {
      double val = double.tryParse(_grafikBulanan[i]['omzet'].toString()) ?? 0;
      if (val > maxY) maxY = val;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: AppColors.primaryMid,
              width: 14,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    if (maxY == 0) maxY = 1000000;

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
          Text(
            'Grafik Omzet Bulanan',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= _grafikBulanan.length)
                          return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _grafikBulanan[index]['nama_bulan'] ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: maxY / 4,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox();
                        return Text(
                          '${(value / 1000000).toStringAsFixed(1)}M',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction(
        'Buat Pesanan',
        Icons.add_circle_outline_rounded,
        AppColors.primary,
        AppColors.surfaceBlue,
      ),
      _QuickAction(
        'Kelola Pelanggan',
        Icons.people_outline_rounded,
        const Color(0xFF7C3AED),
        const Color(0xFFEDE9FE),
      ),
      _QuickAction(
        'Absensi',
        Icons.fingerprint_rounded,
        const Color(0xFF0ea5e9),
        const Color(0xFFe0f2fe),
      ),
      _QuickAction(
        'Chat Harian',
        Icons.forum_outlined,
        const Color(0xFFEC4899),
        const Color(0xFFFCE7F3),
      ),
      _QuickAction(
        'KPI Karyawan',
        Icons.analytics_rounded,
        const Color(0xFFE65100),
        const Color(0xFFFFF3E0),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aksi Cepat',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: actions
              .map(
                (a) => Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (a.label == 'Buat Pesanan') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateOrderScreen(),
                          ),
                        );
                      } else if (a.label == 'KPI Karyawan') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const KpiScreen()),
                        );
                      } else if (a.label == 'Absensi') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                        );
                      } else if (a.label == 'Chat Harian') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChatHarianScreen()),
                        );
                      } else if (a.label == 'Kelola Pelanggan') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CustomerListScreen()),
                        );
                      }
                    },
                    child: Container(
                      margin: EdgeInsets.only(right: a == actions.last ? 0 : 8),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [AppColors.cardShadow],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: a.bg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(a.icon, color: a.color, size: 20),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            a.label,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textDark,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildRecentOrders() {
    if (_recentOrders.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Text(
                  'Pesanan Terbaru CS',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrderListScreen()),
                );
              },
              child: Text(
                'Lihat Semua',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._recentOrders.map(
          (o) {
            final bool isPaid = o.paymentStatus.toLowerCase() == 'paid' || 
                                o.paymentStatus.toLowerCase() == 'approved' ||
                                o.pembayaran?.statusPembayaran.toLowerCase() == 'approved';
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o)),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [AppColors.cardShadow],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '#${o.id}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        StatusBadge(status: o.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        InitialsAvatar(name: o.customer.name, size: 42),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                o.customer.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                o.services.isNotEmpty
                                    ? o.services.first.name
                                    : 'Pesanan Layanan',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: AppColors.border),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Tagihan',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              _formatRupiah(o.total),
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isPaid ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                                size: 14,
                                color: isPaid ? const Color(0xFF065F46) : const Color(0xFF92400E),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isPaid ? 'Paid / Approved' : 'Unpaid / Pending',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isPaid ? const Color(0xFF065F46) : const Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value, this.icon, this.color, {this.hint = '', this.onTap});
  final String label, value, hint;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});
  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: stat.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: stat.color.withOpacity(0.3), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: stat.color.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: stat.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(stat.icon, color: stat.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    stat.value,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    stat.label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (stat.hint.isNotEmpty)
                    Text(
                      stat.hint,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction(this.label, this.icon, this.color, this.bg);
  final String label;
  final IconData icon;
  final Color color, bg;
}
