import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/data/customer_model.dart';
import '../../../core/services/customer_service.dart';
import 'customer_detail_screen.dart';
import 'add_customer_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _filter = 'Semua';
  List<CustomerModel> _customers = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final data = await CustomerService.getCustomers(status: 'Semua');
      if (mounted) {
        setState(() {
          _customers = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  List<CustomerModel> get _filtered {
    var list = _customers.where((c) {
      final q = _query.toLowerCase().trim();
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q) ||
          c.address.toLowerCase().contains(q);
    }).toList();

    if (_filter != 'Semua') {
      if (_filter == 'Aktif') {
        list = list.where((c) => c.status.toLowerCase() == 'aktif').toList();
      } else {
        list = list.where((c) => c.status.toLowerCase() != 'aktif').toList();
      }
    }
    return list;
  }

  int get _countTotal => _customers.length;
  int get _countAktif => _customers.where((c) => c.status.toLowerCase() == 'aktif').length;
  int get _countNonAktif => _customers.where((c) => c.status.toLowerCase() != 'aktif').length;
  int get _totalOrders => _customers.fold(0, (sum, c) => sum + c.totalOrders);

  Future<void> _openWhatsApp(String phone, String name) async {
    var cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    }
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor WhatsApp tidak valid.')),
      );
      return;
    }
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka WhatsApp: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryMid,
                    ),
                  )
                : _error.isNotEmpty
                    ? _buildErrorView()
                    : RefreshIndicator(
                        onRefresh: _fetchData,
                        color: AppColors.primaryMid,
                        backgroundColor: Colors.white,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                          children: [
                            // 1. KPI Summary Cards
                            _buildKpiMetrics(),

                            const SizedBox(height: 12),

                            // 2. Segmented Status Filter Bar
                            _buildFilterBar(),

                            const SizedBox(height: 12),

                            // 3. Customer List or Empty
                            if (_filtered.isEmpty)
                              _buildEmptyView()
                            else
                              ..._filtered.map((c) => _CustomerCard(
                                    customer: c,
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CustomerDetailScreen(customer: c),
                                        ),
                                      );
                                      _fetchData();
                                    },
                                    onWhatsAppTap: () => _openWhatsApp(c.phone, c.name),
                                  )),
                          ],
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'customer_fab',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddCustomerScreen(),
            ),
          );
          if (result != null) _fetchData();
        },
        backgroundColor: AppColors.primaryMid,
        elevation: 4,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
        label: Text(
          'Tambah Pelanggan',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ================= HEADER & SEARCH =================

  Widget _buildHeader() {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (Navigator.canPop(context)) ...[
                const AppBackButton(),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MANAJEMEN',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pelanggan',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.group_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      '$_countTotal Total',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Search Input Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
              cursorColor: AppColors.primaryMid,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Cari nama, nomor WhatsApp, alamat...',
                hintStyle: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Color(0xFF64748B), size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primaryMid, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= KPI METRIC CARDS =================

  Widget _buildKpiMetrics() {
    final activePct = _countTotal > 0 ? ((_countAktif / _countTotal) * 100).round() : 0;
    return Row(
      children: [
        _buildKpiCard(
          title: 'Total Pelanggan',
          value: '$_countTotal',
          subtitle: 'Terdaftar',
          icon: Icons.people_alt_rounded,
          color: const Color(0xFF0284C7),
          bgColor: const Color(0xFFE0F2FE),
        ),
        const SizedBox(width: 8),
        _buildKpiCard(
          title: 'Pelanggan Aktif',
          value: '$_countAktif',
          subtitle: '$activePct% Aktif',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF059669),
          bgColor: const Color(0xFFD1FAE5),
        ),
        const SizedBox(width: 8),
        _buildKpiCard(
          title: 'Total Pesanan',
          value: '$_totalOrders',
          subtitle: 'Transaksi',
          icon: Icons.shopping_bag_rounded,
          color: const Color(0xFF7C3AED),
          bgColor: const Color(0xFFEDE9FE),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF64748B).withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 14, color: color),
                ),
                const Spacer(),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 9.5,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= FILTER BAR =================

  Widget _buildFilterBar() {
    final filters = [
      {'label': 'Semua', 'count': _countTotal, 'color': AppColors.primaryMid},
      {'label': 'Aktif', 'count': _countAktif, 'color': const Color(0xFF10B981)},
      {'label': 'Non Aktif', 'count': _countNonAktif, 'color': const Color(0xFF64748B)},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: filters.map((item) {
          final label = item['label'] as String;
          final count = item['count'] as int;
          final isSelected = _filter == label;
          final accentColor = item['color'] as Color;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_filter != label) {
                  setState(() => _filter = label);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (label != 'Semua') ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentColor.withValues(alpha: 0.12)
                            : const Color(0xFFCBD5E1).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? accentColor : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ================= ERROR & EMPTY STATES =================

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 40, color: Colors.red),
            ),
            const SizedBox(height: 14),
            Text(
              'Gagal Memuat Data Pelanggan',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              _error,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMid,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              label: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    String emptyTitle = 'Belum Ada Data Pelanggan';
    String emptySubtitle = 'Mulai catat pelanggan baru cabang dengan menekan tombol "+ Tambah Pelanggan".';

    if (_query.isNotEmpty) {
      emptyTitle = 'Pelanggan Tidak Ditemukan';
      emptySubtitle = 'Tidak ada pelanggan yang cocok dengan kata kunci "$_query". Coba cari nomor atau nama lain.';
    } else if (_filter == 'Non Aktif') {
      emptyTitle = 'Tidak Ada Pelanggan Non Aktif';
      emptySubtitle = 'Semua data pelanggan di cabang ini saat ini berstatus Aktif.';
    } else if (_filter == 'Aktif') {
      emptyTitle = 'Tidak Ada Pelanggan Aktif';
      emptySubtitle = 'Belum ada pelanggan aktif yang terdaftar di cabang ini.';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryMid.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_search_rounded, size: 48, color: AppColors.primaryMid),
          ),
          const SizedBox(height: 16),
          Text(
            emptyTitle,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            emptySubtitle,
            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ================= CUSTOMER CARD COMPONENT =================

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.onTap,
    required this.onWhatsAppTap,
  });

  final CustomerModel customer;
  final VoidCallback onTap;
  final VoidCallback onWhatsAppTap;

  List<Color> _getAvatarGradient(String name) {
    final colorsList = [
      [const Color(0xFF0284C7), const Color(0xFF38BDF8)], // Sky
      [const Color(0xFF059669), const Color(0xFF34D399)], // Emerald
      [const Color(0xFF7C3AED), const Color(0xFFA78BFA)], // Violet
      [const Color(0xFFD97706), const Color(0xFFFBBF24)], // Amber
      [const Color(0xFFE11D48), const Color(0xFFFB7185)], // Rose
      [const Color(0xFF0D9488), const Color(0xFF2DD4BF)], // Teal
      [const Color(0xFF4F46E5), const Color(0xFF818CF8)], // Indigo
    ];
    int hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    return colorsList[hash % colorsList.length];
  }

  String _cleanPhoneDisplay(String phone) {
    if (phone.contains('@lid')) {
      return phone.replaceAll('@lid', ' (LID)');
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final isAktif = c.status.toLowerCase() == 'aktif';
    final gradientColors = isAktif
        ? [const Color(0xFF059669), const Color(0xFF10B981)]
        : [const Color(0xFFDC2626), const Color(0xFFEF4444)];

    // Segment badges (VIP, Repeat, Baru)
    String tierLabel = 'Pelanggan Baru';
    Color tierColor = const Color(0xFF0284C7);
    Color tierBg = const Color(0xFFE0F2FE);
    IconData tierIcon = Icons.star_border_rounded;

    if (c.totalOrders >= 3) {
      tierLabel = 'VIP Customer (${c.totalOrders}x)';
      tierColor = const Color(0xFFB45309);
      tierBg = const Color(0xFFFEF3C7);
      tierIcon = Icons.diamond_rounded;
    } else if (c.totalOrders == 2) {
      tierLabel = 'Repeat Order (2x)';
      tierColor = const Color(0xFF047857);
      tierBg = const Color(0xFFD1FAE5);
      tierIcon = Icons.autorenew_rounded;
    } else if (c.totalOrders == 1) {
      tierLabel = '1x Order';
      tierColor = const Color(0xFF4338CA);
      tierBg = const Color(0xFFEEF2FF);
      tierIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar + Name + Badges + Chevron
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar with gradient & online dot
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: gradientColors[0].withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              c.initials,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: isAktif ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 12),

                    // Customer Name & Category
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Status pill (Aktif / Non Aktif)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: isAktif
                                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                      : const Color(0xFFEF4444).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: isAktif ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isAktif ? 'Aktif' : 'Non Aktif',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isAktif ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          // Phone number
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _cleanPhoneDisplay(c.phone),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Address snippet if exists
                if (c.address.isNotEmpty && c.address != '-') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            c.address,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),

                // Bottom Row: Tier Badge + Spending & Action buttons
                Row(
                  children: [
                    // Tier badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: tierBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tierIcon, size: 12, color: tierColor),
                          const SizedBox(width: 4),
                          Text(
                            tierLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: tierColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // WhatsApp quick button
                    InkWell(
                      onTap: onWhatsAppTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chat_rounded, size: 13, color: Color(0xFF16A34A)),
                            const SizedBox(width: 4),
                            Text(
                              'Chat WA',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Detail button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Detail',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF475569)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
