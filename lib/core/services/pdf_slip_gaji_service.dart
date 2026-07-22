import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../data/hrd_models.dart';
import '../utils/currency_formatter.dart';

class PdfSlipGajiService {
  static Future<Uint8List> generateSlip(GajiKaryawanModel gaji) async {
    final pdf = pw.Document();

    final namaKaryawan = gaji.karyawan?.nama ?? '-';
    final cabang = (gaji.snapshotCabang != null && gaji.snapshotCabang!.trim().isNotEmpty)
        ? gaji.snapshotCabang!.trim().toUpperCase()
        : (gaji.karyawan?.cabang?.namaCabang != null && gaji.karyawan!.cabang!.namaCabang.trim().isNotEmpty)
            ? gaji.karyawan!.cabang!.namaCabang.trim().toUpperCase()
            : '';
    final jabatan = (gaji.snapshotJabatan != null && gaji.snapshotJabatan!.trim().isNotEmpty)
        ? gaji.snapshotJabatan!.trim().toUpperCase()
        : (gaji.karyawan?.jabatan?.namaJabatan != null && gaji.karyawan!.jabatan!.namaJabatan.trim().isNotEmpty)
            ? gaji.karyawan!.jabatan!.namaJabatan.trim().toUpperCase()
            : '-';
    final statusKaryawan = (gaji.snapshotStatus != null && gaji.snapshotStatus!.trim().isNotEmpty)
        ? gaji.snapshotStatus!.trim().toUpperCase()
        : (gaji.karyawan?.statusKaryawan != null && gaji.karyawan!.statusKaryawan!.trim().isNotEmpty)
            ? gaji.karyawan!.statusKaryawan!.trim().toUpperCase()
            : '-';
    final noRek = (gaji.karyawan?.noRekening != null && gaji.karyawan!.noRekening!.trim().isNotEmpty)
        ? gaji.karyawan!.noRekening!
        : '-';

    final monthNames = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final bulanStr = (gaji.periodeBulan != null && gaji.periodeBulan! >= 1 && gaji.periodeBulan! <= 12)
        ? monthNames[gaji.periodeBulan!]
        : '';
    final periodeHeader = '$bulanStr ${gaji.periodeTahun ?? ''}'.trim();

    final now = DateTime.now();
    final tglCetak = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    String formatRp(int val) => 'Rp ${CurrencyInputFormatter.format(val)}';

    // Calculate total income before deductions
    final int totalPendapatan = (gaji.jenisGaji.toLowerCase() == 'harian'
            ? (gaji.gajiPokokHarian * (gaji.jumlahHariKerja ?? 0))
            : gaji.gajiPokok) +
        gaji.bonusBulanan +
        gaji.tunjanganKos +
        gaji.tunjanganKerja +
        gaji.premiBpjs +
        gaji.totalBonus;

    String formatDateStr(String? dateStr) {
      if (dateStr == null || dateStr.trim().isEmpty) return '-';
      try {
        final parts = dateStr.trim().split('-');
        if (parts.length == 3) {
          return '${parts[2]}/${parts[1]}/${parts[0]}';
        }
      } catch (_) {}
      return dateStr;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#002063'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                        ),
                        child: pw.Text(
                          'K',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 3),
                      pw.Text(
                        'linKlin ',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#002063'),
                        ),
                      ),
                      if (cabang.isNotEmpty)
                        pw.Text(
                          cabang,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#002063'),
                          ),
                        ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'SLIP GAJI',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#002063'),
                        ),
                      ),
                      if (periodeHeader.isNotEmpty)
                        pw.Text(
                          periodeHeader,
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                        ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey400, thickness: 1),
              pw.SizedBox(height: 10),

              // Profile Section
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Nama', namaKaryawan),
                        _buildInfoRow('Jabatan', jabatan),
                        _buildInfoRow('Status', statusKaryawan),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Cabang', cabang),
                        _buildInfoRow('Periode', '${formatDateStr(gaji.awalPeriode)} s/d ${formatDateStr(gaji.akhirPeriode)}'),
                        _buildInfoRow('No. Rekening', noRek),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Pendapatan & Potongan Tables
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Pendapatan Column
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          color: PdfColor.fromHex('#1A2536'),
                          child: pw.Text(
                            'PENDAPATAN',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey300),
                          ),
                          child: pw.Column(
                            children: [
                              if (gaji.jenisGaji.toLowerCase() == 'harian')
                                _buildItemRow(
                                  'Gaji Pokok (${gaji.jumlahHariKerja ?? 0} hari x ${formatRp(gaji.gajiPokokHarian)})',
                                  formatRp(gaji.gajiPokokHarian * (gaji.jumlahHariKerja ?? 0)),
                                )
                              else
                                _buildItemRow('Gaji Pokok', formatRp(gaji.gajiPokok)),

                              if (gaji.bonusBulanan > 0) _buildItemRow('Bonus Bulanan', formatRp(gaji.bonusBulanan)),
                              if (gaji.tunjanganKos > 0) _buildItemRow('Tunjangan Kos', formatRp(gaji.tunjanganKos)),
                              if (gaji.tunjanganKerja > 0) _buildItemRow('Tunjangan Kerja', formatRp(gaji.tunjanganKerja)),
                              if (gaji.premiBpjs > 0) _buildItemRow('Premi BPJS', formatRp(gaji.premiBpjs)),
                              if (gaji.bonusReview > 0) _buildItemRow('Bonus Review', formatRp(gaji.bonusReview)),
                              if (gaji.bonusTanggalMerah > 0) _buildItemRow('Bonus Tgl Merah', formatRp(gaji.bonusTanggalMerah)),
                              if (gaji.totalKilometer > 0) _buildItemRow('Kilometer', formatRp(gaji.totalKilometer)),
                              if (gaji.totalDeepclean > 0) _buildItemRow('DeepClean', formatRp(gaji.totalDeepclean)),
                              if (gaji.totalSalon > 0) _buildItemRow('Salon', formatRp(gaji.totalSalon)),
                              if (gaji.totalTips > 0) _buildItemRow('Tips', formatRp(gaji.totalTips)),
                              if (gaji.totalParkir > 0) _buildItemRow('Parkir', formatRp(gaji.totalParkir)),
                              if (gaji.totalLembur > 0) _buildItemRow('Lembur', formatRp(gaji.totalLembur)),
                              if (gaji.totalUangMakan > 0) _buildItemRow('Uang Makan', formatRp(gaji.totalUangMakan)),
                              if (gaji.totalBonusLainnya > 0) _buildItemRow('Bonus Lainnya', formatRp(gaji.totalBonusLainnya)),

                              pw.Divider(color: PdfColors.grey300),
                              _buildItemRow('Total Pendapatan', formatRp(totalPendapatan), isBold: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  // Potongan Column
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          color: PdfColor.fromHex('#A82222'),
                          child: pw.Text(
                            'POTONGAN',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey300),
                          ),
                          child: pw.Column(
                            children: [
                              if (gaji.kasbon > 0) _buildItemRow('Kasbon', formatRp(gaji.kasbon)),
                              if (gaji.potonganTidakAbsen > 0) _buildItemRow('Potongan Tidak Absen', formatRp(gaji.potonganTidakAbsen)),
                              if (gaji.potonganKeterlambatan > 0) _buildItemRow('Keterlambatan', formatRp(gaji.potonganKeterlambatan)),
                              if (gaji.potonganAbsen > 0) _buildItemRow('Absen', formatRp(gaji.potonganAbsen)),
                              if (gaji.bpjsKetenagakerjaan > 0) _buildItemRow('BPJS Ketenagakerjaan', formatRp(gaji.bpjsKetenagakerjaan)),
                              if (gaji.potonganLainnya > 0)
                                _buildItemRow(
                                  'Potongan Lainnya${gaji.keteranganPotonganLainnya != null ? ' (${gaji.keteranganPotonganLainnya})' : ''}',
                                  formatRp(gaji.potonganLainnya),
                                ),
                              if (gaji.totalPotongan == 0) _buildItemRow('-', formatRp(0)),

                              pw.Divider(color: PdfColors.grey300),
                              _buildItemRow('Total Potongan', formatRp(gaji.totalPotongan), isBold: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Take Home Pay Banner
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: PdfColor.fromHex('#1A2536'),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TAKE HOME PAY',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      formatRp(gaji.takeHomePay),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Footer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Dicetak: $tglCetak',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                  pw.Column(
                    children: [
                      pw.Text(
                        'Hormat kami,',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 36),
                      pw.Container(
                        width: 140,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'HRD KlinKlin',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
