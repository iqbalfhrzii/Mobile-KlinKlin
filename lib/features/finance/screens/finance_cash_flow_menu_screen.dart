import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import 'finance_approval_list_screen.dart';
import 'finance_cancel_list_screen.dart';
import 'finance_processed_list_screen.dart';

class FinanceCashFlowMenuScreen extends StatelessWidget {
  const FinanceCashFlowMenuScreen({super.key});

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
                    title: 'Approval Pembayaran',
                    subtitle: 'Setujui atau tolak pembayaran pesanan',
                    icon: Icons.payments_rounded,
                    color: AppColors.primary,
                    bg: AppColors.surfaceBlue,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const FinanceApprovalListScreen()
                      ));
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    context: context,
                    title: 'Pesanan Batal',
                    subtitle: 'Lihat daftar pesanan yang dibatalkan',
                    icon: Icons.cancel_presentation_rounded,
                    color: AppColors.error,
                    bg: const Color(0xFFFEF2F2),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const FinanceCancelListScreen()
                      ));
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    context: context,
                    title: 'Riwayat Pesanan',
                    subtitle: 'Lihat pesanan yang sudah diproses',
                    icon: Icons.history_rounded,
                    color: AppColors.textMuted,
                    bg: const Color(0xFFF3F4F6),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const FinanceProcessedListScreen()
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
              Text('Approval', style: GoogleFonts.inter(
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
