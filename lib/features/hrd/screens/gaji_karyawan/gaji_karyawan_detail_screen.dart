import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';

class GajiKaryawanDetailScreen extends StatelessWidget {
  final GajiKaryawanModel gaji;
  final HrdService _hrdService = HrdService();
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  GajiKaryawanDetailScreen({super.key, required this.gaji});

  void _printSlip(BuildContext context) async {
    final url = Uri.parse(_hrdService.getPrintSlipGajiUrl(gaji.id));
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal membuka tautan PDF.')));
      }
    }
  }

  Widget _buildSummaryRow(String label, int amount, {bool isMinus = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 14, color: isBold ? AppColors.textDark : AppColors.textMuted, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            isMinus ? '- ${currencyFormatter.format(amount)}' : currencyFormatter.format(amount),
            style: GoogleFonts.inter(
              fontSize: 14, 
              color: isMinus ? Colors.red : (isBold ? Colors.indigo : AppColors.textDark), 
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

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
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Text(
                  'Detail Gaji Karyawan',
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(radius: 20, backgroundColor: Colors.indigo.shade50, child: const Icon(Icons.person, color: Colors.indigo)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(gaji.karyawan?.nama ?? gaji.snapshotCabang ?? '-', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo.shade900)),
                                  Text('${gaji.snapshotJabatan} • ${gaji.snapshotCabang}', style: GoogleFonts.inter(fontSize: 12, color: Colors.indigo.shade700)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Jenis Gaji', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                                Text(gaji.jenisGaji.toUpperCase(), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Periode', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                                Text(gaji.jenisGaji == 'bulanan' ? '${gaji.periodeBulan.toString().padLeft(2, '0')}/${gaji.periodeTahun}' : '${gaji.jumlahHariKerja} Hari', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Text('PENDAPATAN', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        if (gaji.jenisGaji == 'harian')
                          _buildSummaryRow('Gaji Harian (${gaji.jumlahHariKerja} hr)', gaji.gajiPokok)
                        else
                          _buildSummaryRow('Gaji Pokok', gaji.gajiPokok),
                        _buildSummaryRow('Tunjangan Kos', gaji.tunjanganKos),
                        _buildSummaryRow('Tunjangan Kerja', gaji.tunjanganKerja),
                        _buildSummaryRow('Premi BPJS', gaji.premiBpjs),
                        _buildSummaryRow('Bonus Bulanan', gaji.bonusBulanan),
                        if (gaji.totalBonusLainnya > 0) _buildSummaryRow('Bonus Tambahan', gaji.totalBonusLainnya),
                        const Divider(height: 24),
                        _buildSummaryRow('TOTAL PENDAPATAN', gaji.totalGajiDiterima, isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text('POTONGAN', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        _buildSummaryRow('Absen/Terlambat', gaji.potonganAbsen + gaji.potonganKeterlambatan + gaji.potonganTidakAbsen),
                        _buildSummaryRow('BPJS Ketenagakerjaan', gaji.bpjsKetenagakerjaan),
                        _buildSummaryRow('Kasbon', gaji.kasbon),
                        _buildSummaryRow(gaji.keteranganPotonganLainnya?.isNotEmpty == true ? gaji.keteranganPotonganLainnya! : 'Potongan Lain', gaji.potonganLainnya),
                        const Divider(height: 24),
                        _buildSummaryRow('TOTAL POTONGAN', gaji.totalPotongan, isMinus: true, isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.indigo.shade600, Colors.indigo.shade900]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('TAKE HOME PAY', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(currencyFormatter.format(gaji.takeHomePay), style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.yellowAccent)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _printSlip(context),
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.amberAccent),
                      label: Text('Download Slip PDF', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
