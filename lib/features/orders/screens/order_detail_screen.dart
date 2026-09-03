import 'package:flutter/material.dart';
import '../../../core/widgets/app_confirmation_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/data/order_model.dart';
import '../services/order_service.dart';
import 'create_order_screen.dart';
import '../../payment/screens/payment_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
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

  bool get _isPaid {
    final s = _o.paymentStatus.toLowerCase();
    return s == 'paid' || s == 'lunas' || s == 'settlement' || s == 'approved' || s == 'disetujui' || _o.status == OrderStatus.completed;
  }

  bool get _isCancelled =>
      _o.status == OrderStatus.cancelled ||
      _o.status == OrderStatus.waitingCancelApproval ||
      _o.paymentStatus.toLowerCase() == 'cancelled' ||
      _o.statusUtamaLabel == 'Dibatalkan' ||
      _o.pembatalanId != null;

  bool get _canEdit {
    if (widget.isReadOnly) return false;
    if (_isCancelled) return false;
    if (_o.status == OrderStatus.completed || _o.statusUtamaLabel == 'Done') return false;

    // Patokan murni di status pembayaran:
    // Jika CS sudah ajukan pembayaran (pending verifikasi Finance) atau sudah approved / lunas,
    // maka pesanan terkunci dan CS harus mengajukan edit ke Finance terlebih dahulu.
    final s = _o.paymentStatus.toLowerCase();
    final bool isPaymentLocked = (s == 'pending' || s == 'approved' || s == 'disetujui' || s == 'paid' || s == 'lunas');
    if (isPaymentLocked) return false;

    // Jika CS sedang menunggu approval pengajuan edit dari Finance, tidak bisa edit langsung
    if (_o.hasPendingEditRequest) return false;

    return true;
  }

  @override
  void initState() {
    super.initState();
    _o = widget.order;
    _fetchDetail();
  }

  Future<void> _openMap(String address) async {
    final query = Uri.encodeComponent(address);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka Maps')),
        );
      }
    }
  }



  Future<void> _togglePph() async {
    if (_isPaid) return;

    final bool currentPphStatus = (_o.pph ?? _o.pembayaran?.pph ?? 0) > 0;
    final int newPph = currentPphStatus ? 0 : 2;

    setState(() {
      _o.pph = newPph;
    });

    try {
      final draft = OrderDraft(
        customer: _o.customer,
        chatDari: _o.chatDari,
        tipeCustomer: _o.tipeCustomer,
        services: List.from(_o.services),
        cleaners: List.from(_o.cleaners),
        notes: _o.notes,
        applyPpn: (_o.ppn ?? _o.pembayaran?.ppn ?? 0) > 0,
        applyPph: newPph > 0,
      );

      await _orderService.updateOrder(_o.id, draft);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status PPh berhasil diperbarui')),
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
              content: Text('PPh diubah lokal, akan disimpan saat pembayaran.'),
            ),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal memperbarui PPh: $e')));
          setState(() {
            _o.pph = currentPphStatus ? 2 : 0;
          });
        }
      }
    }
  }

  Future<void> _showEditDiskonDialog() async {
    if (_isPaid) return;
    double currentDiskon = _o.diskonPersen;
    final ctrl = TextEditingController(
      text: currentDiskon > 0 ? (currentDiskon == currentDiskon.toInt() ? currentDiskon.toInt().toString() : currentDiskon.toString()) : '',
    );

    final result = await showModalBottomSheet<double>(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            padding: EdgeInsets.fromLTRB(
              20, 20, 20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.local_offer_rounded,
                        color: Color(0xFF059669),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Atur Diskon Pesanan',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            'Diskon akan langsung tercantum pada rincian & invoice PDF',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'PILIH PERSENTASE CEPAT',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 50.0].map((val) {
                    final isSelected = currentDiskon == val;
                    return InkWell(
                      onTap: () {
                        setSheetState(() {
                          currentDiskon = val;
                          ctrl.text = val > 0 ? val.toInt().toString() : '';
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF059669) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Text(
                          val == 0.0 ? '0% (Tanpa Diskon)' : '${val.toInt()}%',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text(
                  'ATAU INPUT PERSENTASE KHUSUS (%)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Contoh: 12.5',
                    prefixIcon: const Icon(Icons.percent_rounded, size: 18, color: Color(0xFF059669)),
                    suffixText: '%',
                    suffixStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                    ),
                  ),
                  onChanged: (val) {
                    final parsed = double.tryParse(val.trim()) ?? 0.0;
                    setSheetState(() {
                      currentDiskon = parsed.clamp(0.0, 100.0);
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Live Preview Calculation Card
                Builder(
                  builder: (context) {
                    final int baseSubtotal = (_o.subtotal > 0)
                        ? _o.subtotal
                        : (_o.services.isNotEmpty
                            ? _o.services.fold(0, (sum, s) => sum + s.subtotal)
                            : _o.total);
                    final int diskonRp = (baseSubtotal * (currentDiskon / 100)).round();
                    final int setelahDiskon = (baseSubtotal - diskonRp) > 0 ? (baseSubtotal - diskonRp) : 0;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Awal', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                              Text(_formatRupiah(baseSubtotal), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Diskon (${currentDiskon == currentDiskon.toInt() ? currentDiskon.toInt() : currentDiskon}%)',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF059669)),
                              ),
                              Text(
                                '- ${_formatRupiah(diskonRp)}',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Setelah Diskon', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                              Text(_formatRupiah(setelahDiskon), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final finalVal = double.tryParse(ctrl.text.trim()) ?? currentDiskon;
                    Navigator.pop(ctx, finalVal.clamp(0.0, 100.0));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Simpan Diskon',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (result != null && result != _o.diskonPersen) {
      final oldDiscount = _o.discount;
      setState(() {
        _o.discount = result.toInt();
        _isLoading = true;
      });

      try {
        await _orderService.updateDiskon(_o.id, result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Diskon ${result == result.toInt() ? result.toInt() : result}% berhasil disimpan'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
          _fetchDetail();
        }
      } catch (e) {
        if (mounted) {
          try {
            final draft = OrderDraft(
              customer: _o.customer,
              chatDari: _o.chatDari,
              tipeCustomer: _o.tipeCustomer,
              services: List.from(_o.services),
              cleaners: List.from(_o.cleaners),
              notes: _o.notes,
              applyPpn: (_o.ppn ?? _o.pembayaran?.ppn ?? 0) > 0,
              applyPph: (_o.pph ?? _o.pembayaran?.pph ?? 0) > 0,
              diskonPersen: result,
            );

            await _orderService.updateOrder(_o.id, draft);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Diskon ${result == result.toInt() ? result.toInt() : result}% berhasil disimpan'),
                  backgroundColor: const Color(0xFF059669),
                ),
              );
              _fetchDetail();
            }
          } catch (e2) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _o.discount = oldDiscount;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Gagal memperbarui diskon: $e2')),
              );
            }
          }
        }
      }
    }
  }

  String _formatDuration(DateTime start, DateTime end) {
    final diff = end.difference(start);
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    final seconds = diff.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}j ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
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
                  color: AppColors.surfaceBlue,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                'Ajukan Edit Layanan',
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
                'Status pesanan sudah selesai/diproses. Masukkan alasan pengajuan edit untuk disetujui Finance:',
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
                  hintText: 'Contoh: Maaf mbak ada salah input pembayaran / layanan...',
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
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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
                          await _orderService.submitPengajuanEdit(widget.order.id, reason);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Pengajuan edit layanan berhasil dikirim ke Finance!'),
                              backgroundColor: Color(0xFF059669),
                            ),
                          );
                          _fetchDetail();
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  Future<void> _toggleStatusBonus(OrderModel o) async {
    final isSelesai = o.statusBonus.toLowerCase() == 'selesai';
    final confirm = await AppConfirmationDialog.show(
      context,
      title: isSelesai ? 'Batal Selesai Bonus?' : 'Selesai Input Bonus?',
      message: isSelesai
          ? 'Apakah Anda yakin ingin membatalkan status selesai bonus ini (menjadi belum selesai)?'
          : 'Apakah Anda yakin sudah selesai menginput semua bonus cleaner untuk pesanan ini?',
      type: isSelesai ? ConfirmationDialogType.warning : ConfirmationDialogType.success,
      confirmText: isSelesai ? 'Ya, Batalkan' : 'Ya, Selesai',
      cancelText: 'Batal',
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _orderService.toggleStatusBonus(o.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSelesai
                ? 'Status bonus pesanan dibatalkan (Belum Selesai).'
                : 'Status bonus pesanan berhasil diubah menjadi Selesai.',
          ),
          backgroundColor: isSelesai ? const Color(0xFFD97706) : const Color(0xFF059669),
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
                padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 20 : 24),
                child: Column(
                  children: [
                    if (_isCancelled)
                      _buildCancellationBanner(o),
                    _buildCustomerCard(o),
                    const SizedBox(height: 12),
                    _buildServicesCard(o),
                    const SizedBox(height: 12),
                    if (o.cleaners.isNotEmpty) ...[
                      if (!widget.isReadOnly && !_isCancelled && o.cleaners.length > 1) ...[
                        _buildBeriBonusSekaligusButton(o),
                        const SizedBox(height: 12),
                      ],
                      ...o.cleaners
                          .expand(
                            (c) => [
                              _buildCleanerCard(o, c),
                              const SizedBox(height: 12),
                            ],
                          )
                          .take(o.cleaners.length * 2 - 1),
                      if (!widget.isReadOnly &&
                          !_isCancelled &&
                          o.services.any((s) => s.bonusLayanan > 0)) ...[
                        const SizedBox(height: 12),
                        _buildAlokasiBonusButton(o),
                      ],
                    ] else ...[
                      _buildEmptyCleanerCard(o),
                    ],
                    const SizedBox(height: 12),
                    _buildCleanerPhotosCard(o),
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
      padding: EdgeInsets.fromLTRB(20, 52, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 16 : 20),
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
                      o.customer.name,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!widget.isReadOnly && !_isCancelled) ...[
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
              const SizedBox(width: 8),
              InkWell(
                onTap: () => PdfInvoiceService.showPrintDialog(context, o),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.print_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        'Invoice',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
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

  Widget _buildCancellationBanner(OrderModel o) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFDC2626),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pesanan Dibatalkan',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  o.cancelReason != null && o.cancelReason!.trim().isNotEmpty
                      ? 'Alasan: ${o.cancelReason}'
                      : 'Pesanan telah dibatalkan oleh CS. Layanan, jadwal, dan alokasi bonus tidak dapat diubah.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFFB91C1C),
                  ),
                ),
              ],
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
                  onTap: () => _sendInvoiceWA(o),
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
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (o.customer.address.trim().isNotEmpty) {
                            _openMap(o.customer.address);
                          }
                        },
                        icon: const Icon(Icons.map_rounded, size: 18),
                        label: Text('Buka di Maps', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEFF6FF),
                          foregroundColor: const Color(0xFF2563EB),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
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
      trailingAction: _canEdit
          ? InkWell(
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
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Edit Layanan',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBlue.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Qty: ',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  s.qty.isNotEmpty ? s.qty : '1',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
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
              final int baseSubtotal = (o.subtotal > 0)
                  ? o.subtotal
                  : (o.services.isNotEmpty
                      ? o.services.fold(0, (sum, s) => sum + s.subtotal)
                      : o.total);
              final double diskonPersen = o.diskonPersen;
              final int diskonValue = (baseSubtotal * (diskonPersen / 100)).round();
              final int totalSetelahDiskon = (baseSubtotal - diskonValue) > 0 ? (baseSubtotal - diskonValue) : 0;

              final int ppnPersen = o.ppn ?? (o.pembayaran?.ppn ?? (o.isWajibPpn ? 11 : 0));
              final int ppnValue = (totalSetelahDiskon * (ppnPersen / 100))
                  .round();
              final int pphPersen = o.pph ?? o.pembayaran?.pph ?? 0;
              final int pphValue = (totalSetelahDiskon * (pphPersen / 100))
                  .round();
              final int totalAkhir = totalSetelahDiskon + ppnValue - pphValue;

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
                        _formatRupiah(baseSubtotal),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () {
                      if (!_isPaid) {
                        _showEditDiskonDialog();
                      }
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.local_offer_outlined,
                                size: 16,
                                color: diskonValue > 0 ? const Color(0xFF059669) : AppColors.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                diskonValue > 0
                                    ? 'Diskon ${diskonPersen == diskonPersen.toInt() ? diskonPersen.toInt() : diskonPersen}%'
                                    : 'Tambah Diskon',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: diskonValue > 0 ? FontWeight.w600 : FontWeight.normal,
                                  color: diskonValue > 0 ? const Color(0xFF059669) : AppColors.primary,
                                ),
                              ),
                              if (!_isPaid) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.edit_outlined,
                                  size: 13,
                                  color: diskonValue > 0 ? const Color(0xFF059669) : AppColors.primary,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            diskonValue > 0 ? '- ${_formatRupiah(diskonValue)}' : '0%',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: diskonValue > 0 ? const Color(0xFF059669) : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (diskonValue > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal Setelah Diskon',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          _formatRupiah(totalSetelahDiskon),
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'PPN terkunci sesuai cabang dan hanya dapat diatur saat pembayaran.',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 2,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Checkbox(
                                    value: ppnPersen > 0,
                                    onChanged: null, // Terkunci sesuai cabang
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    activeColor: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 2,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            'PPN (11%)',
                                            style: GoogleFonts.inter(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: ppnPersen > 0 ? AppColors.textDark : AppColors.textMuted,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: _o.isWajibPpn ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.lock_rounded, 
                                                  size: 9.5, 
                                                  color: _o.isWajibPpn ? const Color(0xFF1E40AF) : const Color(0xFF64748B),
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  _o.isWajibPpn ? 'Terkunci (Wajib PPN)' : 'Terkunci (Tanpa PPN)',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w600,
                                                    color: _o.isWajibPpn ? const Color(0xFF1E40AF) : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        ppnPersen > 0
                                            ? 'Dikenakan PPN 11% (Dapat diatur saat pembayaran)' 
                                            : 'Tanpa PPN (Dapat diatur saat pembayaran)',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: ppnPersen > 0 ? const Color(0xFF2563EB) : AppColors.textMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () {
                          if (!_isPaid) {
                            _togglePph();
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
                                pphPersen > 0
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                size: 18,
                                color: pphPersen > 0
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'PPh (2%)',
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
                        '- ${_formatRupiah(pphValue)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
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
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  if (!_isPaid) {
                    _showEditDiskonDialog();
                  }
                },
                icon: const Icon(
                  Icons.local_offer_rounded,
                  size: 16,
                  color: Color(0xFF059669),
                ),
                label: Text(
                  _o.diskonPersen > 0
                      ? 'Atur Diskon (${_o.diskonPersen == _o.diskonPersen.toInt() ? _o.diskonPersen.toInt() : _o.diskonPersen}%)'
                      : 'Atur / Tambah Diskon Pesanan',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF059669),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFF059669)),
                  backgroundColor: const Color(0xFFECFDF5),
                ),
              ),
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

  Widget _buildBeriBonusSekaligusButton(OrderModel o) {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
      useSafeArea: true,
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _AddBonusSheet(
            order: o,
            initialCleaner: null,
            onBonusAdded: _fetchDetail,
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              'Beri Bonus Sekaligus (${o.cleaners.length} Cleaner)',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2563EB),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanerCard(OrderModel o, OrderCleaner cleaner) {
    final isBonusSelesai = o.statusBonus.toLowerCase() == 'selesai';
    return _card(
      title: 'Petugas Kebersihan',
      trailingAction: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isBonusSelesai
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isBonusSelesai
                    ? const Color(0xFFA7F3D0)
                    : const Color(0xFFFDE68A),
              ),
            ),
            child: Text(
              isBonusSelesai ? 'Bonus Selesai' : 'Bonus Pending',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: isBonusSelesai
                    ? const Color(0xFF059669)
                    : const Color(0xFFD97706),
              ),
            ),
          ),
          if (_canEdit) ...[
            const SizedBox(width: 6),
            InkWell(
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
            ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                photoUrl: cleaner.fotoProfil,
                name: cleaner.name,
                size: 44,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(12),
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
                          if (cleaner.statusPengerjaan == CleanerWorkStatus.finished && cleaner.startedAt != null && cleaner.finishedAt != null) ...[
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDuration(cleaner.startedAt!, cleaner.finishedAt!),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!widget.isReadOnly && cleaner.phone.isNotEmpty) ...[
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => _sendTugasToCleanerWA(o, targetPhone: cleaner.phone, targetName: cleaner.name),
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
          if (!widget.isReadOnly && !_isCancelled) ...[
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
            // Action Buttons: Tambah Bonus & Selesai Input Bonus
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddBonusSheet(o, cleaner),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: Text(
                      'Tambah Bonus',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleStatusBonus(o),
                    icon: Icon(
                      o.statusBonus.toLowerCase() == 'selesai'
                          ? Icons.undo_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 16,
                    ),
                    label: Text(
                      o.statusBonus.toLowerCase() == 'selesai'
                          ? 'Batal Selesai'
                          : 'Selesai Bonus',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: o.statusBonus.toLowerCase() == 'selesai'
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFF059669),
                      foregroundColor: o.statusBonus.toLowerCase() == 'selesai'
                          ? const Color(0xFF475569)
                          : Colors.white,
                      elevation: 0,
                      side: o.statusBonus.toLowerCase() == 'selesai'
                          ? const BorderSide(color: Color(0xFFCBD5E1))
                          : null,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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

  void _showAddBonusSheet(OrderModel o, [OrderCleaner? cleaner]) {
    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => _AddBonusSheet(
        order: o,
        initialCleaner: cleaner,
        onBonusAdded: _fetchDetail,
      ),
    );
  }

  Widget _buildCleanerPhotosCard(OrderModel o) {
    if (o.cleaners.isEmpty) return const SizedBox();

    final int totalFotos = o.cleaners.fold(
      0,
      (sum, c) => sum + c.fotosStart.length + c.fotosFinish.length,
    );

    return _card(
      title: 'Foto Pengerjaan Cleaner',
      trailingAction: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          color: totalFotos > 0
              ? const Color(0xFFECFDF5)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: totalFotos > 0
                ? const Color(0xFFA7F3D0)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.camera_alt_rounded,
              size: 12,
              color: totalFotos > 0
                  ? const Color(0xFF059669)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 4),
            Text(
              'Total $totalFotos Foto',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: totalFotos > 0
                    ? const Color(0xFF059669)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...o.cleaners.map((c) {
            final int cleanerFotosCount = c.fotosStart.length + c.fotosFinish.length;

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cleaner header
                  Row(
                    children: [
                      InitialsAvatar(
                        name: c.name,
                        size: 38,
                        backgroundColor: const Color(0xFFEFF6FF),
                        textColor: const Color(0xFF2563EB),
                        borderColor: const Color(0xFFBFDBFE),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: GoogleFonts.inter(
                                fontSize: 14,
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
                                  'Status: ',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  c.statusPengerjaan.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: c.statusPengerjaan == CleanerWorkStatus.finished
                                        ? const Color(0xFF059669)
                                        : (c.statusPengerjaan == CleanerWorkStatus.inProgress
                                            ? const Color(0xFF2563EB)
                                            : const Color(0xFFD97706)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (cleanerFotosCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$cleanerFotosCount Foto',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 12),

                  // Section 1: Foto Mulai (Sebelum)
                  _buildPhotoSection(
                    title: 'Foto Mulai (Sebelum)',
                    icon: Icons.play_circle_outline_rounded,
                    accentColor: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                    timestamp: _formatPhotoDate(c.startedAt ?? (c.fotosStart.isNotEmpty ? c.fotosStart.first.createdAt : null)),
                    photos: c.fotosStart,
                    cleanerName: c.name,
                    emptyText: 'Belum ada foto mulai',
                  ),
                  const SizedBox(height: 12),

                  // Section 2: Foto Selesai (Sesudah)
                  _buildPhotoSection(
                    title: 'Foto Selesai (Sesudah)',
                    icon: Icons.check_circle_outline_rounded,
                    accentColor: const Color(0xFF059669),
                    bgColor: const Color(0xFFECFDF5),
                    timestamp: _formatPhotoDate(c.finishedAt ?? (c.fotosFinish.isNotEmpty ? c.fotosFinish.first.createdAt : null)),
                    photos: c.fotosFinish,
                    cleanerName: c.name,
                    emptyText: 'Belum ada foto selesai',
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPhotoSection({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required String timestamp,
    required List<CleanerFoto> photos,
    required String cleanerName,
    required String emptyText,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 13, color: accentColor),
                    const SizedBox(width: 5),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (timestamp != '-')
                Text(
                  timestamp,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (photos.isNotEmpty)
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final f = photos[idx];
                  final photoUrl = _resolvePhotoUrl(f.url.isNotEmpty ? f.url : f.path);

                  return GestureDetector(
                    onTap: () => _showPhotoModal(
                      context,
                      photoUrl,
                      '$title - $cleanerName (#${idx + 1})',
                      timestamp,
                    ),
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        color: const Color(0xFFE2E8F0),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 24),
                            ),
                          ),
                          Positioned(
                            bottom: 3,
                            right: 3,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.zoom_in_rounded, size: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.photo_outlined, size: 16, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(
                    emptyText,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: const Color(0xFF94A3B8),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _resolvePhotoUrl(String rawPath) {
    if (rawPath.startsWith('http://') || rawPath.startsWith('https://')) {
      return rawPath;
    }
    final cleanPath = rawPath.replaceFirst(RegExp(r'^/?storage/'), '');
    final baseUrl = ApiClient.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    return '$baseUrl/storage/$cleanPath';
  }

  String _formatPhotoDate(DateTime? dt) {
    if (dt == null) return '-';
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month];
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day $month $year $hour:$minute';
  }

  void _showPhotoModal(BuildContext context, String imageUrl, String title, [String? timestamp]) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.black.withValues(alpha: 0.5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (timestamp != null && timestamp != '-') ...[
                            const SizedBox(height: 2),
                            Text(
                              timestamp,
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(dialogCtx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 300,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(color: Colors.white),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            'Gagal memuat gambar',
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
              Flexible(
                child: Text(
                  title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingAction != null) ...[
                const SizedBox(width: 8),
                trailingAction,
              ],
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
        !_isCancelled &&
        o.cleaners.isNotEmpty &&
        o.status != OrderStatus.completed;
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
            onTap: () async {
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
                final confirm = await AppConfirmationDialog.show(
                  context,
                  title: 'Bonus Belum Diatur',
                  message: 'Anda belum mengatur alokasi bonus cleaner.\n\nYakin mau memberitahu cleaner sekarang? (Bonus tetap bisa diatur nanti)',
                  type: ConfirmationDialogType.warning,
                  confirmText: 'Yakin',
                  cancelText: 'Batal',
                );
                if (confirm == true) {
                  _notifyCleaner();
                }
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
            enabled: !_isCancelled,
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
            title: 'Cetak / Lihat PDF Invoice',
            subtitle: 'Pilih stempel & simpan tagihan dalam format PDF',
            icon: Icons.picture_as_pdf_rounded,
            color: const Color(0xFFE53935), // Red color for PDF
            isDone: false,
            enabled: true,
            onTap: () => PdfInvoiceService.showPrintDialog(context, o),
          ),
        ],

      ],
    );
  }

  void _showTambahLayananSheet(OrderModel o) {
    showModalBottomSheet(
      useSafeArea: true,
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
    final orderId = o.nomorPesanan.isNotEmpty ? o.nomorPesanan : o.id.toString();
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

    final int baseSubtotal = (o.subtotal > 0)
        ? o.subtotal
        : (o.services.isNotEmpty
            ? o.services.fold(0, (sum, s) => sum + s.subtotal)
            : o.total);
    final double diskonPersen = o.diskonPersen;
    int diskonValue = (baseSubtotal * (diskonPersen / 100)).round();
    if (diskonValue == 0 && o.pembayaran?.totalSetelahDiskon != null && o.pembayaran!.totalSetelahDiskon! > 0) {
      final diff = baseSubtotal - o.pembayaran!.totalSetelahDiskon!;
      if (diff > 0) diskonValue = diff;
    }
    final int totalSetelahDiskon = (baseSubtotal - diskonValue) > 0 ? (baseSubtotal - diskonValue) : 0;

    final int ppnPersen = o.ppn ?? (o.pembayaran?.ppn ?? (o.isWajibPpn ? 11 : 0));
    final int ppnValue = (o.pembayaran != null || o.ppn != null || o.isWajibPpn)
        ? (totalSetelahDiskon * (ppnPersen / 100)).round()
        : 0;
    final int pphPersen = o.pph ?? o.pembayaran?.pph ?? 0;
    final int pphValue = (totalSetelahDiskon * (pphPersen / 100)).round();
    final int totalAkhir = totalSetelahDiskon + ppnValue - pphValue;

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
Total Awal : ${_formatRupiah(baseSubtotal).replaceAll('Rp ', '')}
Diskon : ${diskonValue > 0 ? _formatRupiah(diskonValue).replaceAll('Rp ', '') : '0'}
PPn : ${_formatRupiah(ppnValue).replaceAll('Rp ', '')}
${pphValue > 0 ? 'PPh : -${_formatRupiah(pphValue).replaceAll('Rp ', '')}\n' : ''}*TOTAL BAYAR : ${_formatRupiah(totalAkhir).replaceAll(' ', '')}*
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
      if (mounted) {
        Navigator.pop(context, true);
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

  Future<void> _sendTugasToCleanerWA(OrderModel o, {String? targetPhone, String? targetName}) async {
    final branchName = o.customer.area.toUpperCase();
    final orderId = o.nomorPesanan.isNotEmpty ? o.nomorPesanan : o.id.toString();
    final customerName = o.customer.name;
    final address = o.customer.address;
    
    String rincian = '';
    for (int i = 0; i < o.services.length; i++) {
      final s = o.services[i];
      rincian += '${i + 1}. ${s.name} : ${s.qty}\n';
    }
    if (rincian.isEmpty) rincian = '-';

    final tglRaw = o.services.isNotEmpty ? o.services.first.tanggalPengerjaan : '';
    final waktu = o.services.isNotEmpty ? o.services.first.waktuPengerjaan : '-';

    final dateFmt = _formatWADate(tglRaw).split('|');
    final hari = dateFmt[0];
    final tanggal = dateFmt.length > 1 ? dateFmt[1] : '-';
    
    final keterangan = o.customer.notes.isNotEmpty ? o.customer.notes : o.notes.isNotEmpty ? o.notes : '-';
    
    String haloNames = '';
    List<String> cleanerNames = o.cleaners.map((c) => c.name).toList();
    if (cleanerNames.isEmpty) {
      haloNames = 'Tim Cleaner';
    } else if (cleanerNames.length == 1) {
      haloNames = cleanerNames[0];
    } else if (cleanerNames.length == 2) {
      haloNames = '${cleanerNames[0]} dan ${cleanerNames[1]}';
    } else {
      haloNames = '${cleanerNames.sublist(0, cleanerNames.length - 1).join(', ')}, dan ${cleanerNames.last}';
    }

    final message = '''Halo $haloNames, ada tugas baru untukmu! 
KLINKLIN $branchName
--------------------------------
No. Order : $orderId
Nama Customer : $customerName
Alamat : $address

Rincian Pesanan:
${rincian.trim()}

Hari : $hari
Waktu : $waktu
Tanggal : $tanggal
--------------------------------
Keterangan Order:
$keterangan

Semangat ya kerjanya! Tolong foto before after jangan lupa.''';

    final encodedMsg = Uri.encodeComponent(message);
    
    Uri url;
    if (targetPhone != null && targetPhone.isNotEmpty) {
      String phone = targetPhone.replaceAll(RegExp(r'\D'), '');
      if (phone.startsWith('0')) {
        phone = '62${phone.substring(1)}';
      }
      url = Uri.parse('https://wa.me/$phone?text=$encodedMsg');
    } else {
      url = Uri.parse('https://wa.me/?text=$encodedMsg');
    }
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
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
      useSafeArea: true,
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
      useSafeArea: true,
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
      useSafeArea: true,
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
                        availableCleaners = data.where((c) {
                          final status = (c['status'] ?? '').toString().toLowerCase();
                          final statusType = (c['status_type'] ?? '').toString().toLowerCase();
                          final statusLabel = (c['status_label'] ?? '').toString().toLowerCase();
                          return status != 'nonaktif' && statusType != 'nonaktif' && !statusLabel.contains('nonaktif');
                        }).toList();
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
              final status = (c['status'] ?? '').toString().toLowerCase();
              final statusType = (c['status_type'] ?? '').toString().toLowerCase();
              final statusLabel = (c['status_label'] ?? '').toString().toLowerCase();
              if (status == 'nonaktif' || statusType == 'nonaktif' || statusLabel.contains('nonaktif')) {
                return false;
              }
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
                    padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 8 : 12),
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
                              final statusLabel = c['status_label']?.toString() ?? 'Tersedia (Bebas)';
                              final statusType = c['status_type']?.toString().toLowerCase() ?? 'tersedia';
                              final bool isDisabled = c['is_disabled'] == true;

                              return GestureDetector(
                                onTap: () {
                                  if (isDisabled && !isSelected) {
                                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Cleaner sedang $statusLabel pada tanggal pengerjaan ini.'),
                                        backgroundColor: const Color(0xFFDC2626),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                    return;
                                  }

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
                                          : (isDisabled ? AppColors.border.withValues(alpha: 0.5) : AppColors.border),
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Opacity(
                                    opacity: isDisabled && !isSelected ? 0.65 : 1.0,
                                    child: Row(
                                      children: [
                                        AppAvatar(
                                          photoUrl: c['foto_profil']?.toString(),
                                          name: (c['name'] ?? c['nama'] ?? 'Cleaner').toString(),
                                          size: 44,
                                          shape: BoxShape.rectangle,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                (c['name'] ?? c['nama'] ?? '-').toString(),
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textDark,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              _buildCleanerStatusBadge(statusLabel, statusType),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: AppColors.primary,
                                            size: 22,
                                          ),
                                        if (isDisabled && !isSelected)
                                          const Icon(
                                            Icons.block_rounded,
                                            color: Color(0xFFDC2626),
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

  Widget _buildCleanerStatusBadge(String statusLabel, String statusType) {
    Color bg;
    Color text;
    Color border;

    final type = statusType.toLowerCase();
    if (type == 'libur' ||
        type.contains('cuti') ||
        type.contains('izin') ||
        type.contains('sakit') ||
        type == 'nonaktif' ||
        statusLabel.toLowerCase().contains('libur') ||
        statusLabel.toLowerCase().contains('cuti') ||
        statusLabel.toLowerCase().contains('izin') ||
        statusLabel.toLowerCase().contains('nonaktif')) {
      bg = const Color(0xFFFEF2F2);
      text = const Color(0xFFDC2626);
      border = const Color(0xFFFECACA);
    } else if (type == 'in_progress' ||
        statusLabel.toLowerCase().contains('sibuk') ||
        statusLabel.toLowerCase().contains('pengerjaan')) {
      bg = const Color(0xFFFFFBEB);
      text = const Color(0xFFD97706);
      border = const Color(0xFFFDE68A);
    } else if (type == 'finished' || statusLabel.toLowerCase().contains('selesai')) {
      bg = const Color(0xFFEFF6FF);
      text = const Color(0xFF2563EB);
      border = const Color(0xFFBFDBFE);
    } else if (type == 'assigned' || statusLabel.toLowerCase().contains('jadwal')) {
      bg = const Color(0xFFF1F5F9);
      text = const Color(0xFF475569);
      border = const Color(0xFFCBD5E1);
    } else {
      bg = const Color(0xFFECFDF5);
      text = const Color(0xFF059669);
      border = const Color(0xFFA7F3D0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: text,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            statusLabel,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: text,
            ),
          ),
        ],
      ),
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
      useSafeArea: true,
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
                    padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 12 : 16),
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
      useSafeArea: true,
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

      int? jenisBonusId;
      if (_selectedTarifBonus != null && _selectedTarifBonus!['jenis_bonus_id'] != null) {
        jenisBonusId = int.tryParse(_selectedTarifBonus!['jenis_bonus_id'].toString());
      } else {
        final manualTarif = _tarifBonuses.where(
          (t) => (t['jenis_bonus']?['nama_bonus']?.toString().toLowerCase() ?? '') == 'bonus manual',
        ).firstOrNull;
        if (manualTarif != null && manualTarif['jenis_bonus_id'] != null) {
          jenisBonusId = int.tryParse(manualTarif['jenis_bonus_id'].toString());
        } else if (_tarifBonuses.isNotEmpty && _tarifBonuses.first['jenis_bonus_id'] != null) {
          jenisBonusId = int.tryParse(_tarifBonuses.first['jenis_bonus_id'].toString());
        }
      }

      if (_selectedPesananCleanerIds.length == 1) {
        final cleaner = widget.order.cleaners.where((c) => c.pesananCleanerId == _selectedPesananCleanerIds.first).firstOrNull;
        final existing = cleaner?.bonuses.where((b) => b.jenisBonus.toLowerCase() == targetJenis.toLowerCase()).firstOrNull;

        if (existing != null && existing.id.isNotEmpty) {
          await _orderService.updateManualBonus(
            existing.id,
            nominalInt,
            note,
          );
        } else {
          await _orderService.assignManualBonuses(
            pesananId: widget.order.id,
            pesananCleanerIds: _selectedPesananCleanerIds.toList(),
            jenisBonusId: jenisBonusId,
            nominal: nominalInt,
            keterangan: note,
          );
        }
      } else {
        await _orderService.assignManualBonuses(
          pesananId: widget.order.id,
          pesananCleanerIds: _selectedPesananCleanerIds.toList(),
          jenisBonusId: jenisBonusId,
          nominal: nominalInt,
          keterangan: note,
        );
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
      useSafeArea: true,
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
