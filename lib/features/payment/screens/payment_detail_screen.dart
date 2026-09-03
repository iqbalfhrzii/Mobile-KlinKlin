import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_confirmation_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/payment_service.dart';
import '../../orders/services/order_service.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/data/order_model.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/image_compress_helper.dart';

class PaymentDetailScreen extends StatefulWidget {
  const PaymentDetailScreen({super.key, required this.order});
  final OrderModel order;

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  late OrderModel _o;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _o = widget.order;
  }

  Future<void> _refreshOrder() async {
    setState(() => _isLoading = true);
    try {
      final updatedOrder = await OrderService().fetchOrderDetail(_o.id);
      if (mounted) {
        setState(() {
          _o = updatedOrder;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memperbarui data: $e')));
      }
    }
  }

  String _fmt(int n) =>
      'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  bool get _isPaid {
    final ps = _o.paymentStatus.toLowerCase();
    final pSub = _o.pembayaran?.statusPembayaran.toLowerCase() ?? '';
    return ps == 'paid' || ps == 'approved' || ps == 'lunas' || pSub == 'approved' || pSub == 'paid';
  }

  bool get _isWaitingCancel => _o.status == OrderStatus.waitingCancelApproval;
  bool get _isPending =>
      _o.paymentStatus == 'pending' ||
      _o.status == OrderStatus.waitingPaymentApproval;
  bool get _isCancelled =>
      _o.paymentStatus == 'cancelled' ||
      _o.status == OrderStatus.cancelled ||
      _o.status == OrderStatus.waitingCancelApproval ||
      _o.statusUtamaLabel == 'Dibatalkan' ||
      _o.pembatalanId != null;

  bool get _canAct {
    if (_isWaitingCancel || _isCancelled) return false;
    if (_isPending) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // ── Sticky bottom action bar ──────────────────────────────────────
      bottomNavigationBar: _canAct ? _buildBottomBar(context) : null,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
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
                        if (_o.cleaners.isNotEmpty) ...[
                          _buildCleanersCard(),
                          const SizedBox(height: 12),
                        ],
                        _buildServicesCard(),
                        const SizedBox(height: 12),
                        _buildPaymentInfo(),
                        if (_o.cancelReason != null) ...[
                          const SizedBox(height: 12),
                          _buildCancelCard(),
                        ],
                        if (_o.hasUploadedTransferProof) ...[
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
      padding: EdgeInsets.fromLTRB(20, 52, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 16 : 20),
      child: Row(
        children: [
          HeaderBackButton(onTap: () => Navigator.pop(context, true)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detail Pembayaran',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _o.nomorPesanan,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(status: _o.status, order: _o),
        ],
      ),
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
    } else if (_o.paymentStatus == 'rejected') {
      accent = AppColors.error;
      statusText = 'Pembayaran Ditolak';
      statusIcon = Icons.error_outline_rounded;
    } else if (_isWaitingCancel) {
      accent = AppColors.error.withValues(alpha: 0.8);
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
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        children: [
          // Top colored strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: accent, size: 16),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          // Amount
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Tagihan',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Builder(
                        builder: (context) {
                          final int baseSubtotal = (_o.subtotal > 0)
                              ? _o.subtotal
                              : (_o.services.isNotEmpty
                                  ? _o.services.fold(0, (sum, s) => sum + s.subtotal)
                                  : _o.total);
                          final double diskonPersen =
                              _o.pembayaran?.diskonPersen ?? 0.0;
                          final int diskonValue =
                              (baseSubtotal * (diskonPersen / 100)).round();
                          final int totalSetelahDiskon = baseSubtotal - diskonValue;
                          final int ppnPersen =
                              _o.ppn ?? _o.pembayaran?.ppn ?? 0;
                          final int ppnValue =
                              (totalSetelahDiskon * (ppnPersen / 100)).round();
                          final int totalAkhir = totalSetelahDiskon + ppnValue;
                          return Text(
                            _fmt(totalAkhir),
                            style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 11,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _o.schedule,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
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
        ],
      ),
    );
  }

  // ─── Customer ────────────────────────────────────────────────────────────
  Widget _buildCustomerCard() {
    return _card(
      'Pelanggan',
      Row(
        children: [
          InitialsAvatar(name: _o.customer.name, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _o.customer.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  _o.customer.phone,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 11,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        _o.customer.area,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Cleaners ────────────────────────────────────────────────────────────
  Widget _buildCleanersCard() {
    return _card(
      'Petugas Kebersihan',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isCancelled && _o.cleaners.length > 1) ...[
            InkWell(
              onTap: () {
                showModalBottomSheet(
      useSafeArea: true,
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _AddBonusSheet(
                    order: _o,
                    initialCleaner: null,
                    onBonusAdded: () {
                      _refreshOrder();
                    },
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.group_add_rounded,
                      size: 18,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Beri Bonus Sekaligus (${_o.cleaners.length} Cleaner)',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          ..._o.cleaners.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.cleaning_services_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (c.totalBonus > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Total Bonus: ${_fmt(c.totalBonus)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.statusDone,
                            ),
                          ),
                          ...c.bonuses.map(
                            (b) => Text(
                              '• ${b.jenisBonus}: ${_fmt(b.nominal)}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!_isCancelled)
                    InkWell(
                      onTap: () {
                        showModalBottomSheet(
      useSafeArea: true,
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _AddBonusSheet(
                            order: _o,
                            initialCleaner: c,
                            onBonusAdded: () {
                              _refreshOrder();
                            },
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add_circle_outline_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Atur Bonus',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
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

  // ─── Services ────────────────────────────────────────────────────────────
  Widget _buildServicesCard() {
    return _card(
      'Rincian Layanan',
      Column(
        children: [
          ..._o.services.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.cleaning_services_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          '${s.qty}× layanan',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _fmt(s.subtotal),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final int baseSubtotal = (_o.subtotal > 0)
                  ? _o.subtotal
                  : (_o.services.isNotEmpty
                      ? _o.services.fold(0, (sum, s) => sum + s.subtotal)
                      : _o.total);
              final double diskonPersen = _o.pembayaran?.diskonPersen ?? 0.0;
              final int diskonValue = (baseSubtotal * (diskonPersen / 100)).round();
              final int totalSetelahDiskon = baseSubtotal - diskonValue;
              final int ppnPersen = _o.ppn ?? _o.pembayaran?.ppn ?? 0;
              final int ppnValue = (totalSetelahDiskon * (ppnPersen / 100))
                  .round();
              final int totalAkhir = totalSetelahDiskon + ppnValue;

              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        _fmt(baseSubtotal),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  if (diskonValue > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Diskon ${diskonPersen == diskonPersen.toInt() ? diskonPersen.toInt() : diskonPersen}%',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          '-${_fmt(diskonValue)}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PPN ($ppnPersen%)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        _fmt(ppnValue),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: AppColors.border),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Pembayaran',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        _fmt(totalAkhir),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo() {
    return _card(
      'Informasi Pembayaran',
      Column(
        children: [
          _infoRow(
            'Metode Bayar',
            _o.paymentMethod == '-'
                ? 'Belum dipilih'
                : _o.paymentMethod
                      .replaceAll('_', ' ')
                      .split(' ')
                      .map(
                        (s) => s.isNotEmpty
                            ? '${s[0].toUpperCase()}${s.substring(1)}'
                            : '',
                      )
                      .join(' '),
            icon: Icons.payment_rounded,
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          _infoRow(
            'Status Pembayaran',
            _isCancelled
                ? 'Dibatalkan'
                : _isPaid
                ? 'Lunas'
                : _isPending
                ? 'Pending'
                : 'Belum Lunas',
            icon: _isCancelled
                ? Icons.cancel_rounded
                : _isPaid
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            valueColor: _isCancelled
                ? AppColors.error
                : _isPaid
                ? AppColors.statusDone
                : _isPending
                ? AppColors.statusPending
                : AppColors.primary,
          ),
          if (_o.cleaners.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            _infoRow(
              'Petugas Kebersihan',
              _o.cleaners.map((c) => c.name).join(', '),
              icon: Icons.person_rounded,
            ),
          ],
        ],
      ),
    );
  }

  // ─── Cancel reason ───────────────────────────────────────────────────────
  Widget _buildCancelCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.error,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Alasan Pembatalan',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _o.cancelReason!,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF7A2020),
              height: 1.5,
            ),
          ),
          if (_o.cancelProof != null && _o.cancelProof!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: AppColors.error.withValues(alpha: 0.2), thickness: 1),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _showImageDialog(context, _o.cancelProof!),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.image_outlined,
                        color: AppColors.error,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lihat Bukti Pembatalan',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ketuk untuk melihat foto',
                            style: GoogleFonts.inter(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.textMuted,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Proof card ──────────────────────────────────────────────────────────
  // ─── Proof card ──────────────────────────────────────────────────────────
  Widget _buildProofCard() {
    final urls = _o.proofUrls;
    final bool isApproved = _isPaid;
    final bool isPending = _isPending || _o.pembayaran?.statusPembayaran.toLowerCase() == 'pending';
    final Color statusColor = isApproved
        ? AppColors.statusDone
        : (isPending ? const Color(0xFFD97706) : AppColors.error);
    final Color statusBg = isApproved
        ? AppColors.statusDoneBg
        : (isPending ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2));
    final IconData statusIcon = isApproved
        ? Icons.check_circle_rounded
        : (isPending ? Icons.hourglass_top_rounded : Icons.error_outline_rounded);
    final String statusLabel = isApproved
        ? 'Terverifikasi · Disetujui Finance'
        : (isPending ? 'Pending · Menunggu Verifikasi Finance' : 'Ditolak oleh Finance');

    return GestureDetector(
      onTap: () {
        if (urls.isNotEmpty) {
          _showImageDialog(context, urls);
        } else if (_o.paymentProof != null && _o.paymentProof!.isNotEmpty) {
          _showImageDialog(context, _o.paymentProof!);
        }
      },
      child: _card(
        'Bukti Pembayaran',
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: statusColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    urls.length > 1 ? 'Lihat Bukti Pembayaran (${urls.length} Foto)' : 'Lihat Bukti Pembayaran',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              statusIcon,
              color: statusColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showImageDialog(BuildContext context, dynamic imageSource) {
    List<String> urls = [];
    if (imageSource is List<String>) {
      urls = imageSource;
    } else if (imageSource is String) {
      if (imageSource.contains(',')) {
        urls = imageSource.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      } else {
        urls = [imageSource.trim()];
      }
    }

    if (urls.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) {
        int currentIndex = 0;
        final pageCtrl = PageController();
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.75,
                    width: double.infinity,
                    child: PageView.builder(
                      controller: pageCtrl,
                      itemCount: urls.length,
                      onPageChanged: (idx) {
                        setDialogState(() => currentIndex = idx);
                      },
                      itemBuilder: (context, idx) {
                        final img = urls[idx];
                        final fullUrl = img.startsWith('http')
                            ? img
                            : '${ApiClient.baseUrl.replaceAll('/api', '')}/storage/${img.replaceFirst(RegExp(r'^/?storage/'), '')}';
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: InteractiveViewer(
                            child: Image.network(
                              fullUrl,
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
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.broken_image,
                                      color: AppColors.textMuted,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Gagal memuat gambar',
                                      style: GoogleFonts.inter(color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (urls.length > 1)
                    Positioned(
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Foto ${currentIndex + 1} dari ${urls.length}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showRequestEditDialog() {
    if (_o.hasPendingEditRequest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pengajuan edit pembayaran sudah dikirim dan sedang menunggu persetujuan Finance.',
          ),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }

    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: Colors.white,
        elevation: 10,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFDE68A),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: Color(0xFFD97706),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                'Ajukan Edit Pembayaran',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              // Subtitle
              Text(
                'Pembayaran ini sudah diverifikasi & disetujui. Masukkan alasan pengajuan edit untuk ditinjau oleh Finance:',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Input Area
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: 'Contoh: Maaf ada kesalahan nominal bayar / bukti transfer salah...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.white,
                      ),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final reason = reasonCtrl.text.trim();
                        if (reason.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Alasan pengajuan edit harus diisi.')),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        setState(() => _isLoading = true);
                        try {
                          await OrderService().submitPengajuanEdit(_o.id, reason);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Pengajuan edit pembayaran berhasil dikirim ke Finance!'),
                              backgroundColor: Color(0xFF059669),
                            ),
                          );
                          _refreshOrder();
                        } catch (e) {
                          if (!mounted) return;
                          setState(() => _isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: Text(
                        'Kirim Pengajuan',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── STICKY BOTTOM BAR ──────────────────────────────────────────────────
  Widget _buildBottomBar(BuildContext context) {
    // If payment is already approved / paid, CS cannot directly edit or cancel.
    // They can submit an edit request to Finance for approval.
    if (_isPaid) {
      if (_o.hasPendingEditRequest) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.of(context).padding.bottom + 12,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Pengajuan Edit Pending (Menunggu Finance)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFD97706),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        child: GestureDetector(
          onTap: () => _showRequestEditDialog(),
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD97706), Color(0xFFB45309)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD97706).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.edit_note_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ajukan Edit ke Finance',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Pembayaran telah disetujui, edit butuh persetujuan',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isRejected = _o.paymentStatus == 'rejected';
    final isPendingPayment = _isPending || _o.pembayaran?.statusPembayaran.toLowerCase() == 'pending' || _o.hasUploadedTransferProof;
    final buttonLabel = isRejected
        ? 'Revisi Bukti Bayar'
        : (isPendingPayment ? 'Perbarui Bukti Bayar' : 'Upload Bukti Bayar');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPendingPayment) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.hourglass_top_rounded,
                    color: Color(0xFFD97706),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bukti Pembayaran Sudah Diunggah',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                        Text(
                          'Status: Pending (Menunggu Verifikasi Finance)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Primary CTA — Pay
          GestureDetector(
            onTap: () => _showPpnSelectionModal(context),
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
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.payments_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        buttonLabel,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _fmt(_o.total),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                color: AppColors.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cancel_outlined,
                    size: 18,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Upload Bukti Cancel',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
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

  int get _serviceSubtotal {
    if (_o.subtotal > 0) return _o.subtotal;
    if (_o.services.isNotEmpty) {
      final s = _o.services.fold(0, (sum, item) => sum + item.subtotal);
      if (s > 0) return s;
    }
    // Jika subtotal belum terisi dan order sudah ada PPN, kurangi PPN untuk mendapatkan DPP
    final ppnRate = _o.ppn ?? _o.pembayaran?.ppn ?? (_o.isWajibPpn ? 11 : 0);
    if (ppnRate > 0 && _o.total > 0) {
      return (_o.total / (1 + (ppnRate / 100.0))).round();
    }
    return _o.total;
  }

  // ─── PPN SELECTION MODAL (Matching Web CS PesananDetailPage) ───────────
  void _showPpnSelectionModal(BuildContext context) {
    final int rawSubtotal = _serviceSubtotal;
    final double diskonPersen = _o.pembayaran?.diskonPersen ??
        (_o.discount != null && _o.subtotal > 0
            ? (_o.discount! / _o.subtotal * 100)
            : 0.0);
    final int diskonNominal = (rawSubtotal * diskonPersen / 100).round();
    final int subtotal = rawSubtotal - diskonNominal;

    final int nominalPpn = (subtotal * 0.11).round();
    final int totalDenganPpn = subtotal + nominalPpn;
    final int totalTanpaPpn = subtotal;
    final bool isWajibPpn = _o.isWajibPpn;

    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pilih Opsi PPN',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(ctx),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 20, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Apakah pembayaran ini menggunakan PPN (11%) atau tidak?',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: const Color(0xFF64748B),
              ),
            ),
            if (_o.hasUploadedTransferProof || _o.pembayaran?.statusPembayaran.toLowerCase() == 'pending') ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bukti pembayaran sudah pernah diunggah (Status: Pending Menunggu Verifikasi Finance). Mengunggah kembali akan memperbarui data bukti sebelumnya.',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF92400E),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Card 1: Pakai PPN
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _showPaymentSheet(context, initialPpn: true);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isWajibPpn ? const Color(0xFFF0FDF4) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isWajibPpn ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                    width: isWajibPpn ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Pakai PPN (11%)',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        if (isWajibPpn)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Default Cabang',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        Text(_fmt(subtotal), style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('PPN (11%)', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        Text('+${_fmt(nominalPpn)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A))),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                        Text(_fmt(totalDenganPpn), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF16A34A))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Card 2: Tanpa PPN
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _showPaymentSheet(context, initialPpn: false);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: !isWajibPpn ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                    width: !isWajibPpn ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFF64748B), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Tanpa PPN',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        if (!isWajibPpn)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Default Cabang',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        Text(_fmt(subtotal), style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('PPN (11%)', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        Text('+Rp 0', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                        Text(_fmt(totalTanpaPpn), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── PAYMENT SHEET ──────────────────────────────────────────────────────
  void _showPaymentSheet(BuildContext context, {bool? initialPpn}) {
    final noteCtrl = TextEditingController();
    final double initDiskon = _o.diskonPersen;
    final diskonCtrl = TextEditingController(
      text: initDiskon > 0 ? (initDiskon == initDiskon.toInt() ? initDiskon.toInt().toString() : initDiskon.toString()) : '',
    );
    final bool isWajibPpn = _o.isWajibPpn;
    bool applyPpn = initialPpn ?? isWajibPpn;
    bool applyPph = (_o.pph ?? _o.pembayaran?.pph ?? 0) > 0;
    List<File> selectedProofs = [];
    bool isSubmitting = false;
    String? errorMsg;
    final ImagePicker picker = ImagePicker();
    final methods = [
      {
        'id': 'Transfer BCA',
        'icon': Icons.account_balance_rounded,
        'desc': 'BCA 8640679949 a.n KLINKLIN INDONESIA GROUP',
      },
      {
        'id': 'Transfer Mandiri',
        'icon': Icons.account_balance_rounded,
        'desc': 'Mandiri 1780022255554 a.n KLINKLIN INDONESIA GROUP',
      },
      {
        'id': 'QRIS',
        'icon': Icons.qr_code_scanner_rounded,
        'desc': 'Scan QR di kasir',
      },
      {
        'id': 'Tunai',
        'icon': Icons.payments_rounded,
        'desc': 'Bayar langsung ke petugas',
      },
    ];
    String selectedMethod = 'Transfer BCA';
    if (_o.paymentMethod.toLowerCase().contains('mandiri')) {
      selectedMethod = 'Transfer Mandiri';
    } else if (_o.paymentMethod.toLowerCase().contains('qris')) {
      selectedMethod = 'QRIS';
    } else if (_o.paymentMethod.toLowerCase().contains('cash') ||
        _o.paymentMethod.toLowerCase().contains('tunai')) {
      selectedMethod = 'Tunai';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final int baseSubtotal = _serviceSubtotal;
          int diskonPersen = int.tryParse(diskonCtrl.text) ?? 0;
          int ppnPersen = applyPpn ? 11 : 0;
          int pphPersen = applyPph ? 2 : 0;
          int diskonNominal = (baseSubtotal * diskonPersen / 100).round();
          int setelahDiskon = baseSubtotal - diskonNominal;
          int ppnNominal = (setelahDiskon * ppnPersen / 100).round();
          int pphNominal = (setelahDiskon * pphPersen / 100).round();
          int totalAkhir = setelahDiskon + ppnNominal - pphNominal;
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.payments_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upload Bukti Bayar',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              _o.nomorPesanan,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  if (_o.hasUploadedTransferProof || _o.pembayaran?.statusPembayaran.toLowerCase() == 'pending') ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bukti pembayaran sebelumnya sudah diunggah (Status: Pending). Mengunggah bukti baru akan mengganti bukti transfer sebelumnya.',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: const Color(0xFF92400E),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Amount banner
                  Container(
                    margin: const EdgeInsets.only(top: 16, bottom: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.08),
                          AppColors.primary.withValues(alpha: 0.03),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total yang harus dibayar',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          _fmt(totalAkhir),
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Diskon dan PPN
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Diskon (%)',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: diskonCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setModal(() {}),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textDark,
                              ),
                              decoration: InputDecoration(
                                hintText: '0',
                                filled: true,
                                fillColor: AppColors.background,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pajak PPN (11%)',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Pilihan apakah mau bayar sesuai PPN atau tanpa PPN
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.all(3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        setModal(() => applyPpn = true);
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        decoration: BoxDecoration(
                                          color: applyPpn ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: applyPpn
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.06),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Pakai PPN',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: applyPpn ? FontWeight.bold : FontWeight.w500,
                                              color: applyPpn ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        setModal(() => applyPpn = false);
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        decoration: BoxDecoration(
                                          color: !applyPpn ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: !applyPpn
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.06),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Tanpa PPN',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: !applyPpn ? FontWeight.bold : FontWeight.w500,
                                              color: !applyPpn ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Checkbox PPN (Terkunci, nilai otomatis mengikuti pilihan)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: applyPpn
                                    ? const Color(0xFFF0FDF4)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: applyPpn
                                      ? const Color(0xFFBBF7D0)
                                      : const Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: Checkbox(
                                      value: applyPpn,
                                      onChanged: null, // Terkunci! Hanya diatur lewat tombol pilihan di atas
                                      activeColor: const Color(0xFF16A34A),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text(
                                          applyPpn ? 'PPN 11% Aktif' : 'PPN Nonaktif',
                                          style: GoogleFonts.inter(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: applyPpn
                                                ? const Color(0xFF15803D)
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                        const Spacer(),
                                        const Icon(
                                          Icons.lock_rounded,
                                          size: 11,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () {
                                setModal(() {
                                  applyPph = !applyPph;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: applyPph
                                        ? AppColors.primary
                                        : AppColors.border,
                                    width: applyPph ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Checkbox(
                                        value: applyPph,
                                        onChanged: (val) {
                                          if (val != null) {
                                            setModal(() {
                                              applyPph = val;
                                            });
                                          }
                                        },
                                        activeColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'PPh (2%)',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textDark,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Method selector
                  Text(
                    'Metode Pembayaran',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
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
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.primary.withValues(alpha: 0.06)
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: sel ? AppColors.primary : AppColors.border,
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppColors.primary.withValues(alpha: 0.12)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                icon,
                                color: sel
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    id,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: sel
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: sel
                                          ? AppColors.primary
                                          : AppColors.textDark,
                                    ),
                                  ),
                                  Text(
                                    desc,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (sel)
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              )
                            else
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppColors.border,
                                    width: 1.5,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Note (optional)
                  Text(
                    'Catatan (opsional)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'cth. Ref transfer: 12345, sudah konfirmasi CS...',
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Proof upload
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bukti Pembayaran (Maks. 2 Foto)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: selectedProofs.isNotEmpty ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selectedProofs.isNotEmpty ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          '${selectedProofs.length}/2 Foto',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: selectedProofs.isNotEmpty ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // List of uploaded proofs
                  if (selectedProofs.isNotEmpty) ...[
                    ...selectedProofs.asMap().entries.map((entry) {
                      final index = entry.key;
                      final file = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.statusDoneBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.statusDone.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                file,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Foto Bukti ${index + 1}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  Text(
                                    file.path.split(r'/').last.split(r'\').last,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () {
                                      setModal(() {
                                        selectedProofs.removeAt(index);
                                      });
                                    },
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.error,
                                size: 20,
                              ),
                              tooltip: 'Hapus foto',
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  // Add button / Box
                  if (selectedProofs.length < 2)
                    GestureDetector(
                      onTap: isSubmitting
                          ? null
                          : () async {
                              final picked = await picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (picked != null) {
                                final compressed = await ImageCompressHelper.compressXFileIfNeeded(picked);
                                if (compressed != null) {
                                  setModal(() {
                                    selectedProofs.add(compressed);
                                    errorMsg = null;
                                  });
                                }
                              }
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          vertical: selectedProofs.isEmpty ? 20 : 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.border,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceBlue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.add_photo_alternate_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedProofs.isEmpty
                                      ? 'Upload Bukti Pembayaran (Min. 1 Foto)'
                                      : '+ Tambah Foto Bukti Kedua (Opsional)',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Text(
                                  'Bisa upload hingga 2 foto (JPG, PNG, max 5MB)',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMsg!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    const SizedBox(height: 16),
                  ],

                  // Confirm button
                  GestureDetector(
                    onTap: isSubmitting
                        ? null
                        : () async {
                            if (selectedProofs.isEmpty) {
                              setModal(
                                () =>
                                    errorMsg = 'Harap unggah minimal 1 foto bukti pembayaran',
                              );
                              return;
                            }

                            // Alert Konfirmasi Pembayaran (Sesuai Web Custom Confirm Modal)
                            final confirmed = await AppConfirmationDialog.show(
                              ctx,
                              title: 'Konfirmasi Pembayaran',
                              message: 'Apakah Anda yakin dengan pilihan ${applyPpn ? "PPN (11%)" : "Tanpa PPN"} dan Metode Pembayaran ($selectedMethod) ini?',
                              confirmText: 'Ya, Yakin',
                              cancelText: 'Kembali',
                              type: ConfirmationDialogType.info,
                            );
                            if (confirmed != true) return;

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
                                usePph: applyPph,
                                totalTagihan: baseSubtotal,
                                totalSetelahDiskon: setelahDiskon,
                                totalAkhir: totalAkhir,
                                buktiTransfer: selectedProofs,
                              );
                              if (!context.mounted) return;

                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Pembayaran ${_o.nomorPesanan} berhasil dikirim!',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: AppColors.statusDone,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  margin: const EdgeInsets.all(16),
                                ),
                              );
                              Navigator.pop(context, true);
                            } catch (e) {
                              setModal(() {
                                isSubmitting = false;
                                errorMsg = e.toString().replaceFirst(
                                  'Exception: ',
                                  '',
                                );
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
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: isSubmitting
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Konfirmasi & Kirim · ${_fmt(totalAkhir)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
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
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Warning header
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.error,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload Bukti Cancel',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                ),
                              ),
                              Text(
                                '${_o.nomorPesanan} · ${_fmt(_o.total)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Reason input
                  Text(
                    'Alasan Pembatalan',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Wajib diisi · akan tercatat di riwayat pesanan',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    onChanged: (_) => setModal(() {}),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                    decoration: InputDecoration(
                      hintText: 'cth. Pelanggan reschedule ke minggu depan...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Proof (wajib)
                  Row(
                    children: [
                      Text(
                        'Bukti Pembatalan',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'wajib',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final pickedFile = await picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (pickedFile != null) {
                        final compressed = await ImageCompressHelper.compressXFileIfNeeded(pickedFile);
                        if (compressed != null) {
                          setModal(() {
                            proofFile = compressed;
                          });
                        }
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: proofFile != null
                            ? const Color(0xFFFFF1F1)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: proofFile != null
                              ? AppColors.error.withValues(alpha: 0.3)
                              : AppColors.border,
                        ),
                      ),
                      child: uploading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: AppColors.error,
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Memproses...',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            )
                          : proofFile != null
                          ? Row(
                              children: [
                                const Icon(
                                  Icons.image_rounded,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    proofFile!.path.split('/').last,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.textMuted,
                                  size: 16,
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_photo_alternate_rounded,
                                  color: AppColors.textMuted,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Upload foto bukti (wajib)',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Confirm button — disabled until reason filled
                  Builder(
                    builder: (bCtx) {
                      final hasReason =
                          reasonCtrl.text.trim().isNotEmpty &&
                          proofFile != null;
                      return GestureDetector(
                        onTap: hasReason && !uploading
                            ? () async {
                                setModal(() => uploading = true);
                                try {
                                  await OrderService().cancelOrder(
                                    _o.id,
                                    reasonCtrl.text.trim(),
                                    proofFile!,
                                  );
                                  if (!context.mounted) return;
                                  Navigator.pop(ctx); // close modal
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Pesanan ${_o.nomorPesanan} berhasil dibatalkan.',
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: AppColors.statusDone,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      margin: const EdgeInsets.all(16),
                                    ),
                                  );
                                  Navigator.pop(
                                    context,
                                  ); // close screen and trigger loadData
                                } catch (e) {
                                  setModal(() => uploading = false);
                                  AppConfirmationDialog.show(
                                    ctx,
                                    title: 'Gagal',
                                    message: e.toString().replaceFirst('Exception: ', ''),
                                    type: ConfirmationDialogType.danger,
                                    confirmText: 'Tutup',
                                    cancelText: '',
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cancel_rounded,
                                color: hasReason
                                    ? Colors.white
                                    : AppColors.textMuted,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Konfirmasi Pembatalan',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: hasReason
                                      ? Colors.white
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      reasonCtrl.text.trim().isEmpty || proofFile == null
                          ? 'Lengkapi alasan dan foto bukti untuk membatalkan'
                          : 'Aksi ini tidak bisa dibatalkan setelah dikonfirmasi',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    IconData? icon,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              size: 14,
              color: valueColor ?? AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _AddBonusSheet extends StatefulWidget {
  const _AddBonusSheet({
    required this.order,
    this.initialCleaner,
    required this.onBonusAdded,
  });
  final OrderModel order;
  final OrderCleaner? initialCleaner;
  final VoidCallback onBonusAdded;

  @override
  State<_AddBonusSheet> createState() => _AddBonusSheetState();
}

class _AddBonusSheetState extends State<_AddBonusSheet> {
  final OrderService _orderService = OrderService();
  final _nominalCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _tarifBonuses = [];
  Map<String, dynamic>? _selectedTarifBonus;
  final Set<String> _selectedPesananCleanerIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialCleaner != null) {
      _selectedPesananCleanerIds.add(widget.initialCleaner!.pesananCleanerId);
    } else {
      _selectedPesananCleanerIds.addAll(widget.order.cleaners.map((c) => c.pesananCleanerId));
    }
    _fetchTarifBonus();
    _onTarifSelected(null);
  }

  Future<void> _fetchTarifBonus() async {
    try {
      final tarif = await _orderService.fetchTarifBonus(widget.order.cabangId);
      if (mounted) {
        setState(() {
          _tarifBonuses = tarif;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onTarifSelected(Map<String, dynamic>? tarif) {
    setState(() {
      _selectedTarifBonus = tarif;
      _noteCtrl.clear();

      if (tarif != null && tarif['nominal_default'] != null) {
        final double nominalVal =
            double.tryParse(tarif['nominal_default'].toString()) ?? 0;
        _nominalCtrl.text = CurrencyInputFormatter.format(nominalVal.toInt());
      } else {
        _nominalCtrl.clear();
      }

      final String targetJenis = tarif == null
          ? 'Bonus Manual'
          : (tarif['jenis_bonus']?['nama_bonus'] ?? '');

      // Pre-fill notes if single cleaner selected
      if (targetJenis.isNotEmpty && _selectedPesananCleanerIds.length == 1) {
        final cleanerId = _selectedPesananCleanerIds.first;
        final cleaner = widget.order.cleaners.where((c) => c.pesananCleanerId == cleanerId).firstOrNull;
        if (cleaner != null) {
          final existing = cleaner.bonuses.where((b) => b.jenisBonus.toLowerCase() == targetJenis.toLowerCase()).firstOrNull;
          if (existing != null) {
            _nominalCtrl.text = CurrencyInputFormatter.format(existing.nominal);
            if (existing.keterangan != '-' &&
                existing.keterangan != 'Bonus manual' &&
                existing.keterangan != targetJenis) {
              _noteCtrl.text = existing.keterangan;
            }
          }
        }
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedPesananCleanerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 cleaner penerima bonus')),
      );
      return;
    }

    final nominalText = _nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (nominalText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal bonus wajib diisi')),
      );
      return;
    }

    final int nominalInt = int.parse(nominalText);
    final String note = _noteCtrl.text.trim();

    setState(() => _isSubmitting = true);
    try {
      final String targetJenis = _selectedTarifBonus == null
          ? 'Bonus Manual'
          : (_selectedTarifBonus!['jenis_bonus']?['nama_bonus'] ?? 'Bonus');

      int jenisBonusId = 4;
      if (_selectedTarifBonus != null && _selectedTarifBonus!['jenis_bonus_id'] != null) {
        jenisBonusId = _selectedTarifBonus!['jenis_bonus_id'] as int;
      } else {
        final manualTarif = _tarifBonuses.where(
          (t) => (t['jenis_bonus']?['nama_bonus']?.toString().toLowerCase() ?? '') == 'bonus manual',
        ).firstOrNull;
        if (manualTarif != null && manualTarif['jenis_bonus_id'] != null) {
          jenisBonusId = manualTarif['jenis_bonus_id'] as int;
        }
      }

      for (final pesananCleanerId in _selectedPesananCleanerIds) {
        final cleaner = widget.order.cleaners.where((c) => c.pesananCleanerId == pesananCleanerId).firstOrNull;
        final existing = cleaner?.bonuses.where((b) => b.jenisBonus.toLowerCase() == targetJenis.toLowerCase()).firstOrNull;

        if (existing != null && existing.id.isNotEmpty) {
          await _orderService.updateManualBonus(
            existing.id,
            nominalInt,
            note,
          );
        } else {
          await _orderService.storeManualBonus(
            pesananCleanerId,
            jenisBonusId,
            nominalInt,
            note,
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bonus berhasil diberikan untuk ${_selectedPesananCleanerIds.length} cleaner!'),
          backgroundColor: AppColors.statusDone,
        ),
      );
      widget.onBonusAdded();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppConfirmationDialog.show(
        context,
        title: 'Gagal',
        message: e.toString().replaceFirst('Exception: ', ''),
        type: ConfirmationDialogType.danger,
        confirmText: 'Tutup',
        cancelText: '',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Beri Bonus Cleaner',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bisa pilih beberapa cleaner sekaligus',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: Color(0xFF2563EB),
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                // Cleaner Multi-Select Section
                if (widget.order.cleaners.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pilih Cleaner (${_selectedPesananCleanerIds.length}/${widget.order.cleaners.length})',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (widget.order.cleaners.length > 1)
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (_selectedPesananCleanerIds.length == widget.order.cleaners.length) {
                                _selectedPesananCleanerIds.clear();
                              } else {
                                _selectedPesananCleanerIds.clear();
                                _selectedPesananCleanerIds.addAll(
                                  widget.order.cleaners.map((c) => c.pesananCleanerId),
                                );
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Text(
                              _selectedPesananCleanerIds.length == widget.order.cleaners.length
                                  ? 'Batal Semua'
                                  : 'Pilih Semua',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Cleaner Cards
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: widget.order.cleaners.map((c) {
                        final isSelected = _selectedPesananCleanerIds.contains(c.pesananCleanerId);
                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedPesananCleanerIds.remove(c.pesananCleanerId);
                              } else {
                                _selectedPesananCleanerIds.add(c.pesananCleanerId);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF93C5FD) : const Color(0xFFF1F5F9),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (c.totalBonus > 0)
                                        Text(
                                          'Total saat ini: Rp ${CurrencyInputFormatter.format(c.totalBonus)}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: const Color(0xFF059669),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Dipilih',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                Text(
                  'Jenis Bonus',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>>(
                      isExpanded: true,
                      value: _selectedTarifBonus,
                      hint: Text(
                        'Pilih jenis bonus...',
                        style: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(
                            'Bonus Manual',
                            style: GoogleFonts.inter(fontSize: 14),
                          ),
                        ),
                        ..._tarifBonuses
                            .where((t) {
                              final name =
                                  t['jenis_bonus']?['nama_bonus']
                                      ?.toString()
                                      .toLowerCase() ??
                                  '';
                              return name != 'bonus layanan' &&
                                  name != 'bonus manual';
                            })
                            .map((t) {
                              return DropdownMenuItem(
                                value: t,
                                child: Text(
                                  t['jenis_bonus']?['nama_bonus'] ?? 'Bonus',
                                  style: GoogleFonts.inter(fontSize: 14),
                                ),
                              );
                            }),
                      ],
                      onChanged: _onTarifSelected,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Nominal per Cleaner (Rp)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nominalCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Misal: 20000',
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Keterangan',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Catatan tambahan (opsional)',
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _selectedPesananCleanerIds.isNotEmpty
                                ? 'Simpan Bonus (${_selectedPesananCleanerIds.length} Cleaner)'
                                : 'Pilih Cleaner Terlebih Dahulu',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
