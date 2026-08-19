import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfQuotationService {
  static Future<Uint8List> generateQuotation(dynamic quotation) async {
    final pdf = pw.Document();

    // Load Logo if available
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    // Load Signature if available
    pw.MemoryImage? signatureImage;
    try {
      final sigData = await rootBundle.load('assets/images/ttd_M_Aminuddin_Ghufron.png');
      signatureImage = pw.MemoryImage(sigData.buffer.asUint8List());
    } catch (_) {}

    // Parsing data
    final String noQuo = quotation['no_quotation']?.toString() ?? '-';
    
    String formatTgl(dynamic val) {
      if (val == null) return '-';
      try {
        final dt = DateTime.parse(val.toString());
        return DateFormat('dd/MM/yyyy').format(dt);
      } catch (_) {
        return val.toString();
      }
    }

    final String tgl = formatTgl(quotation['tanggal']);
    final String expDate = formatTgl(quotation['exp_date']);
    final String namaCustomer = quotation['nama_customer']?.toString() ?? '-';
    final String alamat = quotation['alamat']?.toString() ?? '-';
    final String jobLocation = (quotation['job_location'] != null && quotation['job_location'].toString().isNotEmpty)
        ? quotation['job_location'].toString()
        : alamat;
    final String namaCabang = quotation['cabang']?['nama']?.toString().toUpperCase() ??
        quotation['cabang']?['nama_cabang']?.toString().toUpperCase() ??
        '-';

    // Rincian items
    List<dynamic> rincianList = [];
    if (quotation['rincian'] != null) {
      if (quotation['rincian'] is List) {
        rincianList = quotation['rincian'];
      } else if (quotation['rincian'] is String) {
        try {
          rincianList = jsonDecode(quotation['rincian']);
        } catch (_) {}
      }
    }

    final num subtotal = num.tryParse(quotation['subtotal_calc']?.toString() ?? quotation['subtotal']?.toString() ?? '0') ?? 0;
    final num diskon = num.tryParse(quotation['diskon']?.toString() ?? '0') ?? 0;
    final num ppnPersen = num.tryParse(quotation['ppn']?.toString() ?? '0') ?? 0;
    final num ppnNominal = num.tryParse(quotation['ppn_nominal_calc']?.toString() ?? quotation['ppn_nominal']?.toString() ?? '0') ?? 0;
    final num pphPersen = num.tryParse(quotation['pph']?.toString() ?? '0') ?? 0;
    final num pphNominal = num.tryParse(quotation['pph_nominal_calc']?.toString() ?? quotation['pph_nominal']?.toString() ?? '0') ?? 0;
    final num grandTotal = num.tryParse(quotation['grand_total_calc']?.toString() ?? quotation['grand_total']?.toString() ?? '0') ??
        (subtotal - diskon + ppnNominal - pphNominal);

    final bool hasAlatChemical = quotation['alat_chemical_klinklin'] == 1 || quotation['alat_chemical_klinklin'] == true;

    final String namaPenyetuju = quotation['penyetuju']?['nama']?.toString() ??
        quotation['penyetuju']?['name']?.toString() ??
        'M. Aminuddin Ghufron';

    String formatRp(num amount) {
      final formatter = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
      return formatter.format(amount).trim();
    }

    final redTextColor = PdfColor.fromHex('#923419');
    final blueTextColor = PdfColor.fromHex('#4B789B');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // 1. Header (Logo & Company Info)
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (logoImage != null)
                            pw.Container(
                              width: 100,
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: pw.BoxDecoration(
                                color: PdfColor.fromHex('#002063'),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                              ),
                              child: pw.Image(logoImage),
                            )
                          else ...[
                            pw.Text(
                              'KlinKlin',
                              style: pw.TextStyle(
                                fontSize: 24,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                              ),
                            ),
                            pw.Text(
                              'CLEANING SERVICE',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 2,
                                color: blueTextColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                      pw.Container(
                        width: 270,
                        padding: const pw.EdgeInsets.only(left: 10),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(left: pw.BorderSide(color: PdfColors.black, width: 1)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'PT. KLINKLIN INDONESIA GROUP',
                              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Jl. Mojo Kidul No. 23, Mojo, Gubeng, Surabaya, Jawa Timur 62085',
                              style: pw.TextStyle(fontSize: 8, color: redTextColor, height: 1.2),
                            ),
                            pw.Text(
                              'Phone (+62) 889-9141-1785 email : divisimarketing@klinklin.co.id',
                              style: const pw.TextStyle(fontSize: 8, height: 1.2),
                            ),
                            pw.Text(
                              'web : www.klinklin.co.id',
                              style: const pw.TextStyle(fontSize: 8, height: 1.2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 6),
                  pw.Container(height: 1.5, color: PdfColors.black),
                  pw.SizedBox(height: 6),

                  // 2. Title: QUOTATION
                  pw.Center(
                    child: pw.Text(
                      'QUOTATION',
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5),
                    ),
                  ),
                  pw.SizedBox(height: 8),

                  // 3. Info Table (Left & Right)
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Left Column
                      pw.Expanded(
                        flex: 3,
                        child: pw.Table(
                          columnWidths: {
                            0: const pw.FixedColumnWidth(60),
                            1: const pw.FixedColumnWidth(8),
                            2: const pw.FlexColumnWidth(),
                          },
                          children: [
                            _buildInfoRow('No. Quo', noQuo),
                            _buildInfoRow('Date', tgl),
                            _buildInfoRow('Exp Date', expDate),
                            _buildInfoRow('Currency', 'IDR'),
                            pw.TableRow(children: [
                              pw.SizedBox(height: 4),
                              pw.SizedBox(height: 4),
                              pw.SizedBox(height: 4),
                            ]),
                            pw.TableRow(
                              children: [
                                pw.Text('To', style: const pw.TextStyle(fontSize: 8.5)),
                                pw.Text(':', style: const pw.TextStyle(fontSize: 8.5)),
                                pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(namaCustomer, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                                    pw.Text(alamat, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                                  ],
                                ),
                              ],
                            ),
                            pw.TableRow(children: [
                              pw.SizedBox(height: 4),
                              pw.SizedBox(height: 4),
                              pw.SizedBox(height: 4),
                            ]),
                            _buildInfoRow('Job Location', jobLocation),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 16),
                      // Right Column
                      pw.Expanded(
                        flex: 2,
                        child: pw.Table(
                          columnWidths: {
                            0: const pw.FixedColumnWidth(45),
                            1: const pw.FixedColumnWidth(8),
                            2: const pw.FlexColumnWidth(),
                          },
                          children: [
                            pw.TableRow(
                              children: [
                                pw.Text('Branch', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                                pw.Text(':', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                                pw.Text(namaCabang, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 8),

                  // 4. Items Table
                  pw.Table(
                    border: const pw.TableBorder(
                      top: pw.BorderSide(color: PdfColors.black, width: 1.2),
                      bottom: pw.BorderSide(color: PdfColors.black, width: 1.2),
                    ),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(26),
                      1: const pw.FlexColumnWidth(4),
                      2: const pw.FixedColumnWidth(35),
                      3: const pw.FixedColumnWidth(75),
                      4: const pw.FixedColumnWidth(80),
                    },
                    children: [
                      // Table Header
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.2)),
                        ),
                        children: [
                          _buildTableHeaderCell('NO', align: pw.TextAlign.center),
                          _buildTableHeaderCell('DESCRIPTION'),
                          _buildTableHeaderCell('QTY', align: pw.TextAlign.center),
                          _buildTableHeaderCell('PRICE', align: pw.TextAlign.right),
                          _buildTableHeaderCell('AMOUNT', align: pw.TextAlign.right),
                        ],
                      ),
                      // Table Rows
                      if (rincianList.isEmpty)
                        pw.TableRow(
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(vertical: 8),
                              child: pw.Text('-', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8.5)),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(vertical: 8),
                              child: pw.Text('Tidak ada rincian', style: const pw.TextStyle(fontSize: 8.5)),
                            ),
                            pw.Container(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text('-', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8.5))),
                            pw.Container(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text('-', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
                            pw.Container(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text('-', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
                          ],
                        )
                      else
                        ...List.generate(rincianList.length, (index) {
                          final r = rincianList[index];
                          final desc = r['deskripsi']?.toString() ?? '-';
                          final num qty = num.tryParse(r['qty']?.toString() ?? '1') ?? 1;
                          final num harga = num.tryParse(r['harga']?.toString() ?? '0') ?? 0;
                          final num totalItem = qty * harga;

                          return pw.TableRow(
                            children: [
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 3),
                                child: pw.Text('${index + 1}', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8.5, color: redTextColor, fontWeight: pw.FontWeight.bold)),
                              ),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 3),
                                child: pw.Text(desc, style: pw.TextStyle(fontSize: 8.5, color: redTextColor, fontWeight: pw.FontWeight.bold)),
                              ),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 3),
                                child: pw.Text('$qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8.5, color: redTextColor)),
                              ),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 3),
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('IDR', style: pw.TextStyle(fontSize: 8, color: redTextColor)),
                                    pw.Text(formatRp(harga), style: pw.TextStyle(fontSize: 8.5, color: redTextColor, fontWeight: pw.FontWeight.bold)),
                                  ],
                                ),
                              ),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 3),
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('IDR', style: pw.TextStyle(fontSize: 8, color: redTextColor)),
                                    pw.Text(formatRp(totalItem), style: pw.TextStyle(fontSize: 8.5, color: redTextColor, fontWeight: pw.FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                    ],
                  ),

                  pw.SizedBox(height: 6),
                  pw.Container(height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 6),

                  // 5. Summary Section
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Left Side: Note
                      pw.Expanded(
                        flex: 3,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (hasAlatChemical)
                              pw.Text(
                                'Note : Alat & Chemical dari Klinklin',
                                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                              ),
                          ],
                        ),
                      ),
                      // Right Side: Breakdown
                      pw.Expanded(
                        flex: 2,
                        child: pw.Column(
                          children: [
                            _buildSummaryPriceRow('Gross Total', 'IDR', formatRp(subtotal)),
                            _buildSummaryPriceRow('Diskon', 'IDR', formatRp(diskon)),
                            if (ppnNominal > 0 || ppnPersen > 0)
                              _buildSummaryPriceRow('PPN ($ppnPersen%)', 'IDR', formatRp(ppnNominal)),
                            if (pphNominal > 0 || pphPersen > 0)
                              _buildSummaryPriceRow('PPh ($pphPersen%)', 'IDR', '-${formatRp(pphNominal)}'),
                            pw.Container(
                              margin: const pw.EdgeInsets.symmetric(vertical: 2),
                              height: 1,
                              color: PdfColors.black,
                            ),
                            _buildSummaryPriceRow('Net Total', 'IDR', formatRp(grandTotal)),
                            pw.Container(
                              margin: const pw.EdgeInsets.symmetric(vertical: 2),
                              height: 1.2,
                              color: PdfColors.black,
                            ),
                            _buildSummaryPriceRow('Grand Total', 'IDR', formatRp(grandTotal), isBold: true),
                            pw.Container(
                              margin: const pw.EdgeInsets.only(top: 1.5),
                              height: 1.2,
                              color: PdfColors.black,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 6),

                  // 6. Inword (Terbilang)
                  pw.Row(
                    children: [
                      pw.SizedBox(width: 45, child: pw.Text('Inword', style: const pw.TextStyle(fontSize: 8.5))),
                      pw.Text(': ', style: const pw.TextStyle(fontSize: 8.5)),
                      pw.Expanded(
                        child: pw.Text(
                          '${_terbilang(grandTotal.toInt())} Rupiah',
                          style: pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic),
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 14),

                  // 7. Signature
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Container(
                      width: 130,
                      child: pw.Column(
                        children: [
                          pw.Text('Sincerely,', style: const pw.TextStyle(fontSize: 8.5)),
                          pw.SizedBox(height: 2),
                          if (signatureImage != null)
                            pw.Container(height: 38, child: pw.Image(signatureImage))
                          else
                            pw.Container(
                              height: 38,
                              alignment: pw.Alignment.center,
                              child: pw.Text('Signature', style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey400, fontStyle: pw.FontStyle.italic)),
                            ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            namaPenyetuju,
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
                          ),
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(height: 8),

                  // 8. Payment Instructions Footer
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Pembayaran Cash / Transfer via',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        children: [
                          pw.SizedBox(width: 65, child: pw.Text('Bank Mandiri', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                          pw.Text(': 1780022255554 a.n KLINKLIN INDONESIA GROUP', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Row(
                        children: [
                          pw.SizedBox(width: 65, child: pw.Text('Bank BCA', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                          pw.Text(': 8640679949 a.n KLINKLIN INDONESIA GROUP', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.TableRow _buildInfoRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8.5)),
        pw.Text(':', style: const pw.TextStyle(fontSize: 8.5)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 8.5)),
      ],
    );
  }

  static pw.Widget _buildTableHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _buildSummaryPriceRow(String label, String currency, String amount, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
            ),
          ),
          pw.SizedBox(
            width: 22,
            child: pw.Text(
              currency,
              style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
            ),
          ),
          pw.Text(
            amount,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
        ],
      ),
    );
  }

  static String _terbilang(int angka) {
    if (angka == 0) return 'Nol';

    String konversi(int n) {
      final units = [
        '',
        'Satu',
        'Dua',
        'Tiga',
        'Empat',
        'Lima',
        'Enam',
        'Tujuh',
        'Delapan',
        'Sembilan',
        'Sepuluh',
        'Sebelas',
      ];
      if (n == 0) return '';
      if (n < 12) return units[n];
      if (n < 20) return '${units[n - 10]} Belas';
      if (n < 100) return '${units[n ~/ 10]} Puluh ${konversi(n % 10)}';
      if (n < 200) return 'Seratus ${konversi(n - 100)}';
      if (n < 1000) return '${units[n ~/ 100]} Ratus ${konversi(n % 100)}';
      if (n < 2000) return 'Seribu ${konversi(n - 1000)}';
      if (n < 1000000) return '${konversi(n ~/ 1000)} Ribu ${konversi(n % 1000)}';
      if (n < 1000000000) return '${konversi(n ~/ 1000000)} Juta ${konversi(n % 1000000)}';
      if (n < 1000000000000) return '${konversi(n ~/ 1000000000)} Milyar ${konversi(n % 1000000000)}';
      return '${konversi(n ~/ 1000000000000)} Triliun ${konversi(n % 1000000000000)}';
    }

    final raw = konversi(angka).trim().replaceAll(RegExp(r'\s+'), ' ');
    if (raw.isEmpty) return 'Nol';
    return raw;
  }
}
