import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import 'finance_pemasukan_screen.dart';
import 'finance_pengeluaran_screen.dart';
import 'finance_download_screen.dart';
import 'finance_cash_flow_menu_screen.dart';

class FinanceKeuanganMenuScreen extends StatelessWidget {
  const FinanceKeuanganMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Manajemen', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.7))),
                      Text('Keuangan', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(20),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildMenuCard(
                  context, 
                  'Pemasukan', 
                  'Daftar uang masuk', 
                  Icons.arrow_circle_down_rounded, 
                  Colors.green,
                  const FinancePemasukanScreen(),
                ),
                _buildMenuCard(
                  context, 
                  'Pengeluaran', 
                  'Daftar uang keluar', 
                  Icons.arrow_circle_up_rounded, 
                  Colors.red,
                  const FinancePengeluaranScreen(),
                ),
                _buildMenuCard(
                  context, 
                  'Approval Cash Flow', 
                  'Persetujuan order', 
                  Icons.fact_check_rounded, 
                  AppColors.primary,
                  const FinanceCashFlowMenuScreen(),
                ),
                _buildMenuCard(
                  context, 
                  'Download Laporan', 
                  'Export data ke Excel', 
                  Icons.download_rounded, 
                  Colors.purple,
                  const FinanceDownloadScreen(),
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
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
