import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_header.dart';
import 'cabang/cabang_list_screen.dart';
import 'jabatan/jabatan_list_screen.dart';
import 'karyawan/karyawan_list_screen.dart';
import 'layanan/layanan_list_screen.dart';
import 'pelanggan/pelanggan_list_screen.dart';
import 'jenis_bonus/jenis_bonus_list_screen.dart';
import 'gaji_pokok/gaji_pokok_list_screen.dart';
import 'gaji_karyawan/gaji_karyawan_list_screen.dart';
import 'insentif/insentif_cleaner_list_screen.dart';

class HrdDataMasterScreen extends StatelessWidget {
  const HrdDataMasterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kelola',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Data Master',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                _buildMenuCard(
                  context,
                  title: 'Insentif Cleaner',
                  description: 'Pantau & kelola insentif cleaner',
                  icon: Icons.payments_rounded,
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InsentifCleanerListScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildMenuCard(
                  context,
                  title: 'Karyawan',
                  description: 'Kelola data pegawai',
                  icon: Icons.badge_outlined,
                  color: Colors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const KaryawanListScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildMenuCard(
                  context,
                  title: 'Jabatan',
                  description: 'Atur posisi & role',
                  icon: Icons.work_outline_rounded,
                  color: Colors.indigo,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const JabatanListScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildMenuCard(
                  context,
                  title: 'Cabang & Bonus',
                  description: 'Lokasi & tarif cabang',
                  icon: Icons.storefront_rounded,
                  color: Colors.orange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CabangListScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                _buildMenuCard(
                  context,
                  title: 'Kategori Bonus',
                  description: 'Jenis bonus tambahan',
                  icon: Icons.card_giftcard_rounded,
                  color: Colors.purple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const JenisBonusListScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildMenuCard(
                  context,
                  title: 'Layanan',
                  description: 'Daftar jasa pembersihan',
                  icon: Icons.cleaning_services_rounded,
                  color: Colors.green,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LayananListScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildMenuCard(
                  context,
                  title: 'Pelanggan',
                  description: 'Kelola data pelanggan',
                  icon: Icons.people_alt_rounded,
                  color: Colors.blueAccent,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PelangganListScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildMenuCard(
                  context,
                  title: 'Gaji Pokok',
                  description: 'Standar gaji karyawan',
                  icon: Icons.monetization_on_rounded,
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GajiPokokListScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildMenuCard(
                  context,
                  title: 'Gaji Karyawan',
                  description: 'Rekapitulasi gaji bulanan',
                  icon: Icons.receipt_long_rounded,
                  color: Colors.indigo,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GajiKaryawanListScreen(),
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

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.lerp(color, Colors.white, 0.2)!, 
                        color
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
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
                        description,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
