import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/gradient_header.dart';
import 'operasional_data_chat_screen.dart';
import 'tagihan_bulanan_screen.dart';
import 'monitoring_stok_opname_screen.dart';
import 'operasional_ringkasan_barang_screen.dart';
import 'operasional_approval_pengajuan_screen.dart';
import 'kantor_klinklin_screen.dart';
import 'operasional_purchase_order_screen.dart';
import 'operasional_cashflow_cabang_screen.dart';
import 'operasional_kpi_main_screen.dart';
import 'operasional_quotation_screen.dart';
import 'operasional_arsip_penawaran_screen.dart';
import 'operasional_evaluasi_rapat_screen.dart';
import 'operasional_strategi_rapat_screen.dart';
import 'operasional_data_kecelakaan_screen.dart';
import 'operasional_laporan_lapangan_screen.dart';
import 'operasional_kesehatan_berkala_screen.dart';
import 'operasional_tanda_terima_apd_screen.dart';
import 'operasional_layanan_kesehatan_screen.dart';
import 'operasional_sim_screen.dart';
import 'operasional_monthly_report_screen.dart';
import 'operasional_kajian_rd_screen.dart';
import 'operasional_target_omzet_screen.dart';
import 'operasional_permintaan_design_screen.dart';
import '../../master_barang/screens/master_barang_screen.dart';
// TODO: import screens as they are created

class OperasionalMenuScreen extends StatelessWidget {
  const OperasionalMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  if (Navigator.canPop(context)) ...[
                    const AppBackButton(),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Menu Operasional',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Pusat kontrol & modul operasional KlinKlin',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _buildMenuGrid(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid(BuildContext context) {
    final menus = [
      _MenuSection(
        title: 'Operasional Cabang',
        subtitle: 'Manajemen kantor, stok & pengadaan',
        sectionIcon: Icons.apartment_rounded,
        sectionColor: const Color(0xFF0284C7),
        items: [
          _MenuItem(
            icon: Icons.storefront_rounded,
            title: 'Kantor Klinklin',
            iconColor: const Color(0xFF0284C7),
            bgColor: const Color(0xFFE0F2FE),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const KantorKlinklinScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.receipt_long_rounded,
            title: 'Tagihan Bulanan',
            iconColor: const Color(0xFF059669),
            bgColor: const Color(0xFFECFDF5),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TagihanBulananScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.fact_check_rounded,
            title: 'Stok Opname',
            iconColor: const Color(0xFF6366F1),
            bgColor: const Color(0xFFEEF2FF),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MonitoringStokOpnameScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.inventory_2_rounded,
            title: 'Ringkasan Barang',
            iconColor: const Color(0xFF0D9488),
            bgColor: const Color(0xFFCCFBF1),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalRingkasanBarangScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.science_rounded,
            title: 'Pengajuan Alat & Chem',
            iconColor: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF3E8FF),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalApprovalPengajuanScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.shopping_cart_checkout_rounded,
            title: 'Purchase Order',
            iconColor: const Color(0xFFD97706),
            bgColor: const Color(0xFFFEF3C7),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalPurchaseOrderScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Cashflow Cabang',
            iconColor: const Color(0xFF10B981),
            bgColor: const Color(0xFFD1FAE5),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalCashflowCabangScreen()));
            },
          ),
        ],
      ),
      _MenuSection(
        title: 'HCS & Komersial',
        subtitle: 'Performa CS, chat, penawaran & rapat',
        sectionIcon: Icons.trending_up_rounded,
        sectionColor: const Color(0xFF2563EB),
        items: [
          _MenuItem(
            icon: Icons.query_stats_rounded,
            title: 'Report CS',
            iconColor: const Color(0xFF2563EB),
            bgColor: const Color(0xFFDBEAFE),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalKpiMainScreen(initialIndex: 0)));
            },
          ),
          _MenuItem(
            icon: Icons.leaderboard_rounded,
            title: 'KPI Cabang',
            iconColor: const Color(0xFFEA580C),
            bgColor: const Color(0xFFFFEDD5),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalKpiMainScreen(initialIndex: 1)));
            },
          ),
          _MenuItem(
            icon: Icons.mark_chat_unread_rounded,
            title: 'Data Chat',
            iconColor: const Color(0xFFDB2777),
            bgColor: const Color(0xFFFCE7F3),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalDataChatScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.request_quote_rounded,
            title: 'Quotation',
            iconColor: const Color(0xFFCA8A04),
            bgColor: const Color(0xFFFEF9C3),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalQuotationScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.folder_special_rounded,
            title: 'Arsip Penawaran',
            iconColor: const Color(0xFF4F46E5),
            bgColor: const Color(0xFFEDE9FE),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalArsipPenawaranScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.groups_rounded,
            title: 'Evaluasi Rapat',
            iconColor: const Color(0xFF0891B2),
            bgColor: const Color(0xFFCFFAFE),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalEvaluasiRapatScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.insights_rounded,
            title: 'Strategi Rapat',
            iconColor: const Color(0xFF9333EA),
            bgColor: const Color(0xFFF3E8FF),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalStrategiRapatScreen()));
            },
          ),
        ],
      ),
      _MenuSection(
        title: 'HSE & Keselamatan Kerja',
        subtitle: 'K3, kesehatan, APD & sertifikasi',
        sectionIcon: Icons.health_and_safety_rounded,
        sectionColor: const Color(0xFFDC2626),
        items: [
          _MenuItem(
            icon: Icons.warning_amber_rounded,
            title: 'Data Kecelakaan',
            iconColor: const Color(0xFFDC2626),
            bgColor: const Color(0xFFFEE2E2),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalDataKecelakaanScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.assignment_turned_in_rounded,
            title: 'Laporan Lapangan',
            iconColor: const Color(0xFFD97706),
            bgColor: const Color(0xFFFEF3C7),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalLaporanLapanganScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.favorite_rounded,
            title: 'Kesehatan Berkala',
            iconColor: const Color(0xFFE11D48),
            bgColor: const Color(0xFFFFE4E6),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalKesehatanBerkalaScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.shield_rounded,
            title: 'Tanda Terima APD',
            iconColor: const Color(0xFF059669),
            bgColor: const Color(0xFFD1FAE5),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalTandaTerimaApdScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.local_hospital_rounded,
            title: 'Layanan Kesehatan',
            iconColor: const Color(0xFF0284C7),
            bgColor: const Color(0xFFE0F2FE),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalLayananKesehatanScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.badge_rounded,
            title: 'Surat Izin Mengemudi',
            iconColor: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF3E8FF),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalSimScreen()));
            },
          ),
        ],
      ),
      _MenuSection(
        title: 'R&D & Analisis',
        subtitle: 'Laporan bulanan & riset operasional',
        sectionIcon: Icons.psychology_rounded,
        sectionColor: const Color(0xFF9333EA),
        items: [
          _MenuItem(
            icon: Icons.auto_graph_rounded,
            title: 'Monthly Report',
            iconColor: const Color(0xFF2563EB),
            bgColor: const Color(0xFFDBEAFE),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalMonthlyReportScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.science_outlined,
            title: 'Kajian R&D',
            iconColor: const Color(0xFF9333EA),
            bgColor: const Color(0xFFF3E8FF),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalKajianRdScreen()));
            },
          ),
        ],
      ),
      _MenuSection(
        title: 'Master & Pengaturan',
        subtitle: 'Target omzet & master data',
        sectionIcon: Icons.tune_rounded,
        sectionColor: const Color(0xFF475569),
        items: [
          _MenuItem(
            icon: Icons.track_changes_rounded,
            title: 'Target Omzet',
            iconColor: const Color(0xFFD97706),
            bgColor: const Color(0xFFFEF3C7),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalTargetOmzetScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.category_rounded,
            title: 'Master Barang',
            iconColor: const Color(0xFF0D9488),
            bgColor: const Color(0xFFCCFBF1),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MasterBarangScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.palette_rounded,
            title: 'Permintaan Design',
            iconColor: const Color(0xFFEC4899),
            bgColor: const Color(0xFFFCE7F3),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalPermintaanDesignScreen()));
            },
          ),
        ],
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: menus.length,
      itemBuilder: (context, index) {
        final section = menus[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: section.sectionColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(section.sectionIcon, size: 16, color: section.sectionColor),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                section.title,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                section.subtitle,
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${section.items.length} Menu',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.76,
                ),
                itemCount: section.items.length,
                itemBuilder: (context, i) {
                  final item = section.items[i];
                  return _buildMenuCard(item);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuCard(_MenuItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: item.bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: item.iconColor.withValues(alpha: 0.18)),
                boxShadow: [
                  BoxShadow(
                    color: item.iconColor.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(item.icon, color: item.iconColor, size: 24),
            ),
            const SizedBox(height: 5),
            Text(
              item.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
                height: 1.15,
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

class _MenuSection {
  final String title;
  final String subtitle;
  final IconData sectionIcon;
  final Color sectionColor;
  final List<_MenuItem> items;

  _MenuSection({
    required this.title,
    required this.subtitle,
    required this.sectionIcon,
    required this.sectionColor,
    required this.items,
  });
}

class _MenuItem {
  final IconData icon;
  final String title;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.bgColor,
    required this.onTap,
  });
}
