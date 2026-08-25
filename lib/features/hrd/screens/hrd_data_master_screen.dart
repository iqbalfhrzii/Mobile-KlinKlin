import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../attendance/screens/admin_attendance_list_screen.dart';
import '../../operasional/screens/operasional_pengumuman_screen.dart';
import '../../operasional/screens/operasional_permintaan_design_screen.dart';
import 'cabang/cabang_list_screen.dart';
import 'jabatan/jabatan_list_screen.dart';
import 'karyawan/karyawan_list_screen.dart';
import 'layanan/layanan_list_screen.dart';
import 'pelanggan/pelanggan_list_screen.dart';
import 'gaji_pokok/gaji_pokok_list_screen.dart';
import 'gaji_karyawan/gaji_karyawan_list_screen.dart';
import 'insentif/insentif_cleaner_list_screen.dart';
import 'tukar_libur/hrd_tukar_libur_screen.dart';
import 'jadwal_libur/hrd_jadwal_libur_screen.dart';
import 'cuti/hrd_cuti_screen.dart';

class HrdDataMasterScreen extends StatelessWidget {
  const HrdDataMasterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(
              children: [
                if (Navigator.canPop(context)) ...[
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pusat Kontrol',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Menu HRD & Master Data',
                        style: GoogleFonts.inter(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.widgets_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '13 Modul',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                // 1. Kepegawaian & SDM
                _buildMenuSection(
                  context,
                  title: 'Kepegawaian & SDM',
                  subtitle: 'Manajemen staf, cleaner, libur & presensi',
                  sectionIcon: Icons.badge_rounded,
                  sectionColor: const Color(0xFF2563EB),
                  items: [
                    _HrdMenuItem(
                      title: 'Karyawan',
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF2563EB),
                      bgColor: const Color(0xFFEFF6FF),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KaryawanListScreen())),
                    ),
                    _HrdMenuItem(
                      title: 'Jabatan',
                      icon: Icons.work_outline_rounded,
                      color: const Color(0xFF4F46E5),
                      bgColor: const Color(0xFFEEF2FF),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JabatanListScreen())),
                    ),
                    _HrdMenuItem(
                      title: 'Jadwal Libur',
                      icon: Icons.calendar_month_rounded,
                      color: const Color(0xFF0D9488),
                      bgColor: const Color(0xFFCCFBF1),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrdJadwalLiburScreen())),
                    ),
                    _HrdMenuItem(
                      title: 'Tukar Libur',
                      icon: Icons.swap_horiz_rounded,
                      color: const Color(0xFFD97706),
                      bgColor: const Color(0xFFFEF3C7),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrdTukarLiburScreen())),
                    ),
                    _HrdMenuItem(
                      title: 'Cuti & Izin',
                      icon: Icons.beach_access_rounded,
                      color: const Color(0xFFE11D48),
                      bgColor: const Color(0xFFFFE4E6),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrdCutiScreen())),
                    ),
                    _HrdMenuItem(
                      title: 'Presensi Log',
                      icon: Icons.fingerprint_rounded,
                      color: const Color(0xFF059669),
                      bgColor: const Color(0xFFECFDF5),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAttendanceListScreen())),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 2. Kompensasi & Penggajian
                _buildMenuSection(
                  context,
                  title: 'Kompensasi & Penggajian',
                  subtitle: 'Standar gaji pokok, slip & bonus cleaner',
                  sectionIcon: Icons.payments_rounded,
                  sectionColor: const Color(0xFF059669),
                  items: [
                    _HrdMenuItem(
                      title: 'Gaji Karyawan',
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFF059669),
                      bgColor: const Color(0xFFECFDF5),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GajiKaryawanListScreen())),
                    ),
                    _HrdMenuItem(
                      title: 'Standar Gaji',
                      icon: Icons.monetization_on_rounded,
                      color: const Color(0xFF0D9488),
                      bgColor: const Color(0xFFCCFBF1),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GajiPokokListScreen())),
                    ),
                    _HrdMenuItem(
                      title: 'Insentif Cleaner',
                      icon: Icons.card_giftcard_rounded,
                      color: const Color(0xFF7C3AED),
                      bgColor: const Color(0xFFF3E8FF),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InsentifCleanerListScreen())),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 3. Operasional Cabang & Data Master
                _buildMenuSection(
                  context,
                  title: 'Operasional & Data Master',
                  subtitle: 'Pengaturan cabang, layanan, pelanggan & info',
                  sectionIcon: Icons.storefront_rounded,
                  sectionColor: const Color(0xFF7C3AED),
                  items: [
                    _HrdMenuItem(
                      title: 'Cabang & Bonus',
                      icon: Icons.storefront_rounded,
                      color: const Color(0xFF7C3AED),
                      bgColor: const Color(0xFFF3E8FF),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CabangListScreen())),
                    ),
                    _HrdMenuItem(
                      title: 'Layanan',
                      icon: Icons.cleaning_services_rounded,
                      color: const Color(0xFF0284C7),
                      bgColor: const Color(0xFFE0F2FE),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LayananListScreen())),
                    ),
                    _HrdMenuItem(
                      title: 'Pelanggan',
                      icon: Icons.contact_phone_rounded,
                      color: const Color(0xFFD97706),
                      bgColor: const Color(0xFFFEF3C7),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PelangganListScreen())),
                    ),
                    _HrdMenuItem(
                      title: 'Desain',
                      icon: Icons.brush_rounded,
                      color: const Color(0xFFEA580C),
                      bgColor: const Color(0xFFFFEDD5),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OperasionalPermintaanDesignScreen())),
                    ),
                    _HrdMenuItem(
                      title: 'Pengumuman',
                      icon: Icons.campaign_rounded,
                      color: const Color(0xFFE11D48),
                      bgColor: const Color(0xFFFFE4E6),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OperasionalPengumumanScreen())),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData sectionIcon,
    required Color sectionColor,
    required List<_HrdMenuItem> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: sectionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(sectionIcon, size: 16, color: sectionColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Items Grid (4 columns)
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Chunk items into rows of 4
                final List<List<_HrdMenuItem>> rows = [];
                for (var i = 0; i < items.length; i += 4) {
                  rows.add(items.sublist(i, (i + 4 > items.length) ? items.length : i + 4));
                }

                return Column(
                  children: rows.map((rowItems) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          ...rowItems.map((item) {
                            return Expanded(
                              child: _buildGridItem(item),
                            );
                          }),
                          // Fill remaining spots if row has less than 4 items
                          ...List.generate(4 - rowItems.length, (_) => const Expanded(child: SizedBox())),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(_HrdMenuItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: item.bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, size: 23, color: item.color),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _HrdMenuItem {
  final String title;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  _HrdMenuItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });
}
