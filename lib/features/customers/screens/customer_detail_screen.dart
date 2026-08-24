import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/data/customer_model.dart';
import '../../../core/data/order_model.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../orders/screens/create_order_screen.dart';
import '../../orders/screens/order_detail_screen.dart';
import '../../orders/services/order_service.dart';
import 'edit_customer_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({super.key, required this.customer});
  final CustomerModel customer;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late CustomerModel _customer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _loadCustomerDetail();
  }

  Future<void> _loadCustomerDetail() async {
    setState(() => _isLoading = true);
    try {
      final fullData = await CustomerService.getCustomer(_customer.id);
      if (mounted) {
        setState(() {
          _customer = fullData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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

  Future<void> _openWhatsApp() async {
    final c = _customer;
    if (c.phone.isEmpty || c.phone == '-') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor WhatsApp tidak tersedia.')),
      );
      return;
    }
    var cleanPhone = c.phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
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


  Future<void> _changeStatus() async {
    final c = _customer;
    final isAktif = c.status.toLowerCase() == 'aktif';
    final newStatus = isAktif ? 'nonaktif' : 'aktif';

    setState(() => _isLoading = true);
    try {
      final updated = await CustomerService.updateCustomerStatus(
        c.id,
        newStatus,
        {},
      );

      if (mounted) {
        setState(() {
          _customer = updated;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Status diubah menjadi ${newStatus == 'aktif' ? 'Aktif' : 'Non Aktif'}',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: newStatus == 'aktif' ? const Color(0xFF10B981) : const Color(0xFF64748B),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _customer;
    final isAktif = c.status.toLowerCase() == 'aktif';
    final gradientColors = isAktif
        ? [const Color(0xFF059669), const Color(0xFF10B981)]
        : [const Color(0xFFDC2626), const Color(0xFFEF4444)];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context, c, gradientColors, isAktif),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadCustomerDetail,
                  color: AppColors.primaryMid,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                    child: Column(
                      children: [
                        // 1. KPI Stats Summary Cards
                        _buildStats(c),

                        const SizedBox(height: 12),

                        // 2. Customer Profile Details Card
                        _buildInfoCard(c),

                        if (c.notes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildNotes(c),
                        ],

                        const SizedBox(height: 12),

                        // 3. Order History List
                        _buildOrderHistory(c),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.25),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  // ================= HEADER & HERO =================

  Widget _buildHeader(BuildContext context, CustomerModel c, List<Color> gradientColors, bool isAktif) {
    // Tier badge
    String tierLabel = 'Pelanggan Baru';
    Color tierColor = const Color(0xFF38BDF8);
    IconData tierIcon = Icons.star_border_rounded;

    if (c.totalOrders >= 3) {
      tierLabel = 'VIP Customer (${c.totalOrders}x)';
      tierColor = const Color(0xFFFDE047);
      tierIcon = Icons.diamond_rounded;
    } else if (c.totalOrders == 2) {
      tierLabel = 'Repeat Order (2x)';
      tierColor = const Color(0xFF6EE7B7);
      tierIcon = Icons.autorenew_rounded;
    } else if (c.totalOrders == 1) {
      tierLabel = '1x Order';
      tierColor = const Color(0xFFA5B4FC);
      tierIcon = Icons.check_circle_outline_rounded;
    }

    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        children: [
          // Top Nav bar
          Row(
            children: [
              HeaderBackButton(onTap: () => Navigator.pop(context, _customer)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Detail Pelanggan',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              InkWell(
                onTap: () async {
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditCustomerScreen(customer: _customer),
                    ),
                  );
                  if (updated != null) {
                    setState(() => _customer = updated);
                    _loadCustomerDetail();
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Avatar + Status Dot
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    c.initials,
                    style: GoogleFonts.inter(
                      fontSize: 24,
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
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isAktif ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Customer Name
          Text(
            c.name,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Badges Row: ID + Status + Tier
          Wrap(
            spacing: 6,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              // ID chip
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: c.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ID Pelanggan disalin ke clipboard!')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        c.id,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.copy_rounded, size: 10, color: Colors.white.withValues(alpha: 0.7)),
                    ],
                  ),
                ),
              ),

              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAktif
                      ? const Color(0xFF10B981).withValues(alpha: 0.25)
                      : const Color(0xFFEF4444).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isAktif
                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                        : const Color(0xFFEF4444).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isAktif ? const Color(0xFF34D399) : const Color(0xFFF87171),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isAktif ? 'Aktif' : 'Non Aktif',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Tier chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
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
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: tierColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 3 Action Buttons Bar
          Row(
            children: [
              _buildHeaderActionBtn(
                icon: Icons.chat_rounded,
                label: 'WhatsApp',
                onTap: _openWhatsApp,
              ),
              const SizedBox(width: 8),
              _buildHeaderActionBtn(
                icon: Icons.swap_horiz_rounded,
                label: 'Ubah Status',
                onTap: _changeStatus,
              ),
              const SizedBox(width: 8),
              _buildHeaderActionBtn(
                icon: Icons.add_shopping_cart_rounded,
                label: 'Order Baru',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateOrderScreen(initialCustomer: _customer),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 19),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= KPI METRIC CARDS =================

  Widget _buildStats(CustomerModel c) {
    return Row(
      children: [
        _buildStatCard(
          title: 'Total Pesanan',
          value: '${c.totalOrders}',
          subtitle: 'Order Selesai',
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF0284C7),
          bgColor: const Color(0xFFE0F2FE),
        ),
        const SizedBox(width: 8),
        _buildStatCard(
          title: 'Total Belanja',
          value: CurrencyFormatter.format(c.totalSpending),
          subtitle: 'Akumulasi',
          icon: Icons.payments_rounded,
          color: const Color(0xFF059669),
          bgColor: const Color(0xFFD1FAE5),
        ),
        const SizedBox(width: 8),
        _buildStatCard(
          title: 'Rata-rata Order',
          value: CurrencyFormatter.format(c.avgOrder),
          subtitle: 'Per Transaksi',
          icon: Icons.analytics_rounded,
          color: const Color(0xFF7C3AED),
          bgColor: const Color(0xFFEDE9FE),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
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
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ================= INFORMATION CARD =================

  Widget _buildInfoCard(CustomerModel c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined, size: 15, color: AppColors.primaryMid),
              const SizedBox(width: 6),
              Text(
                'INFORMASI PELANGGAN',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Phone Row
          _buildDetailRow(
            icon: Icons.phone_iphone_rounded,
            iconColor: const Color(0xFF0284C7),
            iconBg: const Color(0xFFE0F2FE),
            label: 'Nomor WhatsApp / HP',
            value: _cleanPhoneDisplay(c.phone),
            trailing: InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: c.phone));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nomor HP disalin ke clipboard!')),
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.copy_rounded, size: 15, color: Color(0xFF94A3B8)),
              ),
            ),
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Address Row
          _buildDetailRow(
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xFFEF4444),
            iconBg: const Color(0xFFFEE2E2),
            label: 'Alamat Pelanggan',
            value: (c.address.isNotEmpty && c.address != '-') ? c.address : 'Alamat belum ditambahkan',
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Last Order Row
          _buildDetailRow(
            icon: Icons.event_available_rounded,
            iconColor: const Color(0xFF10B981),
            iconBg: const Color(0xFFD1FAE5),
            label: 'Terakhir Pesan',
            value: (c.lastOrderDate.isNotEmpty && c.lastOrderDate != '-') ? c.lastOrderDate : 'Belum pernah order',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // ================= NOTES CARD =================

  Widget _buildNotes(CustomerModel c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.sticky_note_2_rounded, size: 15, color: Color(0xFFD97706)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CATATAN CS',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: const Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  c.notes,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: const Color(0xFF78350F),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= ORDER HISTORY =================

  Widget _buildOrderHistory(CustomerModel c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 15, color: AppColors.primaryMid),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'RIWAYAT PESANAN',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryMid.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${c.orders.length} Pesanan',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryMid,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          if (c.orders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shopping_bag_outlined, size: 28, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada riwayat pesanan',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateOrderScreen(initialCustomer: _customer),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 15, color: Colors.white),
                      label: Text('Buat Pesanan', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryMid,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...c.orders.asMap().entries.map((e) {
              final o = e.value;
              final isFirst = e.key == 0;
              return Column(
                children: [
                  if (!isFirst) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 8),
                  ],
                  InkWell(
                    onTap: () async {
                      try {
                        final orderIdClean = o.id.replaceAll(RegExp(r'[^0-9]'), '');
                        if (orderIdClean.isNotEmpty) {
                          final order = await OrderService().fetchOrderDetail(orderIdClean);
                          if (mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderDetailScreen(order: order),
                              ),
                            );
                          }
                        }
                      } catch (err) {
                        debugPrint('Error opening order detail: $err');
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(Icons.cleaning_services_rounded, size: 18, color: AppColors.primaryMid),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      o.id,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryMid,
                                      ),
                                    ),
                                    const Spacer(),
                                    StatusBadge(status: o.status),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  o.service,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 4),
                                    Text(
                                      o.date,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                    if (o.cleaners.isNotEmpty) ...[
                                      const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
                                      Expanded(
                                        child: Text(
                                          o.cleaners.join(', '),
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: const Color(0xFF64748B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  CurrencyFormatter.format(o.amount),
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}
