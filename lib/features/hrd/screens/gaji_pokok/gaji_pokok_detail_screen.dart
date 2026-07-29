import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import 'gaji_pokok_form_screen.dart';

class GajiPokokDetailScreen extends StatelessWidget {
  final GajiPokokModel gajiPokok;
  final VoidCallback onDataChanged;

  const GajiPokokDetailScreen({
    super.key, 
    required this.gajiPokok,
    required this.onDataChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final res = await Navigator.push(
            context, 
            MaterialPageRoute(builder: (_) => GajiPokokFormScreen(gajiPokok: gajiPokok))
          );
          if (res == true) {
            onDataChanged();
            Navigator.pop(context, true);
          }
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Text(
                  'Detail Gaji Pokok',
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.teal.withValues(alpha: 0.1),
                          child: const Icon(Icons.monetization_on_rounded, size: 36, color: Colors.teal),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          gajiPokok.jabatan?.namaJabatan ?? '-',
                          style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            gajiPokok.statusKaryawan.toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        _buildInfoRow(Icons.storefront_rounded, 'Cabang', gajiPokok.cabang?.namaCabang ?? '-'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Rincian Gaji', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildMoneyRow('Gaji Pokok', gajiPokok.gajiPokok, currencyFormatter, isBold: true),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                        _buildMoneyRow('Bonus Bulanan', gajiPokok.bonusBulanan, currencyFormatter),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                        _buildMoneyRow('Tunjangan Kos', gajiPokok.tunjanganKos, currencyFormatter),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                        _buildMoneyRow('Tunjangan Kerja', gajiPokok.tunjanganKerja, currencyFormatter),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                        _buildMoneyRow('Gaji Pokok Harian', gajiPokok.gajiPokokHarian, currencyFormatter),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                        _buildMoneyRow('Premi BPJS', gajiPokok.premiBpjs, currencyFormatter, isDeduction: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100), // padding for FAB
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 2),
              Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMoneyRow(String label, int amount, NumberFormat formatter, {bool isBold = false, bool isDeduction = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted, fontWeight: isBold ? FontWeight.w600 : FontWeight.normal)),
        Text(
          '${isDeduction && amount > 0 ? "- " : ""}${formatter.format(amount)}',
          style: GoogleFonts.inter(
            fontSize: isBold ? 16 : 14, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600, 
            color: isDeduction ? Colors.red : AppColors.textDark
          ),
        ),
      ],
    );
  }
}
