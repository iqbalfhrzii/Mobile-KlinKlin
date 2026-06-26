import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/payment_service.dart';
import '../../orders/services/order_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/data/order_model.dart';

class PaymentDetailScreen extends StatefulWidget {
  const PaymentDetailScreen({super.key, required this.order});
  final OrderModel order;

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  OrderModel get _o => widget.order;

  String _fmt(int n) => 'Rp ${n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  bool get _isPaid => _o.paymentStatus == 'paid' || _o.paymentStatus == 'approved';
  bool get _isWaitingCancel => _o.status == OrderStatus.waitingCancelApproval;
  bool get _isPending => _o.paymentStatus == 'pending' || _o.status == OrderStatus.waitingPaymentApproval;
  bool get _isCancelled => _o.paymentStatus == 'cancelled' || _o.paymentStatus == 'rejected' || _o.status == OrderStatus.cancelled;

  bool get _canAct => !_isPaid && !_isPending && !_isCancelled && !_isWaitingCancel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // ── Sticky bottom action bar ──────────────────────────────────────
      bottomNavigationBar: _canAct ? _buildBottomBar(context) : null,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, _canAct ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAmountHero(),
                  const SizedBox(height: 14),
                  _buildCustomerCard(),
                  const SizedBox(height: 12),
                  _buildServicesCard(),
                  const SizedBox(height: 12),
                  _buildPaymentInfo(),
                  if (_o.cancelReason != null) ...[
                    const SizedBox(height: 12),
                    _buildCancelCard(),
                  ],
                  if (_o.paymentProof != null) ...[
                    const SizedBox(height: 12),
                    _buildProofCard(),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Row(children: [
        HeaderBackButton(onTap: () => Navigator.pop(context, true)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Detail Pembayaran', style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          Text(_o.id, style: GoogleFonts.inter(
              fontSize: 11, color: Colors.white.withOpacity(0.65))),
        ])),
        StatusBadge(status: _o.status),
      ]),
    );
  }

  // ─── Amount hero card ────────────────────────────────────────────────────
  Widget _buildAmountHero() {
    final Color accent;
    final String statusText;
    final IconData statusIcon;

    if (_isCancelled) {
      accent = AppColors.error;
      statusText = 'Pesanan Dibatalkan';
      statusIcon = Icons.cancel_rounded;
    } else if (_isWaitingCancel) {
      accent = AppColors.error.withOpacity(0.8);
      statusText = 'Menunggu Approval Cancel';
      statusIcon = Icons.pending_actions_rounded;
    } else if (_isPaid) {
      accent = AppColors.statusDone;
      statusText = 'Pembayaran Lunas';
      statusIcon = Icons.check_circle_rounded;
    } else if (_isPending) {
      accent = AppColors.statusPending;
      statusText = 'Menunggu Persetujuan';
      statusIcon = Icons.hourglass_top_rounded;
    } else {
      accent = AppColors.primary;
      statusText = 'Belum Lunas';
      statusIcon = Icons.payment_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.25)),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(children: [
        // Top colored strip
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Icon(statusIcon, color: accent, size: 16),
            const SizedBox(width: 6),
            Text(statusText, style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600, color: accent)),
          ]),
        ),
        // Amount
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total Tagihan', style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(height: 2),
              Text(_fmt((_o.total * 1.11).round()), style: GoogleFonts.inter(
                  fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.schedule_rounded, size: 11, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(child: Text(_o.schedule, style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.textMuted))),
              ]),
            ])),
          ]),
        ),
      ]),
    );
  }

  // ─── Customer ────────────────────────────────────────────────────────────
  Widget _buildCustomerCard() {
    return _card('Pelanggan', Row(children: [
      InitialsAvatar(name: _o.customer.name, size: 42),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_o.customer.name, style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        Text(_o.customer.phone, style: GoogleFonts.inter(
            fontSize: 12, color: AppColors.textMuted)),
        Row(children: [
          const Icon(Icons.location_on_outlined, size: 11, color: AppColors.textMuted),
          const SizedBox(width: 2),
          Expanded(child: Text(_o.customer.area, style: GoogleFonts.inter(
              fontSize: 11, color: AppColors.textMuted))),
        ]),
      ])),
    ]));
  }

  // ─── Services ────────────────────────────────────────────────────────────
  Widget _buildServicesCard() {
    return _card('Rincian Layanan', Column(children: [
      ..._o.services.map((s) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.cleaning_services_rounded,
                color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark)),
            Text('${s.qty}× layanan', style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textMuted)),
          ])),
          Text(_fmt(s.subtotal), style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        ]),
      )),
      Container(height: 1, color: AppColors.border),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Subtotal', style: GoogleFonts.inter(
            fontSize: 13, color: AppColors.textMuted)),
        Text(_fmt(_o.total), style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
      ]),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('PPN (11%)', style: GoogleFonts.inter(
            fontSize: 13, color: AppColors.textMuted)),
        Text(_fmt((_o.total * 0.11).round()), style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
      ]),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Divider(height: 1, color: AppColors.border),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Total Pembayaran', style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        Text(_fmt((_o.total * 1.11).round()), style: GoogleFonts.inter(
            fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
      ]),
    ]));
  }

  Widget _buildPaymentInfo() {
    return _card('Informasi Pembayaran', Column(children: [
      _infoRow('Metode Bayar',
          _o.paymentMethod == '-' 
            ? 'Belum dipilih' 
            : _o.paymentMethod.replaceAll('_', ' ').split(' ').map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '').join(' '),
          icon: Icons.payment_rounded),
      const SizedBox(height: 10),
      Container(height: 1, color: AppColors.border),
      const SizedBox(height: 10),
      _infoRow(
        'Status Pembayaran',
        _isCancelled ? 'Dibatalkan' : _isPaid ? 'Lunas' : _isPending ? 'Menunggu Approval' : 'Belum Lunas',
        icon: _isCancelled
            ? Icons.cancel_rounded
            : _isPaid ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
        valueColor: _isCancelled
            ? AppColors.error
            : _isPaid ? AppColors.statusDone : _isPending ? AppColors.statusPending : AppColors.primary,
      ),
      if (_o.cleaners.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(height: 1, color: AppColors.border),
        const SizedBox(height: 10),
        _infoRow('Petugas Kebersihan', _o.cleaners.map((c) => c.name).join(', '), icon: Icons.person_rounded),
      ],
    ]));
  }

  // ─── Cancel reason ───────────────────────────────────────────────────────
  Widget _buildCancelCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.info_outline_rounded, color: AppColors.error, size: 14),
          ),
          const SizedBox(width: 8),
          Text('Alasan Pembatalan', style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.error)),
        ]),
        const SizedBox(height: 10),
        Text(_o.cancelReason!, style: GoogleFonts.inter(
            fontSize: 13, color: const Color(0xFF7A2020), height: 1.5)),
      ]),
    );
  }

  // ─── Proof card ──────────────────────────────────────────────────────────
  Widget _buildProofCard() {
    return _card('Bukti Pembayaran', Row(children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: AppColors.statusDoneBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.receipt_long_rounded,
            color: AppColors.statusDone, size: 24),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_o.paymentProof!, style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        Text('Terverifikasi · Tersimpan', style: GoogleFonts.inter(
            fontSize: 11, color: AppColors.statusDone)),
      ])),
      const Icon(Icons.check_circle_rounded, color: AppColors.statusDone, size: 20),
    ]));
  }

  // ─── STICKY BOTTOM BAR ──────────────────────────────────────────────────
  Widget _buildBottomBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Primary CTA — Pay
        GestureDetector(
          onTap: () => _showPaymentSheet(context),
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF0070CC)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.payments_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Column(mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Upload Bukti Bayar', style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(_fmt((_o.total * 1.11).round()), style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.white.withOpacity(0.8))),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        // Secondary — Cancel
        GestureDetector(
          onTap: () => _showCancelSheet(context),
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.error.withOpacity(0.5)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.cancel_outlined, size: 18, color: AppColors.error),
              const SizedBox(width: 8),
              Text('Upload Bukti Cancel', style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ─── PAYMENT SHEET ──────────────────────────────────────────────────────
  void _showPaymentSheet(BuildContext context) {
    final noteCtrl = TextEditingController();
    final diskonCtrl = TextEditingController();
    final ppnCtrl = TextEditingController(text: '11');
    File? selectedProof;
    bool isSubmitting = false;
    String? errorMsg;
    final ImagePicker picker = ImagePicker();
    final methods = [
      {'id': 'Transfer BCA', 'icon': Icons.account_balance_rounded, 'desc': 'BCA 8640679949 a.n KLINKLIN INDONESIA GROUP'},
      {'id': 'Transfer Mandiri', 'icon': Icons.account_balance_rounded, 'desc': 'Mandiri 1780022255554 a.n KLINKLIN INDONESIA GROUP'},
      {'id': 'QRIS', 'icon': Icons.qr_code_scanner_rounded, 'desc': 'Scan QR di kasir'},
      {'id': 'Tunai', 'icon': Icons.payments_rounded, 'desc': 'Bayar langsung ke petugas'},
    ];
    String selectedMethod = 'Transfer BCA';
    if (_o.paymentMethod.toLowerCase().contains('mandiri')) selectedMethod = 'Transfer Mandiri';
    else if (_o.paymentMethod.toLowerCase().contains('qris')) selectedMethod = 'QRIS';
    else if (_o.paymentMethod.toLowerCase().contains('cash') || _o.paymentMethod.toLowerCase().contains('tunai')) selectedMethod = 'Tunai';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          int diskonPersen = int.tryParse(diskonCtrl.text) ?? 0;
          int ppnPersen = int.tryParse(ppnCtrl.text) ?? 0;
          int diskonNominal = (_o.total * diskonPersen / 100).round();
          int setelahDiskon = _o.total - diskonNominal;
          int ppnNominal = (setelahDiskon * ppnPersen / 100).round();
          int totalAkhir = setelahDiskon + ppnNominal;
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2)),
                    )),
                    const SizedBox(height: 20),

                    // Header
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.payments_rounded,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Upload Bukti Bayar', style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.bold,
                            color: AppColors.textDark)),
                        Text(_o.id, style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.textMuted)),
                      ])),
                    ]),
                    const SizedBox(height: 4),

                    // Amount banner
                    Container(
                      margin: const EdgeInsets.only(top: 16, bottom: 20),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.08),
                            AppColors.primary.withOpacity(0.03)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.15)),
                      ),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                        Text('Total yang harus dibayar',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.textMuted)),
                        Text(_fmt(totalAkhir),
                            style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary)),
                      ]),
                    ),

                    // Diskon dan PPN
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Diskon (%)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: diskonCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setModal(() {}),
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                            decoration: InputDecoration(
                              hintText: '0',
                              filled: true,
                              fillColor: AppColors.background,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('PPN (%)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: ppnCtrl,
                            keyboardType: TextInputType.number,
                            readOnly: true,
                            onChanged: (_) => setModal(() {}),
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                            decoration: InputDecoration(
                              hintText: '0',
                              filled: true,
                              fillColor: AppColors.surface,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                            ),
                          ),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // Method selector
                    Text('Metode Pembayaran', style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                    const SizedBox(height: 10),
                    ...methods.map((m) {
                      final id = m['id'] as String;
                      final icon = m['icon'] as IconData;
                      final desc = m['desc'] as String;
                      final sel = selectedMethod == id;
                      return GestureDetector(
                        onTap: () => setModal(() => selectedMethod = id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.primary.withOpacity(0.06)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: sel
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Row(children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppColors.primary.withOpacity(0.12)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon,
                                  color: sel
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                  size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(id, style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: sel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: sel
                                      ? AppColors.primary
                                      : AppColors.textDark)),
                              Text(desc, style: GoogleFonts.inter(
                                  fontSize: 11, color: AppColors.textMuted)),
                            ])),
                            if (sel)
                              Container(
                                width: 22, height: 22,
                                decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 14),
                              )
                            else
                              Container(
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border, width: 1.5),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ]),
                        ),
                      );
                    }),

                    const SizedBox(height: 16),

                    // Note (optional)
                    Text('Catatan (opsional)', style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 2,
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: 'cth. Ref transfer: 12345, sudah konfirmasi ke admin...',
                        hintStyle: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Proof upload
                    Text('Bukti Pembayaran', style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: isSubmitting ? null : () async {
                        final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                        if (picked != null) {
                          setModal(() {
                            selectedProof = File(picked.path);
                          });
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: selectedProof != null
                              ? AppColors.statusDoneBg
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selectedProof != null
                                ? AppColors.statusDone
                                : AppColors.border,
                            width: selectedProof != null ? 1.5 : 1,
                            // Dashed via custom painter below
                          ),
                        ),
                        child: selectedProof != null
                                ? Row(children: [
                                    Container(
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(
                                        color: AppColors.statusDoneBg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.image_rounded,
                                          color: AppColors.statusDone, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                      Text(selectedProof!.path.split('/').last, style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.statusDone), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text('Tap untuk ganti foto',
                                          style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: AppColors.textMuted)),
                                    ])),
                                    const Icon(Icons.check_circle_rounded,
                                        color: AppColors.statusDone, size: 22),
                                  ])
                                : Column(children: [
                                    Container(
                                      width: 48, height: 48,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceBlue,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.add_photo_alternate_rounded,
                                          color: AppColors.primary, size: 24),
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Upload Bukti Pembayaran',
                                        style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary)),
                                    const SizedBox(height: 2),
                                    Text('JPG, PNG, max 5MB',
                                        style: GoogleFonts.inter(
                                            fontSize: 11, color: AppColors.textMuted)),
                                  ]),
                      ),
                    ),

                    if (errorMsg != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(errorMsg!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.error))),
                        ]),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Confirm button
                    GestureDetector(
                      onTap: isSubmitting ? null : () async {
                        if (selectedProof == null) {
                          setModal(() => errorMsg = 'Harap unggah bukti pembayaran');
                          return;
                        }
                        setModal(() {
                          isSubmitting = true;
                          errorMsg = null;
                        });
                        try {
                          final svc = PaymentService();
                          
                          String apiMethod;
                          if (selectedMethod == 'Transfer BCA' || selectedMethod == 'Transfer Mandiri') {
                            apiMethod = 'transfer';
                          } else if (selectedMethod == 'QRIS') {
                            apiMethod = 'qris';
                          } else {
                            apiMethod = 'cash';
                          }

                          await svc.submitPayment(
                            orderId: _o.id,
                            metodePembayaran: apiMethod,
                            diskonPersen: diskonPersen,
                            ppn: ppnPersen,
                            totalTagihan: _o.total,
                            totalSetelahDiskon: setelahDiskon,
                            totalAkhir: totalAkhir,
                            buktiTransfer: selectedProof!,
                          );
                          if (!context.mounted) return;
                          
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text('Pembayaran ${_o.id} berhasil dikirim!', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                              ]),
                              backgroundColor: AppColors.statusDone,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                          Navigator.pop(context, true);
                        } catch (e) {
                          setModal(() {
                            isSubmitting = false;
                            errorMsg = e.toString().replaceFirst('Exception: ', '');
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, Color(0xFF0070CC)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: isSubmitting 
                           ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
                           : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text('Konfirmasi & Kirim · ${_fmt(totalAkhir)}',
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ]),
                      ),
                    ),
                  ]),
            ),
          );
        },
      ),
    );
  }

  // ─── CANCEL SHEET ───────────────────────────────────────────────────────
  void _showCancelSheet(BuildContext context) {
    final reasonCtrl = TextEditingController();
    bool uploading = false;
    File? proofFile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Drag handle
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 20),

                // Warning header
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.error.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: AppColors.error, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Upload Bukti Cancel', style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.bold,
                          color: AppColors.error)),
                      Text('${_o.id} · ${_fmt((_o.total * 1.11).round())}',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.textMuted)),
                    ])),
                  ]),
                ),

                const SizedBox(height: 20),

                // Reason input
                Text('Alasan Pembatalan', style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
                const SizedBox(height: 4),
                Text('Wajib diisi · akan tercatat di riwayat pesanan',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  onChanged: (_) => setModal(() {}),
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'cth. Pelanggan reschedule ke minggu depan...',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.error.withOpacity(0.6))),
                  ),
                ),

                const SizedBox(height: 16),

                // Proof (wajib)
                Row(children: [
                  Text('Bukti Pembatalan', style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.textDark)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('wajib', style: GoogleFonts.inter(
                        fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 60,
                      maxWidth: 1024,
                      maxHeight: 1024,
                    );
                    if (pickedFile != null) {
                      setModal(() {
                        proofFile = File(pickedFile.path);
                      });
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: proofFile != null ? const Color(0xFFFFF1F1) : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: proofFile != null
                              ? AppColors.error.withOpacity(0.3)
                              : AppColors.border),
                    ),
                    child: uploading
                        ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: AppColors.error, strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Text('Memproses...',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: AppColors.textMuted)),
                          ])
                        : proofFile != null
                            ? Row(children: [
                                const Icon(Icons.image_rounded,
                                    color: AppColors.error, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text(proofFile!.path.split('/').last,
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.error))),
                                const Icon(Icons.close_rounded,
                                    color: AppColors.textMuted, size: 16),
                              ])
                            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const Icon(Icons.add_photo_alternate_rounded,
                                    color: AppColors.textMuted, size: 18),
                                const SizedBox(width: 8),
                                Text('Upload foto bukti (wajib)',
                                    style: GoogleFonts.inter(
                                        fontSize: 12, color: AppColors.textMuted)),
                              ]),
                  ),
                ),

                const SizedBox(height: 24),

                // Confirm button — disabled until reason filled
                Builder(builder: (bCtx) {
                  final hasReason = reasonCtrl.text.trim().isNotEmpty && proofFile != null;
                  return GestureDetector(
                    onTap: hasReason && !uploading
                        ? () async {
                            setModal(() => uploading = true);
                            try {
                              await OrderService().cancelOrder(_o.id, reasonCtrl.text.trim(), proofFile!);
                              if (!context.mounted) return;
                              Navigator.pop(ctx); // close modal
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(children: [
                                    const Icon(Icons.check_circle_rounded,
                                        color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Pesanan ${_o.id} berhasil dibatalkan.',
                                        style: GoogleFonts.inter(
                                            color: Colors.white, fontSize: 13)),
                                  ]),
                                  backgroundColor: AppColors.statusDone,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  margin: const EdgeInsets.all(16),
                                ),
                              );
                              Navigator.pop(context); // close screen and trigger loadData
                            } catch (e) {
                              setModal(() => uploading = false);
                              showDialog(
                                context: ctx,
                                builder: (dCtx) => AlertDialog(
                                  title: const Text('Gagal'),
                                  content: Text(e.toString().replaceFirst('Exception: ', '')),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dCtx),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: hasReason
                            ? AppColors.error
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.cancel_rounded,
                            color: hasReason
                                ? Colors.white
                                : AppColors.textMuted,
                            size: 18),
                        const SizedBox(width: 8),
                        Text('Konfirmasi Pembatalan',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: hasReason
                                    ? Colors.white
                                    : AppColors.textMuted)),
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Center(child: Text(
                  reasonCtrl.text.trim().isEmpty || proofFile == null
                      ? 'Lengkapi alasan dan foto bukti untuk membatalkan'
                      : 'Aksi ini tidak bisa dibatalkan setelah dikonfirmasi',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                )),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  Widget _card(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: AppColors.textMuted, letterSpacing: 0.8)),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _infoRow(String label, String value,
      {IconData? icon, Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon,
                size: 14,
                color: valueColor ?? AppColors.textMuted),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          flex: 2,
          child: Text(label, style: GoogleFonts.inter(
              fontSize: 12, color: AppColors.textMuted)),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(value, 
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textDark)),
        ),
      ],
    );
  }
}
