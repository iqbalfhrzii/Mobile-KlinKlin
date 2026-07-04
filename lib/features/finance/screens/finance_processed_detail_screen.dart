import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/data/order_model.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/api/api_client.dart';

class FinanceProcessedDetailScreen extends StatelessWidget {
  final OrderModel order;
  const FinanceProcessedDetailScreen({super.key, required this.order});

  String _formatCurrency(int amount) {
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(amount);
  }

  String _getInitials(String name) {
    List<String> names = name.split(" ");
    String initials = "";
    int numWords = 2;
    if (names.length < numWords) {
      numWords = names.length;
    }
    for (var i = 0; i < numWords; i++) {
      if (names[i].isNotEmpty) {
        initials += names[i][0].toUpperCase();
      }
    }
    return initials;
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl.startsWith('http')
                    ? imageUrl
                    : '${ApiClient.baseUrl.replaceAll('/api', '')}/storage/${imageUrl.replaceFirst(RegExp(r'^/?storage/'), '')}',
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.broken_image, color: AppColors.textMuted, size: 48),
                      const SizedBox(height: 16),
                      Text('Gagal memuat gambar', style: GoogleFonts.inter(color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payment = order.pembayaran;
    final double diskonPersen = payment?.diskonPersen ?? 0.0;
    final int subtotal = order.total;
    final int diskonValue = (subtotal * (diskonPersen / 100)).round();
    final int totalSetelahDiskon = subtotal - diskonValue;
    
    final int ppnPercentage = order.ppn ?? payment?.ppn ?? 11;
    final int ppn = (totalSetelahDiskon * (ppnPercentage / 100)).round();
    final int total = totalSetelahDiskon + ppn;
    
    final String dateStr = DateFormat('yyyy-MM-dd - HH:mm:ss').format(order.tanggalInput);
    
    String cleanerName = '-';
    if (order.cleaners.isNotEmpty) {
      cleanerName = order.cleaners.map((e) => e.name).join(', ');
    }

    String paymentMethod = order.paymentMethod;
    if (paymentMethod.toLowerCase() == 'midtrans' || paymentMethod.toLowerCase() == 'manual_transfer') {
      paymentMethod = 'Transfer';
    }

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.id, style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.white.withOpacity(0.7))),
                      Text('Detail Pembayaran', style: GoogleFonts.inter(
                          fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Selesai / Lunas',
                    style: GoogleFonts.inter(
                      color: AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Total Tagihan Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.success.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Pembayaran Lunas',
                                style: GoogleFonts.inter(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Tagihan',
                                style: GoogleFonts.inter(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatCurrency(total),
                                style: GoogleFonts.inter(
                                  color: AppColors.textDark,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, color: AppColors.textMuted, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    dateStr,
                                    style: GoogleFonts.inter(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pelanggan Card
                  _buildSectionCard('PELANGGAN', [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFFE8F0FE),
                          child: Text(
                            _getInitials(order.customer.name),
                            style: GoogleFonts.inter(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.customer.name,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                order.customer.phone,
                                style: GoogleFonts.inter(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      order.customer.address ?? 'Tidak ada alamat',
                                      style: GoogleFonts.inter(
                                        color: AppColors.textMuted,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Rincian Layanan Card
                  _buildSectionCard('RINCIAN LAYANAN', [
                    ...order.services.map((service) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F0FE),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.cleaning_services_outlined, color: AppColors.primary, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      service.name,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${service.qty} x layanan',
                                      style: GoogleFonts.inter(
                                        color: AppColors.textMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatCurrency(service.subtotal),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )),
                    Divider(color: Colors.grey[200], thickness: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                        Text(_formatCurrency(subtotal), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    if (diskonValue > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Diskon ${diskonPersen == diskonPersen.toInt() ? diskonPersen.toInt() : diskonPersen}%', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                          Text('-${_formatCurrency(diskonValue)}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.error)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                      Row(
                        children: [
                          Icon(
                            ppnPercentage > 0 ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                            size: 16,
                            color: ppnPercentage > 0 ? AppColors.primary : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text('PPN (11%)', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                        ],
                      ),
                        Text(_formatCurrency(ppn), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.grey[200], thickness: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Pembayaran', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                          _formatCurrency(total),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Informasi Pembayaran Card
                  _buildSectionCard('INFORMASI PEMBAYARAN', [
                    _buildInfoRow(Icons.credit_card_outlined, 'Metode Bayar', paymentMethod, isBold: true),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.check_circle, 'Status Pembayaran', 'Lunas', valueColor: AppColors.success, isBold: true),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.person_outline, 'Petugas Kebersihan', cleanerName, isBold: true),
                  ]),
                  const SizedBox(height: 16),

                  // Bukti Pembayaran Card (if any)
                  if (order.paymentProof != null && order.paymentProof!.isNotEmpty)
                    _buildSectionCard('BUKTI PEMBAYARAN', [
                      GestureDetector(
                        onTap: () => _showImageDialog(context, order.paymentProof!),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.receipt_long, color: AppColors.success, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Lihat Bukti Pembayaran',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Terverifikasi - Tersimpan',
                                      style: GoogleFonts.inter(
                                        color: AppColors.success,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.check_circle, color: AppColors.success),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            color: valueColor ?? AppColors.textDark,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
