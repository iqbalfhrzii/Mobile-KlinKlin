import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/data/order_model.dart';
import '../services/order_service.dart';
import 'create_order_screen.dart';
import '../../payment/screens/payment_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import '../../../core/services/pdf_invoice_service.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/whatsapp_icon.dart';
import '../../../core/utils/currency_formatter.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.order, this.isReadOnly = false});
  final OrderModel order;
  final bool isReadOnly;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderService _orderService = OrderService();
  late OrderModel _o;
  bool _isLoading = false;

  bool get _canEdit {
    if (widget.isReadOnly) return false;
    return _o.statusUtamaLabel != 'Done' &&
        _o.status != OrderStatus.completed &&
        _o.status != OrderStatus.cancelled;
  }

  bool get _isPaid {
    final s = _o.paymentStatus.toLowerCase();
    return s == 'paid' || s == 'lunas' || s == 'settlement';
  }

  @override
  void initState() {
    super.initState();
    _o = widget.order;
    _fetchDetail();
  }

  Future<void> _togglePpn() async {
    if (_isPaid) return;

    final bool currentPpnStatus = (_o.ppn ?? _o.pembayaran?.ppn ?? 0) > 0;
    final int newPpn = currentPpnStatus ? 0 : 11;

    setState(() {
      _o.ppn = newPpn;
    });

    try {
      final draft = OrderDraft(
        customer: _o.customer,
        chatDari: _o.chatDari,
        tipeCustomer: _o.tipeCustomer,
        services: List.from(_o.services),
        cleaners: List.from(_o.cleaners),
        notes: _o.notes,
        applyPpn: newPpn > 0,
      );

      await _orderService.updateOrder(_o.id, draft);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status PPN berhasil diperbarui')),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('selesai') ||
            errorMsg.contains('pembayaran') ||
            _o.status == OrderStatus.finishedByCleaner) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PPN diubah lokal, akan disimpan saat pembayaran.'),
            ),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal memperbarui PPN: $e')));
          setState(() {
            _o.ppn = currentPpnStatus ? 11 : 0;
          });
        }
      }
    }
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoading = true);
    try {
      final updatedOrder = await _orderService.fetchOrderDetail(_o.id);
      final prefs = await SharedPreferences.getInstance();
      final cachedMethod = prefs.getString('order_payment_method_${_o.id}');
      if (cachedMethod != null && updatedOrder.paymentMethod == '-') {
        updatedOrder.paymentMethod = cachedMethod;
      }
      if (mounted) {
        setState(() {
          _o = updatedOrder;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _notifyCleaner() async {
    setState(() => _isLoading = true);
    try {
      await _orderService.notifyCleaner(_o.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berhasil mengirim notifikasi ke cleaner!'),
          backgroundColor: AppColors.statusDone,
        ),
      );
      _fetchDetail();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    }
  }

  void _showRequestEditDialog() {
    if (_o.hasPendingEditRequest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengajuan edit layanan sudah dikirim dan sedang menunggu persetujuan Finance.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }

    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Ajukan Edit Layanan',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status pesanan sudah selesai/diproses. Silakan masukkan alasan pengajuan edit untuk disetujui Finance:',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Contoh: Maaf mbak ada salah input pembayaran / layanan...',
                hintStyle: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alasan pengajuan edit harus diisi.')),
                );
                return;
              }
              Navigator.pop(context); // Tutup dialog
              
              setState(() => _isLoading = true);
              try {
                await _orderService.submitPengajuanEdit(widget.order.id, reason);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pengajuan edit layanan berhasil dikirim ke Finance!'),
                    backgroundColor: Color(0xFF059669),
                  ),
                );
                _fetchDetail(); // Tarik ulang data dari server
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
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Kirim Pengajuan'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleWa(OrderCleaner cleaner) async {
    if (cleaner.pesananCleanerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID Cleaner tidak valid (belum tersimpan di database)'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _orderService.toggleWa(cleaner.pesananCleanerId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cleaner.showWa
                ? 'Akses WA disembunyikan'
                : 'Akses WA ditampilkan untuk cleaner',
          ),
          backgroundColor: AppColors.statusDone,
        ),
      );
      _fetchDetail();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    }
  }

  String _formatRupiah(int n) =>
      'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    final o = _o;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context, o, _canEdit),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchDetail,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  children: [
                    _buildCustomerCard(o),
                    const SizedBox(height: 12),
                    _buildServicesCard(o),
                    const SizedBox(height: 12),
                    if (o.cleaners.isNotEmpty) ...[
                      ...o.cleaners
                          .expand(
                            (c) => [
                              _buildCleanerCard(o, c),
                              const SizedBox(height: 12),
                            ],
                          )
                          .take(o.cleaners.length * 2 - 1),
                      if (_canEdit) ...[
                        const SizedBox(height: 12),
                        _buildAlokasiBonusButton(o),
                        const SizedBox(height: 12),
                        _buildSelesaiBonusButton(o),
                      ],
                    ] else ...[
                      _buildEmptyCleanerCard(o),
                    ],
                    const SizedBox(height: 12),
                    _buildPaymentCard(o),
                    if (o.notes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildNotesCard(o),
                    ],
                    const SizedBox(height: 20),
                    _buildProgressCard(o),
                    const SizedBox(height: 16),
                    _buildActionButtons(o),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, OrderModel o, bool canEdit) {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HeaderBackButton(onTap: () => Navigator.pop(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detail Pesanan',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      o.nomorPesanan,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!widget.isReadOnly) ...[
                if (_canEdit) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateOrderScreen(existingOrder: o),
                        ),
                      );
                      if (result == true) {
                        _fetchDetail();
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Edit Pesanan',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _showRequestEditDialog,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_note_rounded, color: Color(0xFFD97706), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            o.hasPendingEditRequest ? 'Edit Pending' : 'Ajukan Edit',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(OrderModel o) {
    return _card(
      title: 'Info Pesanan',
      trailingAction: StatusBadge(status: o.status, order: o),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: o.customer.name, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.customer.name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      o.customer.phone,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.isReadOnly) ...[
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => _launchWA(o.customer.phone),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF25D366).withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const WhatsAppIcon(
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Chat WA',
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
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 18,
                color: AppColors.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alamat Pengerjaan',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      o.customer.address,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textDark,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      o.customer.area,
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Sumber: ${o.chatDari.name}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Tipe: ${o.tipeCustomer.name}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (o.customer.notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.note_alt_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Catatan Pelanggan:',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    o.customer.notes,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServicesCard(OrderModel o) {
    final hasSchedule =
        o.services.isNotEmpty &&
        o.services.first.tanggalPengerjaan.isNotEmpty &&
        o.services.first.waktuPengerjaan.isNotEmpty;

    return _card(
      title: 'Detail Layanan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Jadwal: ',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                Expanded(
                  child: Text(
                    hasSchedule
                        ? '${o.services.first.tanggalPengerjaan} · ${o.services.first.waktuPengerjaan}'
                        : 'Belum diatur',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (_canEdit) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showAturJadwalModal(o),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.edit_calendar_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasSchedule ? 'Ubah' : 'Atur',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...o.services.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBlue.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Qty: ',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                TextSpan(
                                  text: s.qty,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (s.bonusLayanan > 0)
                          Text(
                            'Bonus: ${_formatRupiah(s.bonusLayanan)}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.statusDone,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatRupiah(s.subtotal),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 12, color: AppColors.border),
          Builder(
            builder: (context) {
              final double diskonPersen = o.pembayaran?.diskonPersen ?? 0.0;
              final int diskonValue = (o.total * (diskonPersen / 100)).round();
              final int totalSetelahDiskon = o.total - diskonValue;

              final int ppnPersen = o.ppn ?? o.pembayaran?.ppn ?? 0;
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
                        _formatRupiah(o.total),
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
                          '-${_formatRupiah(diskonValue)}',
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
                      InkWell(
                        onTap: () {
                          if (!_isPaid) {
                            _togglePpn();
                          }
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 2,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                ppnPersen > 0
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                size: 18,
                                color: ppnPersen > 0
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'PPN (11%)',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        _formatRupiah(ppnValue),
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
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        _formatRupiah(totalAkhir),
                        style: GoogleFonts.inter(
                          fontSize: 16,
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
          if (_canEdit) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showTambahLayananSheet(o),
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      'Tambah Layanan',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAturQtyHargaDropdownModal(o),
                    icon: const Icon(
                      Icons.edit_note_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      'Atur Harga / Qty',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyCleanerCard(OrderModel o) {
    final hasSchedule = o.services.isNotEmpty &&
        o.services.first.tanggalPengerjaan.isNotEmpty &&
        o.services.first.waktuPengerjaan.isNotEmpty;

    return _card(
      title: 'Petugas Kebersihan',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceBlue.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 28,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Belum ada cleaner ditugaskan',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
          if (_canEdit) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (!hasSchedule) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Silakan Atur Jadwal terlebih dahulu.'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                  _showAssignCleanerModal(o);
                },
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Tugaskan Cleaner'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCleanerCard(OrderModel o, OrderCleaner cleaner) {
    return _card(
      title: 'Petugas Kebersihan',
      trailingAction: _canEdit
          ? InkWell(
              onTap: () {
                final hasSchedule = o.services.isNotEmpty &&
                    o.services.first.tanggalPengerjaan.isNotEmpty &&
                    o.services.first.waktuPengerjaan.isNotEmpty;
                if (!hasSchedule) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Silakan Atur Jadwal terlebih dahulu.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
                _showAssignCleanerModal(o);
              },
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBlue,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 12,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Ubah',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Builder(
                builder: (context) {
                  final String? foto = cleaner.fotoProfil
                      ?.replaceAll('\\', '/')
                      .trim();
                  final bool hasFoto =
                      foto != null && foto.isNotEmpty && foto != 'null';

                  Widget avatarContent = const Icon(
                    Icons.cleaning_services_rounded,
                    color: AppColors.primary,
                    size: 20,
                  );

                  if (hasFoto) {
                    if (foto.startsWith('data:image')) {
                      try {
                        final base64Str = foto.split(',').last;
                        avatarContent = Image.memory(
                          base64Decode(base64Str),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.cleaning_services_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        );
                      } catch (_) {}
                    } else {
                      final String fullUrl = foto.startsWith('http')
                          ? foto
                          : '${ApiClient.baseUrl.replaceAll('/api', '')}/storage/${foto.replaceFirst(RegExp(r'^/?storage/'), '')}';
                      avatarContent = Image.network(
                        Uri.encodeFull(fullUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.cleaning_services_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      );
                    }
                  }

                  return Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: hasFoto
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: avatarContent,
                          )
                        : avatarContent,
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cleaner.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                cleaner.statusPengerjaan ==
                                    CleanerWorkStatus.finished
                                ? AppColors.statusDoneBg
                                : AppColors.surfaceBlue,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            cleaner.statusPengerjaan.label,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color:
                                  cleaner.statusPengerjaan ==
                                      CleanerWorkStatus.finished
                                  ? AppColors.statusDone
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!widget.isReadOnly && cleaner.phone.isNotEmpty) ...[
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => _launchWA(cleaner.phone),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF25D366).withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const WhatsAppIcon(
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Chat WA',
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
            ],
          ),
          if (cleaner.totalBonus > 0) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBE6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE58F)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Bonus: ${_formatRupiah(cleaner.totalBonus)}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD48806),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Divider(color: Color(0xFFFFE58F), height: 1),
                  const SizedBox(height: 6),
                  ...cleaner.bonuses.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '• ${b.jenisBonus}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFAD6800),
                                ),
                              ),
                              Text(
                                _formatRupiah(b.nominal),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFD48806),
                                ),
                              ),
                            ],
                          ),
                          if (b.keterangan != null &&
                              b.keterangan.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '  ${b.keterangan}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFFAD6800).withValues(alpha: 0.8),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_canEdit) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 8),
            // Toggle Switch Row for WA Sharing
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const WhatsAppIcon(
                      size: 18,
                      color: Color(0xFF25D366),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Bagikan WA Customer ke Cleaner',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    cleaner.showWa
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: cleaner.showWa
                        ? AppColors.statusDone
                        : AppColors.textMuted,
                    size: 22,
                  ),
                  onPressed: () => _toggleWa(cleaner),
                  tooltip: cleaner.showWa ? 'Sembunyikan WA' : 'Bagikan WA',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 10),
            // Add Bonus Button (Full width)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddBonusSheet(o, cleaner),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                label: const Text('Tambah Bonus'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddBonusSheet(OrderModel o, OrderCleaner cleaner) {
    if (cleaner.pesananCleanerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID Cleaner tidak valid (belum tersimpan di database)'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => _AddBonusSheet(
        order: o,
        cleaner: cleaner,
        onBonusAdded: _fetchDetail,
      ),
    );
  }

  Widget _buildPaymentCard(OrderModel o) {
    final isPaid = o.paymentStatus == 'paid' || o.paymentStatus == 'approved';
    return _card(
      title: 'Status Pembayaran',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Metode',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      o.paymentMethod,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_canEdit)
                      InkWell(
                        onTap: () => _showAturMetodePembayaran(o),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBlue,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.edit_note_rounded,
                                size: 12,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Atur',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isPaid
                  ? AppColors.statusDoneBg
                  : AppColors.statusPendingBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPaid ? AppColors.statusDone : AppColors.statusPending,
              ),
            ),
            child: Text(
              isPaid ? '✓ Lunas' : 'Belum Lunas',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isPaid ? AppColors.statusDone : AppColors.statusPending,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(OrderModel o) {
    return _card(
      title: 'Catatan',
      child: Text(
        o.notes,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.textDark,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required Widget child,
    Widget? trailingAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              if (trailingAction != null) trailingAction,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildProgressCard(OrderModel o) {
    final hasSchedule =
        o.services.isNotEmpty &&
        o.services.first.tanggalPengerjaan.isNotEmpty &&
        o.services.first.waktuPengerjaan.isNotEmpty;
    final isPriceQtyValid =
        o.services.isNotEmpty &&
        o.services.every(
          (s) => s.price > 0 && s.qty.trim().isNotEmpty && s.qty.trim() != '0',
        );
    final hasCleaner = o.cleaners.isNotEmpty;
    final hasBonus =
        o.services.any((s) => s.bonusLayanan > 0) ||
        o.cleaners.any((c) => c.totalBonus > 0);
    final isPaid = o.paymentStatus == 'paid' || o.paymentStatus == 'approved';

    final steps = [
      ('Jadwal', hasSchedule),
      ('Harga/Qty', isPriceQtyValid),
      ('Cleaner', hasCleaner),
      ('Bonus', hasBonus),
      ('Lunas', isPaid),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PROGRESS PESANAN',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${steps.where((s) => s.$2).length} / ${steps.length} Selesai',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(steps.length, (i) {
              final isDone = steps[i].$2;
              final label = steps[i].$1;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: isDone
                                  ? AppColors.statusDone
                                  : AppColors.surfaceBlue,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isDone ? Icons.check_rounded : Icons.circle_outlined,
                              color: isDone ? Colors.white : AppColors.textMuted,
                              size: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
                              color: isDone ? AppColors.statusDone : AppColors.textMuted,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (i < steps.length - 1)
                      Container(
                        width: 10,
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 14),
                        color: isDone && steps[i + 1].$2
                            ? AppColors.statusDone
                            : AppColors.border,
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(OrderModel o) {
    final showNotifyBtn =
        o.cleaners.isNotEmpty &&
        o.status != OrderStatus.completed &&
        o.status != OrderStatus.cancelled;
    final isPriceQtyValid =
        o.services.isNotEmpty &&
        o.services.every(
          (s) => s.price > 0 && s.qty.trim().isNotEmpty && s.qty.trim() != '0',
        );
    final isPaid = o.paymentStatus == 'paid' || o.paymentStatus == 'approved';
    final hasBonus =
        o.services.any((s) => s.bonusLayanan > 0) ||
        o.cleaners.any((c) => c.totalBonus > 0);

    return Column(
      children: [
        if (_canEdit && !widget.isReadOnly) ...[
          _buildBigActionBtn(
            isLoading: _isLoading,
            title: 'Edit Pesanan',
            subtitle: 'Ubah detail layanan, customer, jadwal, atau cleaner',
            icon: Icons.edit_note_rounded,
            color: AppColors.primary,
            isDone: false,
            enabled: true,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateOrderScreen(existingOrder: o),
                ),
              );
              if (result == true) {
                _fetchDetail();
              }
            },
          ),
          const SizedBox(height: 12),
        ],
        if (showNotifyBtn && !widget.isReadOnly) ...[
          _buildBigActionBtn(
            isLoading: _isLoading,
            title: 'Beritahu Cleaner',
            subtitle: 'Kirim notifikasi tugas ke HP cleaner',
            icon: Icons.notifications_active_rounded,
            color: const Color(0xFFFF9800), // Distinct Orange/Amber for notification
            isDone: !o.cleaners.any(
              (c) => c.statusPengerjaan == CleanerWorkStatus.assigned,
            ),
            enabled: isPriceQtyValid,
            onTap: () {
              if (!isPriceQtyValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Silakan atur Harga dan Qty layanan terlebih dahulu.',
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              if (!hasBonus) {
                showDialog(
                  context: context,
                  builder: (BuildContext ctx) {
                    return AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Bonus Belum Diatur',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      content: Text(
                        'Anda belum mengatur alokasi bonus cleaner.\n\nYakin mau memberitahu cleaner sekarang? (Bonus tetap bisa diatur nanti)',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textDark,
                          height: 1.5,
                        ),
                      ),
                      actionsPadding: const EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        16,
                      ),
                      actions: [
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.red.shade50,
                                  foregroundColor: Colors.red.shade700,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(
                                  'Batal',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _notifyCleaner();
                                },
                                child: Text(
                                  'Yakin',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              } else {
                _notifyCleaner();
              }
            },
          ),
          const SizedBox(height: 12),
        ],
        if (!widget.isReadOnly) ...[
          _buildBigActionBtn(
            isLoading: _isLoading,
            title: 'Pembayaran',
            subtitle: 'Lihat rincian & status pembayaran',
            icon: Icons.payments_rounded,
            color: AppColors.primary,
            isDone: isPaid,
            enabled:
                o.status != OrderStatus.cancelled &&
                o.status != OrderStatus.waitingCancelApproval,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PaymentDetailScreen(order: o)),
              );
              if (result == true) {
                _fetchDetail();
              }
            },
          ),
        ],
        if (!widget.isReadOnly && o.status != OrderStatus.cancelled &&
            o.status != OrderStatus.waitingCancelApproval) ...[
          const SizedBox(height: 12),
          _buildBigActionBtn(
            isLoading: _isLoading,
            title: 'Kirim Invoice WA',
            subtitle: 'Kirim rincian tagihan ke WhatsApp',
            icon: Icons.send_rounded,
            color: const Color(0xFF25D366),
            isDone: false,
            enabled: true,
            onTap: () => _sendInvoiceWA(o),
          ),
        ],
        if (o.status == OrderStatus.waitingPaymentApproval ||
            o.status == OrderStatus.finishedByCleaner ||
            o.status == OrderStatus.completed ||
            _isPaid ||
            (o.paymentStatus.isNotEmpty &&
                o.paymentStatus != '-' &&
                o.paymentStatus.toLowerCase() != 'unpaid')) ...[
          const SizedBox(height: 12),
          _buildBigActionBtn(
            isLoading: _isLoading,
            title: 'Lihat PDF Invoice',
            subtitle: 'Cetak atau simpan tagihan dalam format PDF',
            icon: Icons.picture_as_pdf_rounded,
            color: const Color(0xFFE53935), // Red color for PDF
            isDone: false,
            enabled: true,
            onTap: () async {
              await Printing.layoutPdf(
                name: 'KLINKLIN-${o.customer.name}-${o.customer.area}-${o.nomorPesanan}'
                    .replaceAll(' ', '_'),
                onLayout: (format) => PdfInvoiceService.generateInvoice(o),
              );
            },
          ),
        ],

      ],
    );
  }

  void _showTambahLayananSheet(OrderModel o) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TambahLayananOrderDetailSheet(
        order: o,
        onServiceAdded: (newItem) async {
          setState(() => _isLoading = true);
          try {
            final updatedServices = List<ServiceItem>.from(o.services)..add(newItem);
            final draft = OrderDraft(
              customer: o.customer,
              chatDari: o.chatDari,
              tipeCustomer: o.tipeCustomer,
              services: updatedServices,
              cleaners: List.from(o.cleaners),
              notes: o.notes,
              applyPpn: (o.ppn ?? o.pembayaran?.ppn ?? 0) > 0,
            );
            await _orderService.updateOrder(o.id, draft);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Layanan berhasil ditambahkan!'),
                backgroundColor: AppColors.statusDone,
              ),
            );
            _fetchDetail();
          } catch (e) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Gagal menambahkan layanan: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _sendInvoiceWA(OrderModel o) async {
    final customerName = o.customer.name;
    final branchName = o.customer.area.toUpperCase();
    final orderId = o.id;
    final address = o.customer.address;

    String rincian = '';
    for (int i = 0; i < o.services.length; i++) {
      final s = o.services[i];
      rincian += '${i + 1}. ${s.name} : ${s.qty}\n';
    }
    if (rincian.isEmpty) {
      rincian = '-';
    }

    final tglRaw = o.services.isNotEmpty
        ? o.services.first.tanggalPengerjaan
        : '';
    final waktu = o.services.isNotEmpty
        ? o.services.first.waktuPengerjaan
        : '-';

    final dateFmt = _formatWADate(tglRaw).split('|');
    final hari = dateFmt[0];
    final tanggal = dateFmt.length > 1 ? dateFmt[1] : '-';

    final subtotal = o.total;
    final ppn = (subtotal * 0.11).round();
    final totalAkhir = subtotal + ppn;

    final message =
        '''Halo Kak $customerName
Terimakasih sudah melakukan pemesanan di Klinklin $branchName, Berikut Rinciannya :

📄 *KLINKLIN $branchName*
--------------------------------
No. Order : $orderId
Nama Customer : *$customerName*
Alamat : *$address*

*Rincian Pesanan:*
${rincian.trim()}

Hari : $hari
Waktu : $waktu
Tanggal : $tanggal
--------------------------------
Total Awal : ${_formatRupiah(subtotal).replaceAll('Rp ', '')}
Diskon : 0
PPn : ${_formatRupiah(ppn).replaceAll('Rp ', '')}
*TOTAL BAYAR : ${_formatRupiah(totalAkhir).replaceAll(' ', '')}*
--------------------------------

Transfer hanya ke No. Rekening Berikut:
*Mandiri 1780022255554*
*BCA 8640679949*
an. KLINKLIN INDONESIA GROUP




⚠️ *PENTING & HARAP DIBACA :*
Pembayaran ini SAH jika disertai Invoice Resmi Berupa file PDF.
Jika Anda melakukan pembayaran tanpa menerima Invoice, maka transaksi dianggap TIDAK ADA / ILEGAL

Silahkan klik Link berikut ini jika ada kendala pembayaran
klinklin.co.id/aduanpayment''';

    final phone = o.customer.phone.startsWith('0')
        ? '62${o.customer.phone.substring(1)}'
        : o.customer.phone;
    final encodedMsg = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$phone?text=$encodedMsg');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: just try to launch it anyway
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka WhatsApp'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _launchWA(String noWa) async {
    String phone = noWa.replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('0')) {
      phone = '62${phone.substring(1)}';
    }
    final url = Uri.parse('https://wa.me/$phone');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
        );
      }
    }
  }

  String _formatWADate(String dateString) {
    if (dateString.isEmpty) return '-|-';
    try {
      final dt = DateTime.parse(dateString);
      final days = [
        'Minggu',
        'Senin',
        'Selasa',
        'Rabu',
        'Kamis',
        'Jumat',
        'Sabtu',
      ];
      final months = [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];
      final dayName = days[dt.weekday % 7];
      final monthName = months[dt.month - 1];
      return '$dayName|${dt.day.toString().padLeft(2, '0')} $monthName ${dt.year}';
    } catch (e) {
      return '-|-';
    }
  }

  Widget _buildBigActionBtn({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool enabled,
    bool isDone = false,
    bool isLoading = false,
    required VoidCallback onTap,
  }) {
    final bgColor = isDone ? AppColors.statusDone : color;
    return GestureDetector(
      onTap: (enabled && !isLoading) ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (enabled && !isLoading) ? bgColor : bgColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (isDone)
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            else
              Icon(icon, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showAturJadwalModal(OrderModel o) async {
    final tglCtrl = TextEditingController(
      text: o.services.isNotEmpty ? o.services.first.tanggalPengerjaan : '',
    );
    final waktuCtrl = TextEditingController(
      text: o.services.isNotEmpty ? o.services.first.waktuPengerjaan : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(modalContext).viewInsets.bottom + 20,
          ),
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
              Text(
                'Atur Jadwal Pesanan',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tanggal Pengerjaan',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: tglCtrl,
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    tglCtrl.text =
                        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Pilih Tanggal',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  suffixIcon: const Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Waktu Pengerjaan',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: waktuCtrl,
                readOnly: true,
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    waktuCtrl.text =
                        "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Pilih Jam',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  suffixIcon: const Icon(
                    Icons.access_time_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(modalContext);
                  if (!mounted) return;
                  setState(() => _isLoading = true);
                  try {
                    final updatedServices = o.services
                        .map(
                          (s) => ServiceItem(
                            id: s.id,
                            layananId: s.layananId,
                            name: s.name,
                            price: s.price,
                            qty: s.qty,
                            tanggalPengerjaan: tglCtrl.text,
                            waktuPengerjaan: waktuCtrl.text,
                            bonusLayanan: s.bonusLayanan,
                          ),
                        )
                        .toList();

                    final draft = OrderDraft(
                      customer: o.customer,
                      chatDari: o.chatDari,
                      tipeCustomer: o.tipeCustomer,
                      services: updatedServices,
                      cleaners: o.cleaners,
                      notes: o.notes,
                    );
                    await _orderService.updateOrder(o.id, draft);
                    if (!mounted) return;
                    _fetchDetail();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Jadwal berhasil diperbarui!'),
                        backgroundColor: AppColors.statusDone,
                      ),
                    );
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
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Simpan Jadwal',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAturQtyHargaDropdownModal(OrderModel o) async {
    if (o.services.isEmpty) return;

    ServiceItem selectedService = o.services.first;
    final qtyCtrl = TextEditingController(text: selectedService.qty);
    final String initialHarga = selectedService.price > 0
        ? CurrencyInputFormatter.format(selectedService.price)
        : '';
    final hargaCtrl = TextEditingController(text: initialHarga);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(modalContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Atur Qty / Harga',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ServiceItem>(
                        isExpanded: true,
                        value: selectedService,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        items: o.services.map((s) {
                          return DropdownMenuItem<ServiceItem>(
                            value: s,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.cleaning_services_rounded,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        s.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Qty: ${s.qty} · Rp ${CurrencyInputFormatter.format(s.price.toInt())}',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        selectedItemBuilder: (context) {
                          return o.services.map((s) {
                            return DropdownMenuItem<ServiceItem>(
                              value: s,
                              child: Text(
                                s.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                            );
                          }).toList();
                        },
                        onChanged: (ServiceItem? val) {
                          if (val != null) {
                            setStateModal(() {
                              selectedService = val;
                              qtyCtrl.text = val.qty;
                              hargaCtrl.text = val.price > 0
                                  ? CurrencyInputFormatter.format(val.price)
                                  : '';
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Qty',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: qtyCtrl,
                          decoration: InputDecoration(
                            hintText: 'Misal: 3 jam 2 cleaner',
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Harga Layanan',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: hargaCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [CurrencyInputFormatter()],
                          decoration: InputDecoration(
                            hintText: 'Misal: 150.000',
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(modalContext);
                      if (!mounted) return;
                      setState(() => _isLoading = true);
                      try {
                        final updatedServices = o.services.map((s) {
                          if (s.id == selectedService.id &&
                              s.name == selectedService.name) {
                            return ServiceItem(
                              id: s.id,
                              layananId: s.layananId,
                              name: s.name,
                              price:
                                  int.tryParse(
                                    hargaCtrl.text.replaceAll('.', ''),
                                  ) ??
                                  s.price,
                              qty: qtyCtrl.text.isNotEmpty
                                  ? qtyCtrl.text
                                  : s.qty,
                              tanggalPengerjaan: s.tanggalPengerjaan,
                              waktuPengerjaan: s.waktuPengerjaan,
                              bonusLayanan: s.bonusLayanan,
                            );
                          }
                          return s;
                        }).toList();

                        final draft = OrderDraft(
                          customer: o.customer,
                          chatDari: o.chatDari,
                          tipeCustomer: o.tipeCustomer,
                          services: updatedServices,
                          cleaners: o.cleaners,
                          notes: o.notes,
                        );

                        await _orderService.updateOrder(o.id, draft);
                        if (!mounted) return;
                        _fetchDetail();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Layanan berhasil diperbarui!'),
                            backgroundColor: AppColors.statusDone,
                          ),
                        );
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
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Simpan',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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

  Future<void> _showAssignCleanerModal(OrderModel o) async {
    List<Map<String, dynamic>> availableCleaners = [];
    bool isLoading = true;
    String? error;
    String searchQuery = '';
    List<String> selectedIds = o.cleaners.map((c) => c.id).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (innerContext, setStateModal) {
            if (isLoading && availableCleaners.isEmpty) {
              final service = o.services.isNotEmpty ? o.services.first : null;
              final tanggal = service
                  ?.toJson()['tanggal_pengerjaan']
                  ?.toString();
              final waktu = service?.toJson()['waktu_pengerjaan']?.toString();
              _orderService
                  .fetchAvailableCleaners(tanggal: tanggal, waktu: waktu)
                  .then((data) {
                    if (mounted) {
                      setStateModal(() {
                        availableCleaners = data;
                        isLoading = false;
                      });
                    }
                  })
                  .catchError((e) {
                    if (mounted) {
                      setStateModal(() {
                        error = e.toString();
                        isLoading = false;
                      });
                    }
                  });
            }

            final filteredCleaners = availableCleaners.where((c) {
              final name = (c['nama'] ?? c['name'] ?? '').toString().toLowerCase();
              return name.contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(innerContext).size.height * 0.8,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pilih Cleaner',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(modalContext),
                          child: const Icon(
                            Icons.close,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: TextField(
                      onChanged: (val) {
                        setStateModal(() {
                          searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Cari nama cleaner...',
                        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: AppColors.border),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : error != null
                        ? Center(
                            child: Text(
                              error!,
                              style: const TextStyle(color: AppColors.error),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : filteredCleaners.isEmpty
                        ? Center(
                            child: Text(
                              searchQuery.isNotEmpty
                                  ? 'Cleaner dengan nama "$searchQuery" tidak ditemukan.'
                                  : 'Tidak ada cleaner tersedia.',
                              style: GoogleFonts.inter(
                                color: AppColors.textMuted,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredCleaners.length,
                            itemBuilder: (listContext, index) {
                              final c = filteredCleaners[index];
                              final isSelected = selectedIds.contains(c['id']);
                              final statusPengerjaan =
                                  c['status_pengerjaan']?.toString() ?? 'free';
                              final isBusy = statusPengerjaan == 'in_progress';

                              return GestureDetector(
                                onTap: isBusy
                                    ? null
                                    : () {
                                        setStateModal(() {
                                          if (isSelected) {
                                            selectedIds.remove(c['id']);
                                          } else {
                                            selectedIds.add(c['id']);
                                          }
                                        });
                                      },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.surfaceBlue
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.border,
                                    ),
                                  ),
                                  child: Opacity(
                                    opacity: isBusy ? 0.5 : 1.0,
                                    child: Row(
                                      children: [
                                        Builder(
                                          builder: (context) {
                                            final String? foto =
                                                c['foto_profil']
                                                    ?.toString()
                                                    .replaceAll('\\', '/')
                                                    .trim();
                                            final bool hasFoto =
                                                foto != null &&
                                                foto.isNotEmpty &&
                                                foto != 'null';

                                            Widget avatarContent = const Icon(
                                              Icons.cleaning_services_rounded,
                                              color: AppColors.primary,
                                              size: 20,
                                            );

                                            if (hasFoto) {
                                              if (foto.startsWith(
                                                'data:image',
                                              )) {
                                                try {
                                                  final base64Str = foto
                                                      .split(',')
                                                      .last;
                                                  avatarContent = Image.memory(
                                                    base64Decode(base64Str),
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (
                                                          _,
                                                          __,
                                                          ___,
                                                        ) => const Icon(
                                                          Icons
                                                              .cleaning_services_rounded,
                                                          color:
                                                              AppColors.primary,
                                                          size: 20,
                                                        ),
                                                  );
                                                } catch (_) {}
                                              } else {
                                                final String fullUrl =
                                                    foto.startsWith('http')
                                                    ? foto
                                                    : '${ApiClient.baseUrl.replaceAll('/api', '')}/storage/${foto.replaceFirst(RegExp(r'^/?storage/'), '')}';
                                                avatarContent = Image.network(
                                                  Uri.encodeFull(fullUrl),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(
                                                        Icons
                                                            .cleaning_services_rounded,
                                                        color:
                                                            AppColors.primary,
                                                        size: 20,
                                                      ),
                                                );
                                              }
                                            }

                                            return Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: AppColors.surfaceBlue,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: hasFoto
                                                  ? ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      child: avatarContent,
                                                    )
                                                  : avatarContent,
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                c['name'] as String,
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textDark,
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: !isBusy
                                                          ? AppColors.statusDone
                                                                .withValues(alpha: 
                                                                  0.1,
                                                                )
                                                          : AppColors.error
                                                                .withValues(alpha: 
                                                                  0.1,
                                                                ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      statusPengerjaan
                                                          .toUpperCase(),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10,
                                                        color: !isBusy
                                                            ? AppColors
                                                                  .statusDone
                                                            : AppColors.error,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: AppColors.primary,
                                            size: 22,
                                          ),
                                        if (isBusy)
                                          const Icon(
                                            Icons.block,
                                            color: AppColors.error,
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      MediaQuery.of(innerContext).padding.bottom + 12,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading || error != null
                            ? null
                            : () async {
                                Navigator.pop(modalContext);
                                if (!mounted) return;
                                setState(() => _isLoading = true);
                                try {
                                  await _orderService.assignCleaner(
                                    o.id,
                                    selectedIds,
                                  );
                                  if (!mounted) return;
                                  _fetchDetail();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Berhasil menugaskan cleaner!',
                                      ),
                                      backgroundColor: AppColors.statusDone,
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  setState(() => _isLoading = false);
                                  final errorMsg = e.toString().replaceAll(
                                    'Exception: ',
                                    '',
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(errorMsg),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Simpan Penugasan',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
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

  Widget _buildAlokasiBonusButton(OrderModel o) {
    // Only show if there are services with bonus > 0
    final hasBonusLayanan = o.services.any((s) => s.bonusLayanan > 0);
    if (!hasBonusLayanan) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showAlokasiBonusModal(o),
        icon: const Icon(
          Icons.card_giftcard_rounded,
          size: 18,
          color: AppColors.primary,
        ),
        label: Text(
          'Alokasikan Bonus Layanan',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildSelesaiBonusButton(OrderModel o) {
    final isSelesai = o.statusBonus.toLowerCase() == 'selesai';
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading
            ? null
            : () async {
                setState(() => _isLoading = true);
                try {
                  await _orderService.toggleStatusBonus(o.id);
                  _fetchDetail();
                } catch (e) {
                  setState(() => _isLoading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
        icon: Icon(
          isSelesai ? Icons.close_rounded : Icons.check_circle_rounded,
          size: 18,
          color: isSelesai ? AppColors.textMuted : Colors.white,
        ),
        label: Text(
          isSelesai ? 'Batal Selesai' : 'Selesai Input Bonus',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelesai ? AppColors.textMuted : Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelesai ? Colors.grey[200] : AppColors.statusDone,
          padding: const EdgeInsets.symmetric(vertical: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Future<void> _showAlokasiBonusModal(OrderModel o) async {
    final Map<String, String> allocations = {};
    final defaultCleanerId = o.cleaners.isNotEmpty ? o.cleaners.first.id : null;
    for (var s in o.services.where((s) => s.bonusLayanan > 0)) {
      allocations[s.id] = defaultCleanerId ?? '';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Container(
              height: MediaQuery.of(modalContext).size.height * 0.75,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Alokasi Bonus Layanan',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(modalContext),
                          child: const Icon(
                            Icons.close,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: o.services.where((s) => s.bonusLayanan > 0).map(
                        (s) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      s.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    Text(
                                      _formatRupiah(s.bonusLayanan),
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.statusDone,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Pilih Cleaner Penerima:',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: allocations[s.id],
                                      isExpanded: true,
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: AppColors.textMuted,
                                      ),
                                      items: o.cleaners.map((c) {
                                        return DropdownMenuItem<String>(
                                          value: c.id,
                                          child: Text(
                                            c.name,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setStateModal(
                                            () => allocations[s.id] = val,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ).toList(),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      MediaQuery.of(modalContext).padding.bottom + 12,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(modalContext);
                          if (!mounted) return;
                          setState(() => _isLoading = true);
                          try {
                            final items = allocations.entries
                                .map(
                                  (e) => {
                                    'detail_pesanan_id': int.parse(e.key),
                                    'pesanan_cleaner_id': int.parse(e.value),
                                  },
                                )
                                .toList();

                            await _orderService.allocateBonusLayanan(
                              o.id,
                              items,
                            );
                            if (!mounted) return;
                            _fetchDetail();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Bonus layanan berhasil dialokasikan!',
                                ),
                                backgroundColor: AppColors.statusDone,
                              ),
                            );
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
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Simpan Alokasi',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
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

  void _showAturMetodePembayaran(OrderModel o) {
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

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
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
            Text(
              'Pilih Metode Pembayaran',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            ...methods.map((m) {
              final id = m['id'] as String;
              final icon = m['icon'] as IconData;
              final desc = m['desc'] as String;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: AppColors.primary),
                  ),
                  title: Text(
                    id,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  subtitle: Text(
                    desc,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('order_payment_method_${o.id}', id);
                    setState(() {
                      o.paymentMethod = id;
                    });
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Metode pembayaran dipilih sementara'),
                          backgroundColor: AppColors.statusPending,
                        ),
                      );
                    }
                  },
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

class _AddBonusSheet extends StatefulWidget {
  const _AddBonusSheet({
    required this.order,
    required this.cleaner,
    required this.onBonusAdded,
  });
  final OrderModel order;
  final OrderCleaner cleaner;
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
  String? _existingBonusId;

  @override
  void initState() {
    super.initState();
    _fetchTarifBonus();
    _onTarifSelected(null); // Trigger pre-fill for default 'Bonus Manual'
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
      _existingBonusId = null;

      if (tarif != null && tarif['nominal_default'] != null) {
        final double nominalVal =
            double.tryParse(tarif['nominal_default'].toString()) ?? 0;
        _nominalCtrl.text = CurrencyInputFormatter.format(nominalVal.toInt());
      } else {
        _nominalCtrl.clear();
      }

      // Overwrite with existing bonus if present
      final String targetJenis = tarif == null
          ? 'Bonus Manual'
          : (tarif['jenis_bonus']?['nama_bonus'] ?? '');

      if (targetJenis.isNotEmpty) {
        try {
          final existing = widget.cleaner.bonuses.firstWhere(
            (b) => b.jenisBonus.toLowerCase() == targetJenis.toLowerCase(),
          );
          _existingBonusId = existing.id;
          _nominalCtrl.text = CurrencyInputFormatter.format(existing.nominal);
          if (existing.keterangan != '-' &&
              existing.keterangan != 'Bonus manual' &&
              existing.keterangan != targetJenis) {
            _noteCtrl.text = existing.keterangan;
          }
        } catch (_) {}
      }
    });
  }

  Future<void> _submit() async {
    final nominalText = _nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (nominalText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal bonus wajib diisi')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (_existingBonusId != null && _existingBonusId!.isNotEmpty) {
        await _orderService.updateManualBonus(
          _existingBonusId!,
          int.parse(nominalText),
          _noteCtrl.text.trim(),
        );
      } else {
        if (_selectedTarifBonus == null) {
          // Coba cari tarif bonus manual dari data yang difetch, jika tidak ada fallback ke ID 4 sesuai request
          final manualTarif = _tarifBonuses.firstWhere(
            (t) =>
                (t['jenis_bonus']?['nama_bonus']?.toString().toLowerCase() ??
                    '') ==
                'bonus manual',
            orElse: () => <String, dynamic>{},
          );

          final int jenisBonusId =
              manualTarif.isNotEmpty && manualTarif['jenis_bonus_id'] != null
              ? manualTarif['jenis_bonus_id'] as int
              : 4;

          await _orderService.storeManualBonus(
            widget.cleaner.pesananCleanerId,
            jenisBonusId,
            int.parse(nominalText),
            _noteCtrl.text.trim(),
          );
        } else {
          // Bonus dari Tarif
          await _orderService.storeManualBonus(
            widget.cleaner.pesananCleanerId,
            _selectedTarifBonus!['jenis_bonus_id'] as int,
            int.parse(nominalText),
            _noteCtrl.text.trim(),
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bonus berhasil ditambahkan!'),
          backgroundColor: AppColors.statusDone,
        ),
      );
      widget.onBonusAdded();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Gagal'),
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('OK'),
            ),
          ],
        ),
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
              const SizedBox(height: 20),
              Text(
                'Beri Bonus',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                widget.cleaner.name,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
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
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
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
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit_note_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Bonus Manual',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ],
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
                              final double nominalVal =
                                  double.tryParse(
                                    t['nominal_default']?.toString() ?? '0',
                                  ) ??
                                  0;
                              return DropdownMenuItem(
                                value: t,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.statusDone.withValues(alpha: 
                                          0.08,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.stars_rounded,
                                        size: 16,
                                        color: AppColors.statusDone,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            t['jenis_bonus']?['nama_bonus'] ??
                                                'Bonus',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Nominal: Rp ${CurrencyInputFormatter.format(nominalVal.toInt())}',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: AppColors.textMuted,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            })
                            .toList(),
                      ],
                      selectedItemBuilder: (context) {
                        return [
                          DropdownMenuItem(
                            value: null,
                            child: Text(
                              'Bonus Manual',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
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
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                );
                              })
                              .toList(),
                        ];
                      },
                      onChanged: _onTarifSelected,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Nominal (Rp)',
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
                            'Simpan Bonus',
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

class _TambahLayananOrderDetailSheet extends StatefulWidget {
  const _TambahLayananOrderDetailSheet({
    required this.order,
    required this.onServiceAdded,
  });

  final OrderModel order;
  final Function(ServiceItem) onServiceAdded;

  @override
  State<_TambahLayananOrderDetailSheet> createState() =>
      __TambahLayananOrderDetailSheetState();
}

class __TambahLayananOrderDetailSheetState
    extends State<_TambahLayananOrderDetailSheet> {
  List<Map<String, dynamic>> _availableServices = [];
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _selectedLayanan;
  final _qtyCtrl = TextEditingController();
  final _hargaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLayanan();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _hargaCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLayanan() async {
    try {
      final svc = OrderService();
      final data = await svc.fetchLayanan();
      if (mounted) {
        setState(() {
          _availableServices = data;
          _isLoading = false;
          if (_availableServices.isNotEmpty) {
            _selectedLayanan = _availableServices.first;
            final price =
                _selectedLayanan!['harga'] ?? _selectedLayanan!['harga_default'];
            final num priceVal = price is num
                ? price
                : (num.tryParse(price?.toString() ?? '0') ?? 0);
            if (priceVal > 0) {
              _hargaCtrl.text = CurrencyInputFormatter.format(priceVal.toInt());
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _submit() {
    if (_qtyCtrl.text.trim().isEmpty || _selectedLayanan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Layanan dan Qty wajib diisi'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final priceInt =
        int.tryParse(_hargaCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    final newItem = ServiceItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      layananId: _selectedLayanan!['id']?.toString() ?? '1',
      name: _selectedLayanan!['nama_layanan'] ?? 'Layanan',
      price: priceInt,
      qty: _qtyCtrl.text.trim(),
      tanggalPengerjaan: widget.order.services.isNotEmpty
          ? widget.order.services.first.tanggalPengerjaan
          : '',
      waktuPengerjaan: widget.order.services.isNotEmpty
          ? widget.order.services.first.waktuPengerjaan
          : '',
      bonusLayanan: 0,
    );

    Navigator.pop(context);
    widget.onServiceAdded(newItem);
  }

  void _showSearchServiceDialog() {
    String searchQ = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final filtered = _availableServices.where((e) {
              final name = e['nama_layanan']?.toString().toLowerCase() ?? '';
              return name.contains(searchQ.toLowerCase());
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
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
                    const SizedBox(height: 20),
                    Text(
                      'Pilih Layanan',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      onChanged: (val) {
                        setStateModal(() {
                          searchQ = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Cari layanan...',
                        hintStyle: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cleaning_services_rounded,
                                    color: AppColors.textMuted.withValues(alpha: 0.3),
                                    size: 48,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Layanan tidak ditemukan',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(
                                color: AppColors.border,
                                height: 1,
                              ),
                              itemBuilder: (context, index) {
                                final e = filtered[index];
                                final price =
                                    e['harga'] ?? e['harga_default'];
                                final num priceVal = price is num
                                    ? price
                                    : (num.tryParse(price?.toString() ?? '0') ??
                                        0);
                                final isSelected =
                                    _selectedLayanan?['id'] == e['id'];

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary.withValues(alpha: 0.1)
                                          : AppColors.primary
                                              .withValues(alpha: 0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.cleaning_services_rounded,
                                      size: 18,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                  title: Text(
                                    e['nama_layanan'] ?? '',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textDark,
                                    ),
                                  ),
                                  subtitle: priceVal > 0
                                      ? Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text(
                                            'Harga default: Rp ${CurrencyInputFormatter.format(priceVal.toInt())}',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        )
                                      : null,
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: AppColors.primary,
                                          size: 20,
                                        )
                                      : const Icon(
                                          Icons.chevron_right_rounded,
                                          color: AppColors.textMuted,
                                          size: 20,
                                        ),
                                  onTap: () {
                                    Navigator.pop(dialogCtx, e);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((selected) {
      if (selected != null) {
        setState(() {
          _selectedLayanan = selected as Map<String, dynamic>;
          final price =
              _selectedLayanan!['harga'] ?? _selectedLayanan!['harga_default'];
          final num priceVal = price is num
              ? price
              : (num.tryParse(price?.toString() ?? '0') ?? 0);
          _hargaCtrl.text = priceVal > 0
              ? CurrencyInputFormatter.format(priceVal.toInt())
              : '';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
              Text(
                'Tambah Layanan Baru',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Nama Layanan',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Text(_error!, style: const TextStyle(color: AppColors.error))
              else if (_availableServices.isEmpty)
                const Text('Tidak ada layanan tersedia.')
              else
                InkWell(
                  onTap: _showSearchServiceDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _selectedLayanan != null
                                ? _selectedLayanan!['nama_layanan']
                                : 'Pilih layanan...',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: _selectedLayanan != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: _selectedLayanan != null
                                  ? AppColors.textDark
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Text(
                'Harga Layanan (Rp)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _hargaCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: 'Contoh: 150.000',
                  hintStyle: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
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
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Qty (Kuantitas)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _qtyCtrl,
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: 'Contoh: 1 / 3 jam 2 cleaner',
                  hintStyle: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
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
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Simpan Layanan',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
