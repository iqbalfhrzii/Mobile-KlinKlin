import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/data/customer_model.dart';
import '../../../core/services/customer_service.dart';
import '../../orders/screens/create_order_screen.dart';
import 'edit_customer_screen.dart';
import 'package:url_launcher/url_launcher.dart';

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
  }

  String _formatRupiah(int n) =>
      'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    final c = _customer;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context, c),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    children: [
                      _buildInfoCard(c),
                      const SizedBox(height: 12),
                      _buildStats(c),
                      if (c.notes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildNotes(c),
                      ],
                      const SizedBox(height: 12),
                      _buildOrderHistory(c),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
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
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: AppColors.statusDone,
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
            backgroundColor: AppColors.statusCancel,
          ),
        );
      }
    }
  }

  Widget _buildHeader(BuildContext context, CustomerModel c) {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Column(
        children: [
          // Nav row
          Row(
            children: [
              HeaderBackButton(onTap: () => Navigator.pop(context, _customer)),
              const SizedBox(width: 12),
              Text(
                'Detail Pelanggan',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              HeaderIconButton(
                icon: Icons.edit_outlined,
                onTap: () async {
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditCustomerScreen(customer: _customer),
                    ),
                  );
                  if (updated != null) {
                    setState(() => _customer = updated);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Avatar + name
          InitialsAvatar(
            name: c.name,
            size: 64,
            backgroundColor: Colors.white.withOpacity(0.2),
            textColor: Colors.white,
            borderColor: Colors.white.withOpacity(0.35),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
                  (c.status.toLowerCase() == 'aktif'
                          ? AppColors.statusDone
                          : AppColors.statusCancel)
                      .withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    (c.status.toLowerCase() == 'aktif'
                            ? AppColors.statusDone
                            : AppColors.statusCancel)
                        .withOpacity(0.3),
              ),
            ),
            child: Text(
              c.status.toLowerCase() == 'aktif' ? 'Aktif' : 'Non Aktif',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: c.status.toLowerCase() == 'aktif'
                    ? Colors.white
                    : AppColors.statusCancel,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            c.name,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            c.id,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withOpacity(0.6),
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons di dalam header
          Row(
            children: [
              _headerAction(
                Icons.message_rounded, 
                'WhatsApp',
                onTap: () async {
                  if (c.phone.isEmpty || c.phone == '-') return;
                  String phone = c.phone.replaceAll(RegExp(r'\D'), '');
                  if (phone.startsWith('0')) {
                    phone = '62${phone.substring(1)}';
                  }
                  final text = Uri.encodeComponent('Halo Kak ${c.name}, saya dari CS KlinKlin.');
                  final url = Uri.parse('https://wa.me/$phone?text=$text');
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Tidak dapat membuka WhatsApp', style: GoogleFonts.inter(color: Colors.white)),
                        backgroundColor: AppColors.statusCancel,
                      ));
                    }
                  }
                },
              ),
              const SizedBox(width: 8),
              _headerAction(
                Icons.swap_horiz_rounded,
                'Ubah Status',
                onTap: _changeStatus,
              ),
              const SizedBox(width: 8),
              _headerAction(
                Icons.add_shopping_cart_rounded,
                'Pesanan',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateOrderScreen(),
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

  Widget _headerAction(IconData icon, String label, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(CustomerModel c) {
    return _card(
      title: 'Informasi Pelanggan',
      child: Column(
        children: [
          _infoRow(Icons.phone_rounded, 'Nomor HP', c.phone),
          const Divider(height: 16, color: AppColors.border),
          _infoRow(Icons.location_on_outlined, 'Alamat', c.address),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.surfaceBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStats(CustomerModel c) {
    final items = [
      _StatItem(
        'Total Pesanan',
        '${c.totalOrders}',
        Icons.receipt_long_rounded,
        AppColors.primary,
        AppColors.surfaceBlue,
        false,
      ),
      _StatItem(
        'Total Belanja',
        _formatRupiah(c.totalSpending),
        Icons.payments_rounded,
        const Color(0xFF2E7D32),
        const Color(0xFFE8F5E9),
        true,
      ),
      _StatItem(
        'Rata-rata Order',
        _formatRupiah(c.avgOrder),
        Icons.star_rounded,
        const Color(0xFFB45309),
        const Color(0xFFFFF8E1),
        true,
      ),
    ];

    return Row(
      children: items
          .map(
            (s) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: s == items.last ? 0 : 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [AppColors.cardShadow],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: s.bg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(s.icon, size: 14, color: s.color),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.value,
                      style: GoogleFonts.inter(
                        fontSize: s.small ? 11 : 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      s.label,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildNotes(CustomerModel c) {
    return _card(
      title: 'Catatan CS',
      child: Text(
        c.notes,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.textDark,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildOrderHistory(CustomerModel c) {
    return _card(
      title: 'Riwayat Pesanan',
      trailing: Text(
        'Semua',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
      child: Column(
        children: c.orders.asMap().entries.map((e) {
          final o = e.value;
          final isFirst = e.key == 0;
          return Column(
            children: [
              if (!isFirst) const Divider(height: 12, color: AppColors.border),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.id,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          o.service,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              o.date,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const Text(
                              ' · ',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                            Text(
                              o.cleaners.join(', '),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge(status: o.status),
                      const SizedBox(height: 4),
                      Text(
                        _formatRupiah(o.amount),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _card({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatItem {
  const _StatItem(
    this.label,
    this.value,
    this.icon,
    this.color,
    this.bg,
    this.small,
  );
  final String label, value;
  final IconData icon;
  final Color color, bg;
  final bool small;
}
