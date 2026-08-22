import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import 'kantor_klinklin_screen.dart';
import 'operasional_target_omzet_screen.dart';
import 'operasional_permintaan_design_screen.dart';
import 'operasional_pengumuman_screen.dart';

import '../../master_barang/screens/master_barang_screen.dart';

class OperasionalPengaturanScreen extends StatelessWidget {
  const OperasionalPengaturanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          GradientHeader(
            child: Row(
              children: [
                const AppBackButton(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pengaturan',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manajemen Target & Cabang',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildMenuCard(
                  context,
                  icon: Icons.inventory_2_outlined,
                  title: 'Master Barang & Aset',
                  subtitle: 'Kelola kategori, barang, dan generate QR code untuk semua cabang.',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MasterBarangScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildMenuCard(
                  context,
                  icon: Icons.business,
                  title: 'Kantor Klinklin',
                  subtitle: 'Kelola data alamat dan sewa kantor untuk setiap cabang',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const KantorKlinklinScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildMenuCard(
                  context,
                  icon: Icons.track_changes,
                  title: 'Target Omzet',
                  subtitle: 'Kelola target omzet bulanan untuk setiap cabang',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const OperasionalTargetOmzetScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildMenuCard(
                  context,
                  icon: Icons.brush_outlined,
                  title: 'Permintaan Design',
                  subtitle: 'Ajukan dan pantau status permintaan design Anda.',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const OperasionalPermintaanDesignScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildMenuCard(
                  context,
                  icon: Icons.campaign_rounded,
                  title: 'Pengumuman',
                  subtitle: 'Kelola dan lihat pengumuman untuk berbagai divisi dan cabang.',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const OperasionalPengumumanScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
