import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../../core/data/hrd_models.dart';
import 'gaji_pokok_form_sheet.dart';

class GajiPokokDetailSheet extends StatelessWidget {
  final GajiPokokModel gajiPokok;
  final VoidCallback? onDataChanged;

  const GajiPokokDetailSheet({
    super.key,
    required this.gajiPokok,
    this.onDataChanged,
  });

  static Future<bool?> show(
    BuildContext context, {
    required GajiPokokModel gajiPokok,
    VoidCallback? onDataChanged,
  }) {
    return showModalBottomSheet<bool>(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GajiPokokDetailSheet(
        gajiPokok: gajiPokok,
        onDataChanged: onDataChanged,
      ),
    );
  }

  Color _getStatusColor(String status) {
    final s = status.toUpperCase();
    if (s == 'TETAP') return const Color(0xFF059669);
    if (s == 'TETAP KOOR') return const Color(0xFF7C3AED);
    if (s == 'SEMI') return const Color(0xFFD97706);
    if (s == 'FREELANCE') return const Color(0xFF0284C7);
    if (s == 'VENDOR') return const Color(0xFF475569);
    if (s == 'KONTRAK') return const Color(0xFF2563EB);
    return const Color(0xFF0D9488);
  }

  Color _getStatusBgColor(String status) {
    final s = status.toUpperCase();
    if (s == 'TETAP') return const Color(0xFFECFDF5);
    if (s == 'TETAP KOOR') return const Color(0xFFF5F3FF);
    if (s == 'SEMI') return const Color(0xFFFFFBEB);
    if (s == 'FREELANCE') return const Color(0xFFE0F2FE);
    if (s == 'VENDOR') return const Color(0xFFF1F5F9);
    if (s == 'KONTRAK') return const Color(0xFFEFF6FF);
    return const Color(0xFFCCFBF1);
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final statusColor = _getStatusColor(gajiPokok.statusKaryawan);
    final statusBgColor = _getStatusBgColor(gajiPokok.statusKaryawan);

    // Total fixed monthly income (pokok + bonus bulanan + tunjangan)
    final totalBulanan = gajiPokok.gajiPokok + gajiPokok.bonusBulanan + gajiPokok.tunjanganKos + gajiPokok.tunjanganKerja;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle pill
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Profile
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gajiPokok.jabatan?.namaJabatan ?? 'Semua Jabatan',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            gajiPokok.statusKaryawan.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.storefront_rounded, size: 13, color: Color(0xFF64748B)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            gajiPokok.cabang?.namaCabang ?? '-',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total Monthly Summary Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Komponen Bulanan',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF166534),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              currencyFormatter.format(totalBulanan),
                              style: GoogleFonts.inter(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Text(
                            '/ Bulan',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF166534),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Rincian Komponen Gaji & Tunjangan',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Detail Rows Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          icon: Icons.account_balance_wallet_rounded,
                          iconColor: const Color(0xFF0284C7),
                          label: 'Gaji Pokok (Bulanan)',
                          value: currencyFormatter.format(gajiPokok.gajiPokok),
                          isBold: true,
                        ),
                        const Divider(height: 20, color: Color(0xFFE2E8F0)),
                        _buildDetailRow(
                          icon: Icons.today_rounded,
                          iconColor: const Color(0xFF0D9488),
                          label: 'Gaji Pokok Harian',
                          value: currencyFormatter.format(gajiPokok.gajiPokokHarian),
                          subtext: 'Dihitung per hari kerja',
                        ),
                        const Divider(height: 20, color: Color(0xFFE2E8F0)),
                        _buildDetailRow(
                          icon: Icons.card_giftcard_rounded,
                          iconColor: const Color(0xFF7C3AED),
                          label: 'Bonus Bulanan',
                          value: currencyFormatter.format(gajiPokok.bonusBulanan),
                        ),
                        const Divider(height: 20, color: Color(0xFFE2E8F0)),
                        _buildDetailRow(
                          icon: Icons.home_work_rounded,
                          iconColor: const Color(0xFFD97706),
                          label: 'Tunjangan Kos',
                          value: currencyFormatter.format(gajiPokok.tunjanganKos),
                        ),
                        const Divider(height: 20, color: Color(0xFFE2E8F0)),
                        _buildDetailRow(
                          icon: Icons.work_outline_rounded,
                          iconColor: const Color(0xFF2563EB),
                          label: 'Tunjangan Kerja',
                          value: currencyFormatter.format(gajiPokok.tunjanganKerja),
                        ),
                        const Divider(height: 20, color: Color(0xFFE2E8F0)),
                        _buildDetailRow(
                          icon: Icons.health_and_safety_rounded,
                          iconColor: gajiPokok.premiBpjs > 0 ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                          label: 'Premi BPJS Ketenagakerjaan',
                          value: gajiPokok.premiBpjs > 0 ? currencyFormatter.format(gajiPokok.premiBpjs) : 'Tidak Aktif (Rp 0)',
                          isDeduction: gajiPokok.premiBpjs > 0,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Action Buttons: Edit & Tutup
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Tutup',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context); // Close detail sheet
                    final res = await GajiPokokFormSheet.show(context, gajiPokok: gajiPokok);
                    if (res == true && onDataChanged != null) {
                      onDataChanged!();
                    }
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: Text(
                    'Edit Standar Gaji',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? subtext,
    bool isBold = false,
    bool isDeduction = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF475569),
                ),
              ),
              if (subtext != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtext,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isBold ? 14.5 : 13.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isDeduction ? const Color(0xFF059669) : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
