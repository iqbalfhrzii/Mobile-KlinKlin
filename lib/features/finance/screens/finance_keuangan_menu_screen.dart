import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/gradient_header.dart';
import 'finance_cashflow_cabang_screen.dart';
import 'finance_approval_kas_screen.dart';
import 'finance_download_screen.dart';
import '../../operasional/screens/operasional_permintaan_design_screen.dart';
import '../../operasional/screens/operasional_pengumuman_screen.dart';
import 'finance_pengaturan_ppn_screen.dart';

class FinanceKeuanganMenuScreen extends StatelessWidget {
  const FinanceKeuanganMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          GradientHeader(
            child: Row(
              children: [
                if (Navigator.canPop(context)) ...[
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Menu Keuangan & Pengaturan', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
                      Text('Kas, Unduhan & Pengumuman', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
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
                  'Cashflow Cabang', 
                  'Pantau dan kelola data pemasukan & pengeluaran kas seluruh cabang', 
                  Icons.account_balance_wallet_rounded, 
                  const Color(0xFF059669),
                  const FinanceCashflowCabangScreen(),
                ),
                const SizedBox(height: 12),
                _buildMenuCard(
                  context, 
                  'Approval Pengajuan Kas', 
                  'Daftar pengajuan uang kas dari CS cabang yang menunggu persetujuan', 
                  Icons.assignment_turned_in_rounded, 
                  const Color(0xFFD97706),
                  const FinanceApprovalKasScreen(),
                ),
                const SizedBox(height: 12),
                _buildMenuCard(
                  context, 
                  'Download Laporan (.xlsx / .csv)', 
                  'Ekspor rekap data pesanan & gaji karyawan ke file Excel / CSV', 
                  Icons.file_download_rounded, 
                  const Color(0xFF0891B2),
                  const FinanceDownloadScreen(),
                ),
                const SizedBox(height: 12),
                _buildMenuCard(
                  context, 
                  'Permintaan Design', 
                  'Ajukan dan pantau permohonan materi desain marketing & operasional', 
                  Icons.palette_rounded, 
                  const Color(0xFF7C3AED),
                  const OperasionalPermintaanDesignScreen(department: 'finance'),
                ),
                const SizedBox(height: 12),
                _buildMenuCard(
                  context, 
                  'Pengumuman', 
                  'Kelola dan lihat siaran informasi pengumuman divisi dan cabang', 
                  Icons.notifications_active_rounded, 
                  const Color(0xFFEA580C),
                  const OperasionalPengumumanScreen(),
                ),
                const SizedBox(height: 12),
                _buildMenuCard(
                  context, 
                  'Pengaturan PPN', 
                  'Atur kewajiban penggunaan PPN (11%) untuk setiap cabang operasional', 
                  Icons.receipt_long_rounded, 
                  const Color(0xFF2563EB),
                  const FinancePengaturanPpnScreen(),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, String subtitle, IconData icon, Color color, Widget destination) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
