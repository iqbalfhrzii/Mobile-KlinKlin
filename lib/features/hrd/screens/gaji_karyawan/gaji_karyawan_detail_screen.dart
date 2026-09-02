import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../../../../core/services/pdf_slip_gaji_service.dart';
import '../../services/hrd_service.dart';

String _toTitleCase(String text) {
  if (text.isEmpty) return text;
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

/// Menampilkan Modal Pop-up Bottom Sheet Detail Gaji Karyawan
void showGajiKaryawanDetailModal(BuildContext context, GajiKaryawanModel gaji) {
  showModalBottomSheet(
      useSafeArea: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => GajiKaryawanDetailBottomSheet(gaji: gaji),
  );
}

class GajiKaryawanDetailBottomSheet extends StatelessWidget {
  final GajiKaryawanModel gaji;
  final HrdService _hrdService = HrdService();
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  GajiKaryawanDetailBottomSheet({super.key, required this.gaji});

  void _printSlip(BuildContext context) async {
    Uint8List pdfBytes;
    try {
      final bytes = await _hrdService.fetchPrintSlipPdfBytes(gaji.id);
      if (bytes.length > 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
        pdfBytes = bytes;
      } else {
        pdfBytes = await PdfSlipGajiService.generateSlip(gaji);
      }
    } catch (_) {
      pdfBytes = await PdfSlipGajiService.generateSlip(gaji);
    }

    await Printing.layoutPdf(
      name: 'Slip_Gaji_${gaji.karyawan?.nama ?? gaji.id}',
      onLayout: (format) => pdfBytes,
    );
  }

  Widget _buildSummaryRow(String label, int amount, {bool isMinus = false, bool isMutedIfZero = true}) {
    final bool isZero = amount == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isZero && isMutedIfZero ? Colors.grey.shade400 : AppColors.textDark,
                fontWeight: isZero && isMutedIfZero ? FontWeight.normal : FontWeight.w500,
              ),
            ),
          ),
          Text(
            isMinus && amount > 0
                ? '- ${currencyFormatter.format(amount)}'
                : currencyFormatter.format(amount),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isMinus
                  ? (amount > 0 ? const Color(0xFFDC2626) : Colors.grey.shade400)
                  : (isZero && isMutedIfZero ? Colors.grey.shade400 : const Color(0xFF1E293B)),
              fontWeight: isZero && isMutedIfZero ? FontWeight.w500 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawName = gaji.karyawan?.nama ?? gaji.snapshotCabang ?? 'Karyawan';
    final employeeName = _toTitleCase(rawName);
    final jabatan = gaji.snapshotJabatan ?? 'Staff';
    final cabang = gaji.snapshotCabang ?? '-';
    final initial = employeeName.isNotEmpty ? employeeName[0].toUpperCase() : 'K';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header Modal
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employeeName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Slip Gaji',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          if (cabang.isNotEmpty && cabang != '-') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                cabang,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFEA580C),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. Info Capsules (Jenis Gaji, Periode, Jabatan) ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF64748B).withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEFF6FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.work_outline_rounded, size: 13, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              gaji.jenisGaji.toUpperCase(),
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '• $jabatan',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              gaji.jenisGaji == 'bulanan'
                                  ? '${gaji.periodeBulan.toString().padLeft(2, '0')}/${gaji.periodeTahun}'
                                  : '${gaji.jumlahHariKerja} Hari',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // --- 2. Take Home Pay Hero Card ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1D4ED8).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TAKE HOME PAY (THP)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.85),
                                letterSpacing: 0.8,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currencyFormatter.format(gaji.takeHomePay),
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Pendapatan: ${currencyFormatter.format(gaji.totalGajiDiterima)}',
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.9)),
                              ),
                              Text(
                                'Potongan: -${currencyFormatter.format(gaji.totalPotongan)}',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFFCA5A5)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- 3. Pendapatan Card ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF64748B).withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.arrow_circle_up_rounded, color: Color(0xFF059669), size: 16),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Rincian Pendapatan',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (gaji.jenisGaji == 'harian')
                          _buildSummaryRow('Gaji Harian (${gaji.jumlahHariKerja} hr)', gaji.gajiPokok, isMutedIfZero: false)
                        else
                          _buildSummaryRow('Gaji Pokok', gaji.gajiPokok, isMutedIfZero: false),
                        _buildSummaryRow('Tunjangan Kos', gaji.tunjanganKos),
                        _buildSummaryRow('Tunjangan Kerja', gaji.tunjanganKerja),
                        _buildSummaryRow('Premi BPJS', gaji.premiBpjs),
                        _buildSummaryRow('Bonus Bulanan', gaji.bonusBulanan),
                        if (gaji.totalBonusLainnya > 0) _buildSummaryRow('Bonus Tambahan', gaji.totalBonusLainnya),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TOTAL PENDAPATAN',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF047857)),
                              ),
                              Text(
                                currencyFormatter.format(gaji.totalGajiDiterima),
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF047857)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // --- 4. Potongan Card ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF64748B).withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.arrow_circle_down_rounded, color: Color(0xFFDC2626), size: 16),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Rincian Potongan',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildSummaryRow('Absen / Terlambat', gaji.potonganAbsen + gaji.potonganKeterlambatan + gaji.potonganTidakAbsen, isMinus: true),
                        _buildSummaryRow('BPJS Ketenagakerjaan', gaji.bpjsKetenagakerjaan, isMinus: true),
                        _buildSummaryRow('Kasbon', gaji.kasbon, isMinus: true),
                        _buildSummaryRow(
                          gaji.keteranganPotonganLainnya?.isNotEmpty == true ? gaji.keteranganPotonganLainnya! : 'Potongan Lainnya',
                          gaji.potonganLainnya,
                          isMinus: true,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TOTAL POTONGAN',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFB91C1C)),
                              ),
                              Text(
                                '- ${currencyFormatter.format(gaji.totalPotongan)}',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFFB91C1C)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- 5. Action Button ---
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _printSlip(context),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.white),
                      label: Text(
                        'Cetak / Download Slip PDF',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

/// Fallback / Compatibility wrapper jika masih ada yang memanggil GajiKaryawanDetailScreen
class GajiKaryawanDetailScreen extends StatelessWidget {
  final GajiKaryawanModel gaji;
  const GajiKaryawanDetailScreen({super.key, required this.gaji});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Detail Gaji', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: GajiKaryawanDetailBottomSheet(gaji: gaji),
    );
  }
}
