import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../data/order_model.dart';

class PdfInvoiceService {
  static Future<Uint8List> generateInvoice(OrderModel order) async {
    final pdf = pw.Document();

    // Load Logo
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      // Ignored if logo not found
    }

    pw.MemoryImage? signatureImage;
    try {
      final sigData = await rootBundle.load(
        'assets/images/ttd_M_Aminuddin_Ghufron.png',
      );
      signatureImage = pw.MemoryImage(sigData.buffer.asUint8List());
    } catch (e) {
      // Ignored if signature not found
    }

    final branchName = order.customer.area.toUpperCase();
    final now = DateTime.now();
    final tglCetak =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final jamCetak =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final tglInput =
        '${order.tanggalInput.day.toString().padLeft(2, '0')}/${order.tanggalInput.month.toString().padLeft(2, '0')}/${order.tanggalInput.year}';

    String formatRupiah(int amount) {
      final str = amount.toString();
      String result = '';
      int count = 0;
      for (int i = str.length - 1; i >= 0; i--) {
        if (count != 0 && count % 3 == 0) {
          result = '.$result';
        }
        result = str[i] + result;
        count++;
      }
      return 'Rp$result';
    }

    final diskonPersen = order.pembayaran?.diskonPersen ?? 0.0;
    final diskonLayanan = (order.total * (diskonPersen / 100)).round();
    final totalSetelahDiskon = order.total - diskonLayanan;
    
    final ppnPersen = order.pembayaran?.ppn ?? order.ppn ?? 11;
    final ppnValue = (totalSetelahDiskon * (ppnPersen / 100)).round();
    final totalTagihan = totalSetelahDiskon + ppnValue;

    String cleanerNames = order.cleaners.map((c) => c.name).join(', ');
    if (cleanerNames.isEmpty) cleanerNames = '-';

    String getStatusText(OrderStatus status) {
      if (status == OrderStatus.completed) {
        return 'Sudah Diverifikasi';
      } else {
        return 'Sudah Bayar';
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            // HEADER
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        width: 90,
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#002063'),
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(8),
                          ),
                        ),
                        child: pw.Image(logoImage),
                      ),
                    pw.SizedBox(width: 12),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'KLINKLIN $branchName',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#002063'),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Layanan Jasa Kebersihan Profesional',
                          style: pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          'Website: www.klinklin.co.id',
                          style: pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Tgl Cetak: $tglCetak',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      'Jam Cetak: $jamCetak',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // TITLE
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'RINCIAN BIAYA PESANAN',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  pw.Text(
                    'INVOICE KLINKLIN',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // INFO BOX
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Col 1
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('No. Order / Inv', order.id),
                        _buildInfoRow('Tgl Input', tglInput),
                        _buildInfoRow('Nama Customer', order.customer.name),
                        _buildInfoRow('No. WA Customer', order.customer.phone),
                        _buildInfoRow('Alamat', order.customer.address),
                        _buildInfoRow('Cabang', order.customer.area),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  // Col 2
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          'Tanggal Pengerjaan',
                          order.services.isNotEmpty
                              ? order.services.first.tanggalPengerjaan
                              : '-',
                        ),
                        _buildInfoRow(
                          'Waktu Pengerjaan',
                          order.services.isNotEmpty
                              ? order.services.first.waktuPengerjaan
                              : '-',
                        ),
                        _buildInfoRow(
                          'Status Order',
                          getStatusText(order.status),
                        ),
                        _buildInfoRow('Metode Pembayaran', order.paymentMethod),
                        _buildInfoRow('Chat Dari', order.chatDari.name),
                        _buildInfoRow('Nama Cleaner', cleanerNames),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // TABLE HEADER
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(width: 1.5),
                  bottom: pw.BorderSide(width: 1.5),
                ),
              ),
              padding: const pw.EdgeInsets.symmetric(
                vertical: 6,
                horizontal: 4,
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      'Layanan / Deskripsi',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Qty / Detail',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'Harga',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'Subtotal',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // TABLE BODY
            ...order.services.map((s) {
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 4,
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        s.name,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        s.qty,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        formatRupiah(s.price),
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        formatRupiah(s.subtotal),
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),

            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1.5),

            // SUMMARY
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 250,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.SizedBox(height: 8),
                      _buildSummaryRow(
                        'Subtotal (Rp)',
                        formatRupiah(order.total),
                      ),
                      if (diskonLayanan > 0)
                        _buildSummaryRow('Diskon ${diskonPersen == diskonPersen.toInt() ? diskonPersen.toInt() : diskonPersen}% (Rp)', '-${formatRupiah(diskonLayanan)}'),
                      _buildSummaryRow('PPN ($ppnPersen%)', formatRupiah(ppnValue)),
                      pw.SizedBox(height: 8),
                      pw.Container(height: 1.5, color: PdfColors.black),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'TOTAL TAGIHAN (Rp)',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          pw.Text(
                            formatRupiah(totalTagihan),
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 40),

            // FOOTER (Signatures)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'KLINKLIN $branchName, $tglCetak',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Terima kasih telah menggunakan jasa kami.',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Sincerely',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 4),
                    if (signatureImage != null)
                      pw.Image(signatureImage, width: 80, height: 40)
                    else
                      pw.SizedBox(height: 40),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'M. Aminuddin Ghufron',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 100,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
          pw.Text(' : ', style: const pw.TextStyle(fontSize: 9)),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}
