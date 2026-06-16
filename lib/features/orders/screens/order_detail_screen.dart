import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/data/order_model.dart';
import 'edit_order_screen.dart';
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.order});
  final OrderModel order;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  String _formatRupiah(int n) =>
      'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context, o),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  _buildCustomerCard(o),
                  const SizedBox(height: 12),
                  _buildServicesCard(o),
                  const SizedBox(height: 12),
                  _buildScheduleCard(o),
                  if (o.cleaners.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...o.cleaners.expand((c) => [_buildCleanerCard(c), const SizedBox(height: 12)]).take(o.cleaners.length * 2 - 1),
                  ],
                  const SizedBox(height: 12),
                  _buildPaymentCard(o),
                  if (o.notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildNotesCard(o),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, OrderModel o) {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HeaderBackButton(onTap: () => Navigator.pop(context)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detail Pesanan', style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
                  )),
                  Text(o.id, style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.white.withOpacity(0.6),
                  )),
                ],
              ),
              const Spacer(),
              StatusBadge(status: o.status),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditOrderScreen(order: o)),
                  );
                  if (result == true) {
                    setState(() {});
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(OrderModel o) {
    return _card(
      title: 'Pelanggan',
      child: Row(
        children: [
          InitialsAvatar(name: o.customer.name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.customer.name, style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark,
                )),
                Text(o.customer.phone, style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textMuted,
                )),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 2),
                    Expanded(child: Text(o.customer.area, style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textMuted,
                    ))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesCard(OrderModel o) {
    return _card(
      title: 'Layanan',
      child: Column(
        children: [
          ...o.services.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: Text(s.name, style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textDark,
                ))),
                Text('${s.qty}x', style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textMuted,
                )),
                const SizedBox(width: 8),
                Text(_formatRupiah(s.subtotal), style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark,
                )),
              ],
            ),
          )),
          const Divider(height: 12, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark,
              )),
              Text(_formatRupiah(o.total), style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(OrderModel o) {
    return _card(
      title: 'Jadwal',
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event_rounded, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Text(o.schedule, style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark,
          )),
        ],
      ),
    );
  }

  Widget _buildCleanerCard(OrderCleaner cleaner) {
    return _card(
      title: 'Petugas Kebersihan',
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.cleaning_services_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cleaner.name, style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark,
                )),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 2),
                    Text('${cleaner.rating}', style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textMuted,
                    )),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Ditugaskan', style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary,
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(OrderModel o) {
    final isPaid = o.paymentStatus == 'paid';
    return _card(
      title: 'Pembayaran',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Metode', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                Text(o.paymentMethod, style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark,
                )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isPaid ? AppColors.statusDoneBg : AppColors.statusPendingBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPaid ? AppColors.statusDone : AppColors.statusPending,
              ),
            ),
            child: Text(
              isPaid ? '✓ Lunas' : 'Belum Lunas',
              style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: isPaid ? AppColors.statusDone : AppColors.statusPending,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(OrderModel o) {
    return _card(
      title: 'Catatan',
      child: Text(o.notes, style: GoogleFonts.inter(
        fontSize: 13, color: AppColors.textDark, height: 1.5,
      )),
    );
  }

  Widget _card({required String title, required Widget child}) {
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
          Text(title.toUpperCase(), style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: AppColors.textMuted, letterSpacing: 0.5,
          )),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
