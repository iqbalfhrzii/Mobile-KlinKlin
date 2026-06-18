import 'package:flutter/material.dart';
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

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.order});
  final OrderModel order;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderService _orderService = OrderService();
  late OrderModel _o;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _o = widget.order;
    _fetchDetail();
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
    final hasAssignedCleaner = _o.cleaners.any((c) => c.statusPengerjaan == CleanerWorkStatus.assigned);
    
    if (!hasAssignedCleaner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua cleaner sudah dinotifikasi.'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _orderService.notifyCleaner(_o.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berhasil mengirim notifikasi ke cleaner!'), backgroundColor: AppColors.statusDone),
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
    final canEdit = o.status == OrderStatus.draft || o.status == OrderStatus.assigned;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context, o, canEdit),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  _buildCustomerCard(o),
                  const SizedBox(height: 12),
                  _buildServicesCard(o),
                  if (o.cleaners.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...o.cleaners.expand((c) => [_buildCleanerCard(c), const SizedBox(height: 12)]).take(o.cleaners.length * 2 - 1),
                    const SizedBox(height: 12),
                    _buildAlokasiBonusButton(o),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detail Pesanan', style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
                  )),
                  Text(o.id, style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.white.withOpacity(0.6),
                  )),
                ],
              ),
              const Spacer(),
              StatusBadge(status: o.status),
              if (canEdit) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CreateOrderScreen(existingOrder: o)),
                    );
                    if (result == true) {
                      _fetchDetail();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ],
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(backgroundColor: Colors.transparent, color: Colors.white),
            )
        ],
      ),
    );
  }

  Widget _buildCustomerCard(OrderModel o) {
    return _card(
      title: 'Info Pesanan',
      child: Row(
        children: [
          InitialsAvatar(name: o.customer.name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.customer.name, style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark,
                )),
                Text(o.customer.phone, style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textMuted,
                )),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o.customer.address, style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textDark,
                          )),
                          Text(o.customer.area, style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.textMuted,
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.surfaceBlue, borderRadius: BorderRadius.circular(4)),
                  child: Text('Sumber: ${o.chatDari.name} | Tipe: ${o.tipeCustomer.name}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.primary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesCard(OrderModel o) {
    return _card(
      title: 'Detail Layanan',
      child: Column(
        children: [
          ...o.services.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark,
                      )),
                      const SizedBox(height: 2),
                      Text('Qty: ${s.qty}', style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textMuted,
                      )),
                      Text('${s.tanggalPengerjaan} · ${s.waktuPengerjaan}', style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textMuted,
                      )),
                      if (s.bonusLayanan > 0)
                        Text('Bonus: ${_formatRupiah(s.bonusLayanan)}', style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.statusDone,
                        )),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_formatRupiah(s.subtotal), style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark,
                    )),
                    if (o.status == OrderStatus.draft || o.status == OrderStatus.assigned) ...[
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _showAturLayananSingleModal(o, s),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBlue,
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_note_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text('Atur Harga & Bonus', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          )),
          const Divider(height: 12, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark,
              )),
              Text(_formatRupiah(o.total), style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCleanerCard(OrderCleaner cleaner) {
    return _card(
      title: 'Petugas Kebersihan',
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.cleaning_services_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cleaner.name, style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark,
                )),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 2),
                    Text('${cleaner.rating}', style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textMuted,
                    )),
                  ],
                ),
                if (cleaner.totalBonus > 0)
                  Text('Total Bonus: ${_formatRupiah(cleaner.totalBonus)}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.statusDone)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cleaner.statusPengerjaan == CleanerWorkStatus.finished ? AppColors.statusDoneBg : AppColors.surfaceBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(cleaner.statusPengerjaan.name, style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: cleaner.statusPengerjaan == CleanerWorkStatus.finished ? AppColors.statusDone : AppColors.primary,
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(OrderModel o) {
    final isPaid = o.paymentStatus == 'paid';
    return _card(
      title: 'Status Pembayaran',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Metode', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(o.paymentMethod, style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark,
                    )),
                    const SizedBox(width: 8),
                    if (o.status == OrderStatus.draft || o.status == OrderStatus.assigned)
                      InkWell(
                        onTap: () => _showAturMetodePembayaran(o),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBlue,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_note_rounded, size: 12, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text('Atur', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
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
              color: isPaid ? AppColors.statusDoneBg : AppColors.statusPendingBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPaid ? AppColors.statusDone : AppColors.statusPending,
              ),
            ),
            child: Text(
              isPaid ? '✓ Lunas' : 'Belum Lunas',
              style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w700,
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
      child: Text(o.notes, style: GoogleFonts.inter(
        fontSize: 13, color: AppColors.textDark, height: 1.5,
      )),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
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
          Text(title.toUpperCase(), style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: AppColors.textMuted, letterSpacing: 0.5,
          )),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildProgressCard(OrderModel o) {
    final hasSchedule = o.services.isNotEmpty && o.services.first.tanggalPengerjaan.isNotEmpty && o.services.first.waktuPengerjaan.isNotEmpty;
    final hasCleaner = o.cleaners.isNotEmpty;
    final isPaid = o.paymentStatus == 'paid';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progress Pesanan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 16),
          _buildProgressItem('Atur Jadwal', 'Tanggal dan waktu pengerjaan', hasSchedule),
          const SizedBox(height: 16),
          _buildProgressItem('Tugaskan Cleaner', 'Cleaner yang akan bertugas', hasCleaner),
          const SizedBox(height: 16),
          _buildProgressItem('Status Pembayaran', 'Pelunasan tagihan', isPaid),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String title, String subtitle, bool isDone) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: isDone ? AppColors.statusDone.withOpacity(0.1) : AppColors.surfaceBlue,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle_rounded, color: isDone ? AppColors.statusDone : AppColors.primary.withOpacity(0.3), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isDone ? AppColors.statusDone : AppColors.textDark)),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(OrderModel o) {
    final hasSchedule = o.services.isNotEmpty && o.services.first.tanggalPengerjaan.isNotEmpty && o.services.first.waktuPengerjaan.isNotEmpty;
    final hasCleaner = o.cleaners.isNotEmpty;
    final showNotifyBtn = o.status == OrderStatus.assigned && o.cleaners.isNotEmpty;

    return Column(
      children: [
        _buildBigActionBtn(
          title: 'Atur Jadwal',
          subtitle: 'Tentukan tanggal & jam pengerjaan',
          icon: Icons.edit,
          color: AppColors.statusDone,
          enabled: true,
          onTap: () => _showAturJadwalModal(o),
        ),
        const SizedBox(height: 12),
        _buildBigActionBtn(
          title: o.cleaners.isEmpty ? 'Tugaskan Cleaner' : 'Ubah Cleaner',
          subtitle: 'Pilih cleaner yang akan bertugas',
          icon: Icons.edit,
          color: AppColors.statusDone,
          enabled: hasSchedule,
          onTap: () {
            if (!hasSchedule) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silakan Atur Jadwal terlebih dahulu.'), backgroundColor: AppColors.error));
              return;
            }
            _showAssignCleanerModal(o);
          },
        ),
        if (showNotifyBtn) ...[
          const SizedBox(height: 12),
          _buildBigActionBtn(
            title: 'Beritahu Cleaner',
            subtitle: 'Kirim notifikasi tugas',
            icon: Icons.notifications_active,
            color: AppColors.statusPending,
            enabled: true,
            onTap: _notifyCleaner,
          ),
        ],
        const SizedBox(height: 12),
        _buildBigActionBtn(
          title: 'Pembayaran',
          subtitle: 'Langsung menuju halaman pembayaran',
          icon: Icons.chevron_right,
          color: AppColors.primary,
          enabled: true,
          onTap: () {
            final hasUnpricedService = o.services.any((s) => s.subtotal <= 0);
            if (hasUnpricedService || o.total <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silakan atur harga untuk semua layanan terlebih dahulu.'), backgroundColor: AppColors.error));
              return;
            }
            Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentDetailScreen(order: o)));
          },
        ),
      ],
    );
  }

  Widget _buildBigActionBtn({required String title, required String subtitle, required IconData icon, required Color color, required bool enabled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: enabled ? color : color.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.8))),
                ],
              ),
            ),
            Icon(icon, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showAturJadwalModal(OrderModel o) async {
    final tglCtrl = TextEditingController(text: o.services.isNotEmpty ? o.services.first.tanggalPengerjaan : '');
    final waktuCtrl = TextEditingController(text: o.services.isNotEmpty ? o.services.first.waktuPengerjaan : '');

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
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(modalContext).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Atur Jadwal Pesanan', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 16),
              Text('Tanggal Pengerjaan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
                    tglCtrl.text = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Pilih Tanggal',
                  filled: true, fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  suffixIcon: const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),
              Text('Waktu Pengerjaan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
                    waktuCtrl.text = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Pilih Jam',
                  filled: true, fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  suffixIcon: const Icon(Icons.access_time_rounded, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(modalContext);
                  if (!mounted) return;
                  setState(() => _isLoading = true);
                  try {
                    final updatedServices = o.services.map((s) => ServiceItem(
                      id: s.id, layananId: s.layananId, name: s.name, price: s.price, qty: s.qty,
                      tanggalPengerjaan: tglCtrl.text,
                      waktuPengerjaan: waktuCtrl.text,
                      bonusLayanan: s.bonusLayanan,
                    )).toList();

                    final draft = OrderDraft(
                      customer: o.customer, chatDari: o.chatDari, tipeCustomer: o.tipeCustomer,
                      services: updatedServices, cleaners: o.cleaners, notes: o.notes,
                    );
                    await _orderService.updateOrder(o.id, draft);
                    if (!mounted) return;
                    _fetchDetail();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jadwal berhasil diperbarui!'), backgroundColor: AppColors.statusDone));
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Simpan Jadwal', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAturLayananSingleModal(OrderModel o, ServiceItem targetService) async {
    final qtyCtrl = TextEditingController(text: targetService.qty);
    final hargaCtrl = TextEditingController(text: targetService.price > 0 ? targetService.price.toString() : '');
    final bonusCtrl = TextEditingController(text: targetService.bonusLayanan > 0 ? targetService.bonusLayanan.toString() : '');

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
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(modalContext).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('Atur Detail: ${targetService.name}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Qty', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: qtyCtrl,
                      decoration: InputDecoration(
                        hintText: 'Misal: 3 jam 2 cleaner',
                        filled: true, fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Harga (Rp)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: hargaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Masukkan Harga...',
                        prefixText: 'Rp ',
                        filled: true, fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Bonus Layanan (Rp)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: bonusCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Opsional...',
                        prefixText: 'Rp ',
                        filled: true, fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      if (s.id == targetService.id && s.name == targetService.name) {
                        return ServiceItem(
                          id: s.id,
                          layananId: s.layananId,
                          name: s.name,
                          price: int.tryParse(hargaCtrl.text) ?? 0,
                          qty: qtyCtrl.text.isNotEmpty ? qtyCtrl.text : s.qty,
                          tanggalPengerjaan: s.tanggalPengerjaan,
                          waktuPengerjaan: s.waktuPengerjaan,
                          bonusLayanan: int.tryParse(bonusCtrl.text) ?? 0,
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Layanan berhasil diperbarui!'), backgroundColor: AppColors.statusDone));
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Simpan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAssignCleanerModal(OrderModel o) async {
    List<Map<String, dynamic>> availableCleaners = [];
    bool isLoading = true;
    String? error;
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
              final tanggal = service?.toJson()['tanggal_pengerjaan']?.toString();
              final waktu = service?.toJson()['waktu_pengerjaan']?.toString();
              _orderService.fetchAvailableCleaners(tanggal: tanggal, waktu: waktu).then((data) {
                if (mounted) {
                  setStateModal(() {
                    availableCleaners = data;
                    isLoading = false;
                  });
                }
              }).catchError((e) {
                if (mounted) {
                  setStateModal(() {
                    error = e.toString();
                    isLoading = false;
                  });
                }
              });
            }

            return Container(
              height: MediaQuery.of(innerContext).size.height * 0.75,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Pilih Cleaner', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        GestureDetector(onTap: () => Navigator.pop(modalContext), child: const Icon(Icons.close, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  Expanded(
                    child: isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : error != null
                        ? Center(child: Text(error!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center))
                        : availableCleaners.isEmpty
                          ? Center(child: Text('Tidak ada cleaner tersedia.', style: GoogleFonts.inter(color: AppColors.textMuted)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: availableCleaners.length,
                              itemBuilder: (listContext, index) {
                                final c = availableCleaners[index];
                                final isSelected = selectedIds.contains(c['id']);
                                final statusPengerjaan = c['status_pengerjaan']?.toString() ?? 'free';
                                final isBusy = statusPengerjaan == 'notified' || statusPengerjaan == 'in_progress';
                                
                                return GestureDetector(
                                  onTap: isBusy ? null : () {
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
                                      color: isSelected ? AppColors.surfaceBlue : AppColors.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                                    ),
                                    child: Opacity(
                                      opacity: isBusy ? 0.5 : 1.0,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44, height: 44,
                                            decoration: BoxDecoration(color: AppColors.surfaceBlue, borderRadius: BorderRadius.circular(12)),
                                            child: const Icon(Icons.cleaning_services_rounded, color: AppColors.primary, size: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(c['name'] as String, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                                                    const SizedBox(width: 2),
                                                    Text('${c['rating']}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: !isBusy ? AppColors.statusDone.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        statusPengerjaan.toUpperCase(),
                                                        style: GoogleFonts.inter(
                                                          fontSize: 10,
                                                          color: !isBusy ? AppColors.statusDone : AppColors.error,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isSelected)
                                            const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
                                          if (isBusy)
                                            const Icon(Icons.block, color: AppColors.error, size: 20),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(innerContext).padding.bottom + 12),
                    decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading || error != null ? null : () async {
                          Navigator.pop(modalContext);
                          if (!mounted) return;
                          setState(() => _isLoading = true);
                          try {
                            await _orderService.assignCleaner(o.id, selectedIds);
                            if (!mounted) return;
                            _fetchDetail();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil menugaskan cleaner!'), backgroundColor: AppColors.statusDone));
                          } catch (e) {
                            if (!mounted) return;
                            setState(() => _isLoading = false);
                            final errorMsg = e.toString().replaceAll('Exception: ', '');
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: AppColors.error));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Simpan Penugasan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
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
        icon: const Icon(Icons.card_giftcard_rounded, size: 18, color: AppColors.primary),
        label: Text('Alokasikan Bonus Layanan', style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary,
        )),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: AppColors.primary),
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
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Alokasi Bonus Layanan', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        GestureDetector(onTap: () => Navigator.pop(modalContext), child: const Icon(Icons.close, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: o.services.where((s) => s.bonusLayanan > 0).map((s) {
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(s.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                  Text(_formatRupiah(s.bonusLayanan), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.statusDone)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Pilih Cleaner Penerima:', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: allocations[s.id],
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
                                    items: o.cleaners.map((c) {
                                      return DropdownMenuItem<String>(
                                        value: c.id,
                                        child: Text(c.name, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setStateModal(() => allocations[s.id] = val);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(modalContext).padding.bottom + 12),
                    decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(modalContext);
                          if (!mounted) return;
                          setState(() => _isLoading = true);
                          try {
                            final items = allocations.entries.map((e) => {
                              'detail_pesanan_id': int.parse(e.key),
                              'pesanan_cleaner_id': int.parse(e.value),
                            }).toList();

                            await _orderService.allocateBonusLayanan(o.id, items);
                            if (!mounted) return;
                            _fetchDetail();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bonus layanan berhasil dialokasikan!'), backgroundColor: AppColors.statusDone));
                          } catch (e) {
                            if (!mounted) return;
                            setState(() => _isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Simpan Alokasi', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
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
      {'id': 'Transfer Bank', 'icon': Icons.account_balance_rounded, 'desc': 'BCA, Mandiri, BRI, dll'},
      {'id': 'QRIS', 'icon': Icons.qr_code_scanner_rounded, 'desc': 'Scan QR di kasir'},
      {'id': 'Tunai', 'icon': Icons.payments_rounded, 'desc': 'Bayar langsung ke petugas'},
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
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Pilih Metode Pembayaran', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
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
                    decoration: BoxDecoration(color: AppColors.surfaceBlue, borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: AppColors.primary),
                  ),
                  title: Text(id, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  subtitle: Text(desc, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('order_payment_method_${o.id}', id);
                    setState(() {
                      o.paymentMethod = id;
                    });
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Metode pembayaran dipilih sementara'), backgroundColor: AppColors.statusPending));
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
