import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import 'payment_screen.dart';

class CashFlowMenuScreen extends StatelessWidget {
  const CashFlowMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text('Pilih Kategori', style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMuted
                  )),
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    context: context,
                    title: 'Pembayaran',
                    subtitle: 'Kelola pembayaran yang masuk (Lunas & Belum Lunas)',
                    icon: Icons.payments_rounded,
                    color: AppColors.primary,
                    bg: AppColors.surfaceBlue,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const PaymentScreen(isCancelMode: false)
                      ));
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    context: context,
                    title: 'Cancel Pembayaran',
                    subtitle: 'Lihat daftar pembayaran atau pesanan yang dibatalkan',
                    icon: Icons.cancel_presentation_rounded,
                    color: AppColors.error,
                    bg: const Color(0xFFFEF2F2),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const PaymentScreen(isCancelMode: true)
                      ));
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Manajemen', style: GoogleFonts.inter(
                  fontSize: 11, color: Colors.white.withOpacity(0.7))),
              Text('Cash Flow', style: GoogleFonts.inter(
                  fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [AppColors.cardShadow],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark
                  )),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textMuted
                  )),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 24),
          ],
        ),
      ),
    );
  }
}
