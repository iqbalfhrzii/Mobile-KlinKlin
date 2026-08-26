import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/order_model.dart';

class PdfInvoiceService {
  /// Show modal dialog to choose stamp type and print/preview the invoice
  static Future<void> showPrintDialog(BuildContext context, OrderModel order) async {
    return showDialog(
      context: context,
      builder: (ctx) => InvoicePrintModal(order: order),
    );
  }

  /// Generate A4 PDF Invoice matching Web ERP design
  static Future<Uint8List> generateInvoice(
    OrderModel order, {
    String stempel = 'lunas', // 'lunas', 'uang_muka', 'tanpa_stempel'
  }) async {
    final pdf = pw.Document();

    // 1. Load Signature
    pw.MemoryImage? signatureImage;
    try {
      final sigData = await rootBundle.load(
        'assets/images/ttd_M_Aminuddin_Ghufron.png',
      );
      signatureImage = pw.MemoryImage(sigData.buffer.asUint8List());
    } catch (_) {
      // Ignored if signature not found
    }

    // 2. Format values
    final branchName = (order.customer.area.isNotEmpty
            ? order.customer.area
            : 'SURABAYA')
        .toUpperCase();

    final invoiceNumber = order.nomorPesanan.isNotEmpty
        ? order.nomorPesanan
        : (order.id.isNotEmpty ? order.id : 'INV-${DateTime.now().millisecondsSinceEpoch}');

    final tglInput = DateFormat('dd/MM/yyyy').format(order.tanggalInput);

    String formatRupiah(num amount) {
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );
      return formatter.format(amount);
    }

    // Calculations
    final num subtotal = order.subtotal > 0 ? order.subtotal : order.total;
    final num diskonPersen = order.pembayaran?.diskonPersen ?? 0.0;
    final num diskonAmount = order.discount != null && order.discount! > 0
        ? order.discount!
        : (subtotal * (diskonPersen / 100)).round();

    final num afterDiscount = (subtotal - diskonAmount) > 0 ? (subtotal - diskonAmount) : 0;
    final num ppnPersen = order.pembayaran?.ppn ?? order.ppn ?? 0;
    final num ppnAmount = (afterDiscount * (ppnPersen / 100)).round();
    final num totalAkhir = order.pembayaran?.total != null && order.pembayaran!.total! > 0
        ? order.pembayaran!.total!
        : (afterDiscount + ppnAmount);

    final terbilangText = _terbilang(totalAkhir.toInt());

    final paymentMethodStr = order.pembayaran?.metodePembayaran.isNotEmpty == true &&
            order.pembayaran?.metodePembayaran != '-'
        ? order.pembayaran!.metodePembayaran.toUpperCase()
        : (order.paymentMethod.isNotEmpty && order.paymentMethod != '-'
            ? order.paymentMethod.toUpperCase()
            : '-');

    // 3. Colors
    final navyBg = PdfColor.fromHex('#15395B');
    final skyText = PdfColor.fromHex('#5BA3C6');
    final lightBlueText = PdfColor.fromHex('#DBEAFE');
    final textDark = PdfColor.fromHex('#0F172A');
    final textMuted = PdfColor.fromHex('#64748B');
    final borderColor = PdfColor.fromHex('#E2E8F0');
    final tableHeaderBg = PdfColor.fromHex('#F8FAFC');

    // 4. Build Page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          buildBackground: (context) {
            // Watermark KLINKLIN
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Transform.rotate(
                  angle: -0.5236, // -30 degrees
                  child: pw.Text(
                    'KLINKLIN',
                    style: pw.TextStyle(
                      fontSize: 100,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#F1F5F9'),
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ==================== 1. HEADER ====================
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: navyBg,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(12),
                  ),
                ),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Left: Logo & Company Address
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.baseline,
                            children: [
                              pw.Text(
                                'KLIN',
                                style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                ),
                              ),
                              pw.Text(
                                'KLIN ',
                                style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                  color: skyText,
                                ),
                              ),
                              pw.Text(
                                branchName,
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            'Jl. Mojo Kidul No.23, Mojo, Kec. Gubeng, Surabaya, Jawa Timur 60285',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              color: lightBlueText,
                              lineSpacing: 1.3,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Telp: 08977475656  |  Website: www.klinklin.co.id',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: lightBlueText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    // Right: INVOICE Title & Code
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'INVOICE',
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: skyText,
                            letterSpacing: 2.0,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          invoiceNumber,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: lightBlueText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),

              // ==================== 2. BILLING INFO ====================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: Customer details
                  pw.Expanded(
                    flex: 6,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'DITAGIHKAN KEPADA',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          order.customer.name.isNotEmpty
                              ? order.customer.name
                              : '-',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        if (order.customer.address.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            order.customer.address,
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: textDark,
                              lineSpacing: 1.2,
                            ),
                          ),
                        ],
                        if (order.customer.phone.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            order.customer.phone,
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: textDark,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  // Right: Invoice Meta
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildMetaRow('Tanggal:', tglInput, textDark),
                        pw.SizedBox(height: 3),
                        _buildMetaRow('Cabang:', branchName, textDark),
                        pw.SizedBox(height: 3),
                        _buildMetaRow('Pembayaran:', paymentMethodStr, textDark),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 16),

              // ==================== 3. SERVICES TABLE ====================
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: tableHeaderBg,
                  border: pw.Border(
                    top: pw.BorderSide(color: borderColor, width: 1),
                    bottom: pw.BorderSide(color: borderColor, width: 1),
                  ),
                ),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Text(
                        'LAYANAN',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: textMuted,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        'QTY',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: textMuted,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        'HARGA',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: textMuted,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Table Body
              if (order.services.isEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Center(
                    child: pw.Text(
                      'Tidak ada layanan',
                      style: pw.TextStyle(fontSize: 9, color: textMuted),
                    ),
                  ),
                )
              else
                ...order.services.map((s) {
                  return pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: borderColor, width: 0.5),
                      ),
                    ),
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 5,
                          child: pw.Text(
                            s.name,
                            style: pw.TextStyle(
                              fontSize: 9.5,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            s.qty,
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: textMuted,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text(
                            formatRupiah(s.subtotal),
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                              fontSize: 9.5,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              pw.SizedBox(height: 16),

              // ==================== 4. TRANSFER & TOTALS ====================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: Transfer Bank Info
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TRANSFER KE',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          children: [
                            pw.Text(
                              'Bank Mandiri ',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            pw.Text(
                              '1780022255554',
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: textDark,
                              ),
                            ),
                          ],
                        ),
                        pw.Text(
                          'a.n. KlinKlin Indonesia Group',
                          style: pw.TextStyle(fontSize: 8, color: textMuted),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          children: [
                            pw.Text(
                              'Bank BCA ',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            pw.Text(
                              '8640679949',
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: textDark,
                              ),
                            ),
                          ],
                        ),
                        pw.Text(
                          'a.n. KlinKlin Indonesia Group',
                          style: pw.TextStyle(fontSize: 8, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  // Right: Total Card (Navy rounded)
                  pw.Container(
                    width: 220,
                    decoration: pw.BoxDecoration(
                      color: navyBg,
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(10),
                      ),
                    ),
                    padding: const pw.EdgeInsets.all(12),
                    child: pw.Column(
                      children: [
                        _buildTotalRow('Subtotal', formatRupiah(subtotal), lightBlueText),
                        pw.SizedBox(height: 4),
                        _buildTotalRow(
                          'Diskon',
                          diskonAmount > 0 ? '- ${formatRupiah(diskonAmount)}' : '- Rp 0',
                          lightBlueText,
                        ),
                        pw.SizedBox(height: 4),
                        _buildTotalRow(
                          'PPn (${ppnPersen.toInt()}%)',
                          formatRupiah(ppnAmount),
                          lightBlueText,
                        ),
                        pw.SizedBox(height: 6),
                        pw.Container(
                          height: 1,
                          color: PdfColor.fromHex('#2A4D70'),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Total',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.Text(
                              formatRupiah(totalAkhir),
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 14),

              // ==================== 5. TERBILANG BOX ====================
              pw.Container(
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  color: tableHeaderBg,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                  border: pw.Border.all(color: borderColor, width: 1),
                ),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: 'Terbilang: ',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      pw.TextSpan(
                        text: terbilangText,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontStyle: pw.FontStyle.italic,
                          color: textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              pw.Spacer(),

              // ==================== 6. FOOTER & SIGNATURE ====================
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: borderColor, width: 1),
                  ),
                ),
                padding: const pw.EdgeInsets.only(top: 10),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // Left: Note & Official Website
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Terima kasih telah mempercayakan kebersihan Anda kepada KLINKLIN. Simpan invoice ini sebagai bukti transaksi.',
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: textMuted,
                              lineSpacing: 1.3,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Website Resmi: www.klinklin.co.id',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 24),
                    // Right: Signature + Stamp
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'Hormat kami,',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            color: textMuted,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Stack(
                          alignment: pw.Alignment.center,
                          children: [
                            // Signature image
                            if (signatureImage != null)
                              pw.Image(
                                signatureImage,
                                width: 90,
                                height: 44,
                              )
                            else
                              pw.SizedBox(width: 90, height: 44),
                            // Stamp Overlay (LUNAS / UANG MUKA)
                            if (stempel == 'lunas' || stempel == 'uang_muka')
                              _buildStamp(stempel),
                          ],
                        ),
                        pw.Container(
                          width: 140,
                          height: 1,
                          color: textDark,
                          margin: const pw.EdgeInsets.only(top: 2, bottom: 2),
                        ),
                        pw.Text(
                          'M. Aminuddin Ghufron',
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // Stamp helper (Round Emerald Green Stamp)
  static pw.Widget _buildStamp(String stempelType) {
    final text = stempelType == 'lunas' ? 'LUNAS' : 'UANG MUKA';
    final emeraldColor = PdfColor.fromHex('#059669');

    return pw.Transform.rotate(
      angle: -0.2618, // -15 degrees in radians
      child: pw.Container(
        width: 70,
        height: 70,
        decoration: pw.BoxDecoration(
          shape: pw.BoxShape.circle,
          border: pw.Border.all(color: emeraldColor, width: 2.5),
        ),
        padding: const pw.EdgeInsets.all(3),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: stempelType == 'lunas' ? 11 : 8.5,
                fontWeight: pw.FontWeight.bold,
                color: emeraldColor,
                letterSpacing: 1.1,
              ),
            ),
            pw.Container(
              width: 42,
              height: 1.2,
              color: emeraldColor,
              margin: const pw.EdgeInsets.symmetric(vertical: 2),
            ),
            pw.Text(
              'PT KLINKLIN',
              style: pw.TextStyle(
                fontSize: 6,
                fontWeight: pw.FontWeight.bold,
                color: emeraldColor,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildMetaRow(String label, String value, PdfColor textColor) {
    return pw.Row(
      children: [
        pw.Container(
          width: 65,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTotalRow(String label, String value, PdfColor textColor) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            color: textColor,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      ],
    );
  }

  static String _terbilang(int nilai) {
    if (nilai == 0) return 'nol rupiah';

    String penyebut(int n) {
      n = n.abs();
      final huruf = [
        '',
        'satu',
        'dua',
        'tiga',
        'empat',
        'lima',
        'enam',
        'tujuh',
        'delapan',
        'sembilan',
        'sepuluh',
        'sebelas'
      ];
      if (n < 12) {
        return ' ${huruf[n]}';
      } else if (n < 20) {
        return '${penyebut(n - 10)} belas';
      } else if (n < 100) {
        return '${penyebut(n ~/ 10)} puluh${penyebut(n % 10)}';
      } else if (n < 200) {
        return ' seratus${penyebut(n - 100)}';
      } else if (n < 1000) {
        return '${penyebut(n ~/ 100)} ratus${penyebut(n % 100)}';
      } else if (n < 2000) {
        return ' seribu${penyebut(n - 1000)}';
      } else if (n < 1000000) {
        return '${penyebut(n ~/ 1000)} ribu${penyebut(n % 1000)}';
      } else if (n < 1000000000) {
        return '${penyebut(n ~/ 1000000)} juta${penyebut(n % 1000000)}';
      } else if (n < 1000000000000) {
        return '${penyebut(n ~/ 1000000000)} milyar${penyebut(n % 1000000000)}';
      }
      return '${penyebut(n ~/ 1000000000000)} triliun${penyebut(n % 1000000000000)}';
    }

    String hasil = '';
    if (nilai < 0) {
      hasil = 'minus ${penyebut(nilai).trim()}';
    } else {
      hasil = penyebut(nilai).trim();
    }
    if (hasil.isEmpty) return 'nol rupiah';
    return '${hasil[0].toUpperCase()}${hasil.substring(1)} rupiah';
  }
}

/// Modal Dialog matching the Web "Cetak Invoice" popup
class InvoicePrintModal extends StatelessWidget {
  final OrderModel order;

  const InvoicePrintModal({super.key, required this.order});

  void _printWithStamp(BuildContext context, String stempel) async {
    Navigator.pop(context);
    final docName = 'KLINKLIN-${order.customer.name}-${order.customer.area}-${order.nomorPesanan.isNotEmpty ? order.nomorPesanan : order.id}'
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');

    await Printing.layoutPdf(
      name: docName,
      onLayout: (format) => PdfInvoiceService.generateInvoice(order, stempel: stempel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Icon & Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.print_rounded,
                        color: Color(0xFF0284C7),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Cetak Invoice',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              'Pilih jenis stempel untuk invoice ini.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),

            const SizedBox(height: 20),

            // Option 1: Stempel LUNAS (Green)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => _printWithStamp(context, 'lunas'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Stempel LUNAS',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Option 2: Stempel UANG MUKA (Blue)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => _printWithStamp(context, 'uang_muka'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Stempel UANG MUKA',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Option 3: Tanpa Stempel (Outlined)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: () => _printWithStamp(context, 'tanpa_stempel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Tanpa Stempel',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
