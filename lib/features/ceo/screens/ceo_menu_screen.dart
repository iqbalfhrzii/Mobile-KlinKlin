import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../operasional/screens/monitoring_stok_opname_screen.dart';
import '../../operasional/screens/operasional_cashflow_cabang_screen.dart';
import '../../operasional/screens/operasional_approval_pengajuan_screen.dart';
import '../../operasional/screens/operasional_purchase_order_screen.dart';
import '../../operasional/screens/operasional_pengumuman_screen.dart';
import '../../operasional/screens/operasional_permintaan_design_screen.dart';
import 'ceo_data_chat_screen.dart';

class CeoMenuScreen extends StatelessWidget {
  const CeoMenuScreen({super.key});

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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Menu Eksekutif',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Pusat monitoring, keuangan & pengadaan cabang',
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
        title: 'Operasional & Keuangan Cabang',
        subtitle: 'Monitoring inventaris & arus kas operasional',
        sectionIcon: Icons.storefront_rounded,
        sectionColor: const Color(0xFF0284C7),
        items: [
          _MenuItem(
            icon: Icons.fact_check_rounded,
            title: 'Stok Opname',
            iconColor: const Color(0xFF6366F1),
            bgColor: const Color(0xFFEEF2FF),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MonitoringStokOpnameScreen(),
                ),
              );
            },
          ),
          _MenuItem(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Cashflow Cabang',
            iconColor: const Color(0xFF059669),
            bgColor: const Color(0xFFECFDF5),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OperasionalCashflowCabangScreen(),
                ),
              );
            },
          ),
        ],
      ),
      _MenuSection(
        title: 'Pembelian Alat Cabang',
        subtitle: 'Pengadaan barang dari CS & purchase order operasional',
        sectionIcon: Icons.shopping_bag_rounded,
        sectionColor: const Color(0xFFD97706),
        items: [
          _MenuItem(
            icon: Icons.assignment_turned_in_rounded,
            title: 'Pengajuan Alat CS',
            iconColor: const Color(0xFFD97706),
            bgColor: const Color(0xFFFEF3C7),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OperasionalApprovalPengajuanScreen(
                    isReadOnly: true,
                  ),
                ),
              );
            },
          ),
          _MenuItem(
            icon: Icons.receipt_long_rounded,
            title: 'Pembelian Alat Operasional',
            iconColor: const Color(0xFF8B5CF6),
            bgColor: const Color(0xFFF5F3FF),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OperasionalPurchaseOrderScreen(
                    isReadOnly: false,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      _MenuSection(
        title: 'Komunikasi & Modul Tambahan',
        subtitle: 'Informasi pengumuman, materi promosi & data chat',
        sectionIcon: Icons.campaign_rounded,
        sectionColor: const Color(0xFFEA580C),
        items: [
          _MenuItem(
            icon: Icons.campaign_rounded,
            title: 'Pengumuman',
            iconColor: const Color(0xFFEA580C),
            bgColor: const Color(0xFFFFEDD5),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OperasionalPengumumanScreen(),
                ),
              );
            },
          ),
          _MenuItem(
            icon: Icons.palette_rounded,
            title: 'Permintaan Design',
            iconColor: const Color(0xFFEC4899),
            bgColor: const Color(0xFFFCE7F3),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OperasionalPermintaanDesignScreen(),
                ),
              );
            },
          ),
          _MenuItem(
            icon: Icons.mark_chat_unread_rounded,
            title: 'Data Chat',
            iconColor: const Color(0xFF0284C7),
            bgColor: const Color(0xFFE0F2FE),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CeoDataChatScreen(),
                ),
              );
            },
          ),
        ],
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: menus.length,
      itemBuilder: (context, index) {
        final section = menus[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: section.sectionColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(section.sectionIcon, size: 17, color: section.sectionColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          section.subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${section.items.length}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
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
