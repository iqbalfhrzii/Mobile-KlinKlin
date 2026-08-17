import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import 'operasional_data_chat_screen.dart';
import 'tagihan_bulanan_screen.dart';
import 'monitoring_stok_opname_screen.dart';
import 'operasional_ringkasan_barang_screen.dart';
import 'operasional_approval_pengajuan_screen.dart';
import 'kantor_klinklin_screen.dart';
import 'operasional_purchase_order_screen.dart';
import 'operasional_cashflow_cabang_screen.dart';
import 'operasional_kpi_cs_screen.dart';
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
// TODO: import screens as they are created

class OperasionalMenuScreen extends StatelessWidget {
  const OperasionalMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Menu Operasional',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pilih menu untuk melanjutkan',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
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
        title: 'Operasional',
        items: [
          _MenuItem(
            icon: Icons.business,
            title: 'Kantor Klinklin',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const KantorKlinklinScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.receipt_long,
            title: 'Tagihan Bulanan',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TagihanBulananScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.inventory,
            title: 'Stok Opname',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MonitoringStokOpnameScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.inventory_2,
            title: 'Ringkasan Barang',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalRingkasanBarangScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.science,
            title: 'Pengajuan Alat & Chemical',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalApprovalPengajuanScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.receipt,
            title: 'Purchase Order',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalPurchaseOrderScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.account_balance_wallet,
            title: 'Cashflow Cabang',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalCashflowCabangScreen()));
            },
          ),
        ],
      ),
      _MenuSection(
        title: 'HCS',
        items: [
          _MenuItem(
            icon: Icons.analytics,
            title: 'Report CS',
            onTap: () {},
          ),
          _MenuItem(
            icon: Icons.bar_chart,
            title: 'KPI CS',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalKpiCsScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.chat,
            title: 'Data Chat',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalDataChatScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.description_outlined,
            title: 'Quotation',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalQuotationScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.archive,
            title: 'Arsip Nomor & Nominal',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalArsipPenawaranScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.groups,
            title: 'Evaluasi Rapat',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalEvaluasiRapatScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.timeline,
            title: 'Strategi Rapat',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalStrategiRapatScreen()));
            },
          ),
        ],
      ),
      _MenuSection(
        title: 'HSE',
        items: [
          _MenuItem(
            icon: Icons.warning_amber_rounded,
            title: 'Data Kecelakaan',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalDataKecelakaanScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.assignment_outlined,
            title: 'Laporan Lapangan',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalLaporanLapanganScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.monitor_heart_outlined,
            title: 'Kesehatan Berkala',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalKesehatanBerkalaScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.inventory_2_outlined,
            title: 'Tanda Terima APD & Suplemen',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalTandaTerimaApdScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.local_hospital_outlined,
            title: 'Layanan Kesehatan',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalLayananKesehatanScreen()));
            },
          ),
          _MenuItem(
            icon: Icons.badge_outlined,
            title: 'Surat Izin Mengemudi',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalSimScreen()));
            },
          ),
        ],
      ),
      _MenuSection(
        title: 'Pengaturan',
        items: [
          _MenuItem(
            icon: Icons.monetization_on_outlined,
            title: 'Target Omzet',
            onTap: () {},
          ),
          _MenuItem(
            icon: Icons.category_outlined,
            title: 'Master Barang',
            onTap: () {},
          ),
          _MenuItem(
            icon: Icons.brush_outlined,
            title: 'Permintaan Design',
            onTap: () {},
          ),
        ],
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      itemCount: menus.length,
      itemBuilder: (context, index) {
        final section = menus[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                section.title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            GridView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.9,
              ),
              itemCount: section.items.length,
              itemBuilder: (context, i) {
                final item = section.items[i];
                return _buildMenuCard(item);
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildMenuCard(_MenuItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                item.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSection {
  final String title;
  final List<_MenuItem> items;

  _MenuSection({required this.title, required this.items});
}

class _MenuItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  _MenuItem({required this.icon, required this.title, required this.onTap});
}
