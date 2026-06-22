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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoadingStats = true;
  int _omzetThisMonth = 0;
  int _ordersToday = 0;
  int _waiting = 0;
  int _active = 0;
  int _doneToday = 0;
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
      final orders = await OrderService().fetchOrders();
      final now = DateTime.now();
      
      int omzet = 0;
      int countToday = 0;
      int waiting = 0;
      int active = 0;
      int done = 0;

      for (var o in orders) {
        bool isToday = o.scheduleDateTime.year == now.year && o.scheduleDateTime.month == now.month && o.scheduleDateTime.day == now.day;
        bool isThisMonth = o.scheduleDateTime.year == now.year && o.scheduleDateTime.month == now.month;
        
        if (isThisMonth) {
          omzet += o.total;
        }

        if (isToday) {
          countToday++;
          if (o.status == OrderStatus.completed) done++;
        }

        if (o.status == OrderStatus.waitingPaymentApproval) {
            waiting++;
        }

        if (o.status == OrderStatus.assigned || o.status == OrderStatus.inProgress || o.status == OrderStatus.draft) {
          active++;
        }
      }

      if (mounted) {
        setState(() {
          _omzetThisMonth = omzet;
          _ordersToday = countToday;
          _waiting = waiting;
          _active = active;
          _doneToday = done;
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
          _userRole = me['jabatan'] is Map ? me['jabatan']['nama_jabatan'] ?? _userRole : _userRole;
          _userBranch = me['cabang'] is Map ? me['cabang']['nama_cabang'] ?? _userBranch : _userBranch;
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
    final greeting = hour < 12 ? 'Selamat Pagi' : hour < 15 ? 'Selamat Siang' : hour < 18 ? 'Selamat Sore' : 'Selamat Malam';

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
                  Image.network(
                    'https://www.klinklin.co.id/wp-content/uploads/2023/11/Logo-164-x-45-1.png',
                    height: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(greeting + ',', style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
                  )),
                  Text('$_userName ✨', style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
                  )),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    Text('Omzet Bulan Ini', style: GoogleFonts.inter(
                      fontSize: 11, color: Colors.white.withOpacity(0.7),
                    )),
                    Text(_formatRupiah(_omzetThisMonth), style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
                    )),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Aktif',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
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
      return InitialsAvatar(name: _userName, size: 48, backgroundColor: Colors.white.withOpacity(0.2), textColor: Colors.white, borderColor: Colors.white.withOpacity(0.35));
    }
    
    if (_userPhoto!.startsWith('data:image')) {
      try {
        final base64Str = _userPhoto!.split(',').last;
        return ClipOval(child: Image.memory(base64Decode(base64Str), width: 48, height: 48, fit: BoxFit.cover));
      } catch (_) {
        return InitialsAvatar(name: _userName, size: 48, backgroundColor: Colors.white.withOpacity(0.2), textColor: Colors.white, borderColor: Colors.white.withOpacity(0.35));
      }
    }
    
    if (_userPhoto!.startsWith('http')) {
      return ClipOval(child: Image.network(_userPhoto!, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => InitialsAvatar(name: _userName, size: 48, backgroundColor: Colors.white.withOpacity(0.2), textColor: Colors.white, borderColor: Colors.white.withOpacity(0.35))));
    }
    
    if (_userPhoto!.startsWith('/')) {
      return ClipOval(child: Image.file(File(_userPhoto!), width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => InitialsAvatar(name: _userName, size: 48, backgroundColor: Colors.white.withOpacity(0.2), textColor: Colors.white, borderColor: Colors.white.withOpacity(0.35))));
    }
    
    return ClipOval(child: Image.network('http://192.168.1.242:8000/storage/$_userPhoto', width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => InitialsAvatar(name: _userName, size: 48, backgroundColor: Colors.white.withOpacity(0.2), textColor: Colors.white, borderColor: Colors.white.withOpacity(0.35))));
  }

  Widget _buildStatCards() {
    final items = [
      _Stat('Pesanan Hari Ini', '$_ordersToday', Icons.receipt_long_rounded, AppColors.primaryMid, onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderListScreen(isTodayOnly: true)));
      }),
      _Stat('Menunggu Approve', '$_waiting', Icons.hourglass_empty_rounded, AppColors.statusPending, onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderListScreen(initialStatusFilter: 'waitingPaymentApproval')));
      }),
      _Stat('Dikerjakan', '$_active', Icons.cleaning_services_rounded, AppColors.statusProgress, onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderListScreen(initialStatusFilter: 'inProgress')));
      }),
      _Stat('Selesai', '$_doneToday', Icons.check_circle_rounded, AppColors.statusDone, onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderListScreen(initialStatusFilter: 'completed')));
      }),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.map((s) => _StatCard(stat: s)).toList(),
    );
  }

  Widget _buildOmzetCard() {
    final omzet = _omzetThisMonth;
    final target = 15000000;
    final pct = (omzet / target).clamp(0.0, 1.0);

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.trending_up_rounded, color: Color(0xFF2E7D32), size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Omzet Bulan Ini', style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textMuted,
                  )),
                  Text(_formatRupiah(omzet), style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark,
                  )),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progress target bulanan', style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textMuted,
              )),
              Text('${(pct * 100).round()}%', style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark,
              )),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.surfaceBlue,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.statusDone),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text('Target: ${_formatRupiah(target)}', style: GoogleFonts.inter(
            fontSize: 11, color: AppColors.textMuted,
          )),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction('Buat Pesanan', Icons.add_circle_outline_rounded, AppColors.primary, AppColors.surfaceBlue),
      _QuickAction('Kelola Pelanggan', Icons.people_outline_rounded, const Color(0xFF7C3AED), const Color(0xFFEDE9FE)),
      _QuickAction('KPI Karyawan', Icons.analytics_rounded, const Color(0xFFE65100), const Color(0xFFFFF3E0)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Aksi Cepat', style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted,
          letterSpacing: 0.5,
        )),
        const SizedBox(height: 10),
        Row(
          children: actions.map((a) => Expanded(
            child: GestureDetector(
              onTap: () {
                if (a.label == 'Buat Pesanan') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOrderScreen()));
                } else if (a.label == 'KPI Karyawan') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const KpiScreen()));
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
                      decoration: BoxDecoration(color: a.bg, shape: BoxShape.circle),
                      child: Icon(a.icon, color: a.color, size: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(a.label, style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textDark,
                    ), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          )).toList(),
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
            Text('Pesanan Terbaru', style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5,
            )),
            Text('Lihat Semua', style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary,
            )),
          ],
        ),
        const SizedBox(height: 10),
        ..._recentOrders.map((o) => GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o)));
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              boxShadow: [AppColors.cardShadow],
            ),
            child: Row(
              children: [
                InitialsAvatar(name: o.customer.name, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.customer.name, style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark,
                      )),
                      Text(o.services.isNotEmpty ? o.services.first.name : 'Pesanan', style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textMuted,
                      )),
                    ],
                  ),
                ),
                StatusBadge(status: o.status),
              ],
            ),
          ),
        )),
      ],
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value, this.icon, this.color, {this.onTap});
  final String label, value;
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [AppColors.cardShadow],
        ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: stat.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(stat.icon, color: stat.color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(stat.value, style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark,
              )),
              Text(stat.label, style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textMuted,
              )),
            ],
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
