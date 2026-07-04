import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/data/order_model.dart';
import '../../../core/data/customer_model.dart';
import '../../../core/services/customer_service.dart';
import '../services/order_service.dart';
import '../../../core/api/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key, this.existingOrder});
  final OrderModel? existingOrder;

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final OrderService _orderService = OrderService();
  int _step = 0; // 0=info, 1=services, 2=summary
  final _draft = OrderDraft();
  bool _isSaving = false;

  static const _steps = ['Info Pesanan', 'Detail Layanan', 'Pilih Cleaner', 'Ringkasan'];

  @override
  void initState() {
    super.initState();
    if (widget.existingOrder != null) {
      final o = widget.existingOrder!;
      _draft.customer = o.customer;
      _draft.chatDari = o.chatDari;
      _draft.tipeCustomer = o.tipeCustomer;
      _draft.notes = o.notes;
      _draft.services = List.from(o.services);
      _draft.cleaners = List.from(o.cleaners);
      _draft.applyPpn = (o.ppn ?? o.pembayaran?.ppn ?? 11) > 0;
      // Cleaners cannot be edited through this form according to API (only assign cleaner endpoint)
    }
  }

  void _next() => setState(() => _step = (_step + 1).clamp(0, 3));
  void _prev() {
    if (_step == 0) { Navigator.pop(context); return; }
    setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          _buildStepper(),
          Expanded(child: _buildStep()),
          _buildNavButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
      child: Row(
        children: [
          HeaderBackButton(onTap: _prev),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existingOrder == null ? 'Buat Pesanan Baru' : 'Edit Pesanan', style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
              )),
              Text('Langkah ${_step + 1} dari 3 · ${_steps[_step]}', style: GoogleFonts.inter(
                fontSize: 11, color: Colors.white.withOpacity(0.7),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        children: List.generate(_steps.length, (i) {
          final done = i < _step;
          final active = i == _step;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: done ? AppColors.statusDone : active ? AppColors.primary : AppColors.surfaceBlue,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: done
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : Text('${i + 1}', style: GoogleFonts.inter(
                                fontSize: 11, fontWeight: FontWeight.bold,
                                color: active ? Colors.white : AppColors.textMuted,
                              )),
                      ),
                      const SizedBox(height: 4),
                      Text(_steps[i], style: GoogleFonts.inter(
                        fontSize: 9,
                        color: active ? AppColors.primary : AppColors.textMuted,
                        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      ), textAlign: TextAlign.center,),
                    ],
                  ),
                ),
                if (i < _steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 18),
                      color: done ? AppColors.statusDone : AppColors.border,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _Step1Info(draft: _draft, onChanged: () => setState(() {}));
      case 1: return _Step2Services(draft: _draft, onChanged: () => setState(() {}));
      case 2: return _Step3Cleaner(draft: _draft, onChanged: () => setState(() {}));
      case 3: return _Step4Summary(draft: _draft);
      default: return const SizedBox();
    }
  }

  Widget _buildNavButtons() {
    final canNext = switch (_step) {
      0 => _draft.customer != null,
      1 => _draft.services.isNotEmpty,
      _ => true,
    };

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (_step > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _prev,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: AppColors.primary),
                ),
                child: Text('Kembali', style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary,
                )),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: (canNext && !_isSaving) ? (_step == 3 ? _submit : _next) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.border,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: canNext && !_isSaving ? 4 : 0,
                shadowColor: AppColors.primary.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving 
                ? const SizedBox(
                    width: 20, height: 20, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_step == 3 ? 'Simpan' : 'Lanjut', style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white,
                      )),
                      if (_step < 3) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                      ],
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    try {
      if (widget.existingOrder == null) {
        final orderId = await _orderService.createOrder(_draft);
        if (_draft.cleaners.isNotEmpty) {
          await _orderService.assignCleaner(orderId, _draft.cleaners.map((c) => c.id).toList());
        }
      } else {
        await _orderService.updateOrder(widget.existingOrder!.id, _draft);
        if (_draft.cleaners.isNotEmpty) {
          await _orderService.assignCleaner(widget.existingOrder!.id, _draft.cleaners.map((c) => c.id).toList());
        }
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existingOrder == null ? 'Pesanan berhasil dibuat!' : 'Pesanan berhasil diperbarui!', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppColors.statusDone,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString(), style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ─── Step 1: Info Pesanan ─────────────────────────────────────────────────
class _Step1Info extends StatefulWidget {
  const _Step1Info({required this.draft, required this.onChanged});
  final OrderDraft draft;
  final VoidCallback onChanged;

  @override
  State<_Step1Info> createState() => _Step1InfoState();
}

class _Step1InfoState extends State<_Step1Info> {
  List<CustomerModel> _customers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final data = await CustomerService.getCustomers();
      if (mounted) {
        setState(() {
          // Filter ONLY active customers directly
          _customers = data.where((c) => c.status.toLowerCase() == 'aktif').toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showCustomerSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomerSearchSheet(
        customers: _customers,
        selectedId: widget.draft.customer?.id,
        onSelect: (c) {
          widget.draft.customer = OrderCustomer(id: c.id, name: c.name, phone: c.phone, address: c.address, area: '-');
          widget.onChanged();
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data Pelanggan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 12),
          
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.primary)))
          else if (_error != null)
            Center(child: Padding(padding: EdgeInsets.all(20), child: Text(_error!, style: const TextStyle(color: AppColors.error))))
          else
            GestureDetector(
              onTap: _showCustomerSearchSheet,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.draft.customer == null ? AppColors.surface : AppColors.surfaceBlue.withOpacity(0.5),
                  border: Border.all(color: widget.draft.customer == null ? AppColors.border : AppColors.primary),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: widget.draft.customer == null ? [AppColors.cardShadow] : [],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: widget.draft.customer == null ? AppColors.background : AppColors.primary, shape: BoxShape.circle),
                      child: Icon(Icons.person_outline, color: widget.draft.customer == null ? AppColors.textMuted : Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: widget.draft.customer == null
                          ? Text('Pilih Pelanggan...', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.draft.customer!.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                const SizedBox(height: 4),
                                Text(widget.draft.customer!.phone, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                              ],
                            ),
                    ),
                    Icon(Icons.chevron_right, color: widget.draft.customer == null ? AppColors.textMuted : AppColors.primary),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),
          Text('Cabang Pemroses', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_rounded, color: AppColors.textMuted, size: 20),
                const SizedBox(width: 12),
                Text('Surabaya', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark)),
                const Spacer(),
                const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 16),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text('Sumber Chat', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 8),
          Row(
            children: ChatSource.values.map((e) {
              final active = widget.draft.chatDari == e;
              return Expanded(
                child: GestureDetector(
                  onTap: () { widget.draft.chatDari = e; widget.onChanged(); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: e == ChatSource.values.last ? 0 : 8),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary.withOpacity(0.08) : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: active ? AppColors.primary : AppColors.border, width: active ? 1.5 : 1),
                    ),
                    child: Center(
                      child: Text(e.name.toUpperCase(), style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? AppColors.primary : AppColors.textMuted,
                      )),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),
          Text('Tipe Customer', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 8),
          Row(
            children: CustomerType.values.map((e) {
              final active = widget.draft.tipeCustomer == e;
              return Expanded(
                child: GestureDetector(
                  onTap: () { widget.draft.tipeCustomer = e; widget.onChanged(); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: e == CustomerType.values.last ? 0 : 12),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary.withOpacity(0.08) : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: active ? AppColors.primary : AppColors.border, width: active ? 1.5 : 1),
                    ),
                    child: Center(
                      child: Text(e.name.toUpperCase(), style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? AppColors.primary : AppColors.textMuted,
                      )),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),
          Text('Keterangan Order', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: widget.draft.notes,
            maxLines: 3,
            onChanged: (v) { widget.draft.notes = v; widget.onChanged(); },
            decoration: InputDecoration(
              hintText: 'Opsional...',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerSearchSheet extends StatefulWidget {
  const _CustomerSearchSheet({required this.customers, this.selectedId, required this.onSelect});
  final List<CustomerModel> customers;
  final String? selectedId;
  final ValueChanged<CustomerModel> onSelect;

  @override
  State<_CustomerSearchSheet> createState() => _CustomerSearchSheetState();
}

class _CustomerSearchSheetState extends State<_CustomerSearchSheet> {
  String _query = '';

  List<CustomerModel> get _filtered => widget.customers.where((c) {
    final q = _query.toLowerCase();
    return c.name.toLowerCase().contains(q) || c.phone.contains(q) || c.address.toLowerCase().contains(q);
  }).toList();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                Text('Pilih Pelanggan Aktif', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: AppColors.textMuted)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cari nama, nomor HP, atau alamat...',
                hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _filtered.isEmpty
                ? Center(child: Text('Tidak ada pelanggan aktif ditemukan.', style: GoogleFonts.inter(color: AppColors.textMuted)))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = _filtered[i];
                      final selected = widget.selectedId == c.id;
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                        ),
                        tileColor: selected ? AppColors.surfaceBlue : AppColors.surface,
                        leading: InitialsAvatar(name: c.name, size: 40, backgroundColor: selected ? AppColors.primary : AppColors.surfaceBlue, textColor: selected ? Colors.white : AppColors.primary),
                        title: Text(c.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.phone_android, size: 12, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(c.phone, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Expanded(child: Text(c.address, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ],
                        ),
                        trailing: selected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                        onTap: () => widget.onSelect(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 2: Detail Layanan ─────────────────────────────────────────────────
class _Step2Services extends StatelessWidget {
  const _Step2Services({required this.draft, required this.onChanged});
  final OrderDraft draft;
  final VoidCallback onChanged;

  void _showAddServiceSheet(BuildContext context, {ServiceItem? existing, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddServiceSheet(
        existing: existing,
        onSave: (item) {
          if (index != null) draft.services[index] = item;
          else draft.services.add(item);
          onChanged();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showAddServiceSheet(context),
            icon: const Icon(Icons.add, color: AppColors.primary),
            label: Text('Tambah Layanan', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.primary)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceBlue,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.primary)),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
        Expanded(
          child: draft.services.isEmpty
              ? Center(child: Text('Belum ada layanan yang ditambahkan', style: GoogleFonts.inter(color: AppColors.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: draft.services.length,
                  itemBuilder: (_, i) {
                    final s = draft.services[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [AppColors.cardShadow],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceBlue.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.cleaning_services_rounded, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.tag, size: 12, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                    Text('Qty: ${s.qty}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () => _showAddServiceSheet(context, existing: s, index: i),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                  child: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      title: Text('Hapus Layanan?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                                      content: Text('Apakah Anda yakin ingin menghapus layanan ini dari pesanan?', style: GoogleFonts.inter(fontSize: 14)),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            draft.services.removeAt(i);
                                            onChanged();
                                          },
                                          child: Text('Hapus', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w600)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                  child: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AddServiceSheet extends StatefulWidget {
  const _AddServiceSheet({this.existing, required this.onSave});
  final ServiceItem? existing;
  final Function(ServiceItem) onSave;

  @override
  State<_AddServiceSheet> createState() => _AddServiceSheetState();
}

class _AddServiceSheetState extends State<_AddServiceSheet> {
  List<Map<String, dynamic>> _availableServices = [];
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _selectedLayanan;
  final _qtyCtrl = TextEditingController();
  final _hargaCtrl = TextEditingController();
  final _tglCtrl = TextEditingController();
  final _waktuCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLayanan();
    if (widget.existing != null) {
      _qtyCtrl.text = widget.existing!.qty;
      _hargaCtrl.text = widget.existing!.price.toString();
      _tglCtrl.text = widget.existing!.tanggalPengerjaan;
      _waktuCtrl.text = widget.existing!.waktuPengerjaan;
    }
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
             if (widget.existing != null) {
               _selectedLayanan = _availableServices.firstWhere(
                 (e) => e['nama_layanan'] == widget.existing!.name, 
                 orElse: () => _availableServices.first
               );
             } else {
               _selectedLayanan = _availableServices.first;
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
    if (_qtyCtrl.text.isEmpty || _selectedLayanan == null) {
      return;
    }
    widget.onSave(ServiceItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      layananId: _selectedLayanan!['id']?.toString() ?? '1',
      name: _selectedLayanan!['nama_layanan'],
      price: int.tryParse(_hargaCtrl.text) ?? 0,
      qty: _qtyCtrl.text,
      tanggalPengerjaan: _tglCtrl.text,
      waktuPengerjaan: _waktuCtrl.text,
      bonusLayanan: 0,
    ));
    Navigator.pop(context);
  }

  Widget build(BuildContext context) {
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.existing == null ? 'Tambah Layanan' : 'Edit Layanan', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _label('Layanan'),
            if (_isLoading)
               const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
            else if (_error != null)
               Text(_error!, style: const TextStyle(color: AppColors.error))
            else if (_availableServices.isEmpty)
               const Text('Tidak ada layanan di cabang ini.')
            else 
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _selectedLayanan,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
              items: _availableServices.map((e) => DropdownMenuItem(value: e, child: Text(e['nama_layanan'], style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark)))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectedLayanan = v;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            _label('Harga Layanan (Rp)'),
            _textField(_hargaCtrl, type: TextInputType.number, hint: 'Contoh: 150000'),
            const SizedBox(height: 12),
            _label('Tanggal Pengerjaan'),
            _dateField(context, _tglCtrl, hint: 'Pilih Tanggal'),
            const SizedBox(height: 12),
            _label('Waktu Pengerjaan'),
            _timeField(context, _waktuCtrl, hint: 'Pilih Waktu (contoh: 09:00 - 12:00)'),
            const SizedBox(height: 12),
            _label('Qty (Contoh: 3 jam 2 cleaner)'),
            _textField(_qtyCtrl, hint: 'Teks bebas...'),
            const SizedBox(height: 12),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                elevation: 4,
                shadowColor: AppColors.primary.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Simpan', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _label(String text) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)));
  Widget _textField(TextEditingController ctrl, {TextInputType type = TextInputType.text, String hint = ''}) => TextField(
    controller: ctrl, keyboardType: type, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark), decoration: InputDecoration(hintText: hint, hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14), filled: true, fillColor: AppColors.surface, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5))),
  );

  Widget _dateField(BuildContext context, TextEditingController ctrl, {String hint = ''}) {
    return TextField(
      controller: ctrl,
      readOnly: true,
      onTap: () async {
        final initial = DateTime.tryParse(ctrl.text) ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          ctrl.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
        }
      },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textMuted),
      ),
    );
  }

  Widget _timeField(BuildContext context, TextEditingController ctrl, {String hint = ''}) {
    return TextField(
      controller: ctrl,
      readOnly: true,
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (picked != null) {
          final hr = picked.hour.toString().padLeft(2, '0');
          final mn = picked.minute.toString().padLeft(2, '0');
          ctrl.text = "$hr:$mn";
        }
      },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        suffixIcon: const Icon(Icons.access_time_rounded, size: 18, color: AppColors.textMuted),
      ),
    );
  }
}

// ─── Step 3: Pilih Cleaner ─────────────────────────────────────────────────────
class _Step3Cleaner extends StatefulWidget {
  const _Step3Cleaner({required this.draft, required this.onChanged});
  final OrderDraft draft;
  final VoidCallback onChanged;

  @override
  State<_Step3Cleaner> createState() => _Step3CleanerState();
}

class _Step3CleanerState extends State<_Step3Cleaner> {
  List<Map<String, dynamic>> _availableCleaners = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCleaners();
  }

  Future<void> _fetchCleaners() async {
    try {
      // Typically fetch from HrdService, we can import it or use OrderService if we add it
      // Let's assume we can use a basic Dio call here or add fetchCleaners to OrderService
      // Wait, we can't easily fetch without HrdService. We'll use HrdService.
      final hrdService = _HrdServiceStub();
      final prefs = await SharedPreferences.getInstance();
      final cabangId = prefs.getInt('user_cabang_id') ?? 1;
      
      final data = await hrdService.fetchCleaners(cabangId);
      if (mounted) {
        setState(() {
          _availableCleaners = data;
          _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)));
    if (_availableCleaners.isEmpty) return const Center(child: Text('Tidak ada cleaner tersedia.'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _availableCleaners.length,
      itemBuilder: (context, index) {
        final c = _availableCleaners[index];
        final idStr = c['id'].toString();
        // Since draft.cleaners is a List<OrderCleaner>, we'll just check if it's there
        final isSelected = widget.draft.cleaners.any((x) => x.id == idStr);

        return ListTile(
          onTap: () {
            setState(() {
              if (isSelected) {
                widget.draft.cleaners.removeWhere((x) => x.id == idStr);
              } else {
                widget.draft.cleaners.add(OrderCleaner(
                  id: idStr,
                  pesananCleanerId: '',
                  name: c['name'] ?? c['nama'] ?? 'Unknown',
                  rating: c['rating'] != null ? double.tryParse(c['rating'].toString()) ?? 0.0 : 0.0,
                  statusPengerjaan: CleanerWorkStatus.assigned,
                  totalBonus: 0,
                  bonuses: [],
                ));
              }
              widget.onChanged();
            });
          },
          tileColor: isSelected ? AppColors.surfaceBlue : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
          ),
          leading: Icon(Icons.person, color: isSelected ? AppColors.primary : AppColors.textMuted),
          title: Text(c['name'] ?? c['nama'] ?? '-', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
        );
      },
    );
  }
}

class _HrdServiceStub {
  Future<List<Map<String, dynamic>>> fetchCleaners(int cabangId) async {
    final svc = OrderService();
    // Assuming fetchAvailableCleaners exists in OrderService
    return await svc.fetchAvailableCleaners();
  }
}

// ─── Step 4: Ringkasan ─────────────────────────────────────────────────────
class _Step4Summary extends StatefulWidget {
  const _Step4Summary({required this.draft});
  final OrderDraft draft;

  @override
  State<_Step4Summary> createState() => _Step4SummaryState();
}

class _Step4SummaryState extends State<_Step4Summary> {
  @override
  Widget build(BuildContext context) {
    final int subtotal = widget.draft.total;
    final int ppn = widget.draft.applyPpn ? (subtotal * 0.11).round() : 0;
    final int totalAkhir = subtotal + ppn;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryCard(title: 'Data Pelanggan', child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Nama', widget.draft.customer?.name ?? '-'),
              const SizedBox(height: 8),
              _infoRow('Telepon', widget.draft.customer?.phone ?? '-'),
              const SizedBox(height: 8),
              _infoRow('Alamat', widget.draft.customer?.address ?? '-'),
              const SizedBox(height: 8),
              const Divider(color: AppColors.border),
              const SizedBox(height: 8),
              _infoRow('Cabang', 'Surabaya'),
              const SizedBox(height: 8),
              _infoRow('Sumber Chat', widget.draft.chatDari.name.toUpperCase()),
              const SizedBox(height: 8),
              _infoRow('Tipe Customer', widget.draft.tipeCustomer.name.toUpperCase()),
              if (widget.draft.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                _infoRow('Keterangan', widget.draft.notes),
              ]
            ],
          )),
          const SizedBox(height: 12),
          _SummaryCard(
            title: 'Layanan Terpilih',
            child: widget.draft.services.isEmpty
                ? Text('Belum ada layanan yang dipilih.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...widget.draft.services.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(s.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark))),
                          Text('Rp ${s.price}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Qty: ${s.qty}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                      if (s.tanggalPengerjaan.isNotEmpty || s.waktuPengerjaan.isNotEmpty)
                        const SizedBox(height: 4),
                      if (s.tanggalPengerjaan.isNotEmpty || s.waktuPengerjaan.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text('${s.tanggalPengerjaan} ${s.waktuPengerjaan}'.trim(), style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary)),
                          ],
                        ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (widget.draft.cleaners.isNotEmpty) ...[
            _SummaryCard(
              title: 'Petugas Kebersihan Terpilih',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...widget.draft.cleaners.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(c.name, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _SummaryCard(
            title: 'Ringkasan Biaya',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                    Text('Rp $subtotal', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: widget.draft.applyPpn,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  widget.draft.applyPpn = val;
                                });
                              }
                            },
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            activeColor: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('PPN (11%)', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                      ],
                    ),
                    Text('Rp $ppn', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w500)),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: AppColors.border),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    Text('Rp $totalAkhir', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Pesanan Anda akan disimpan beserta jadwal dan penugasan cleaner yang telah dipilih.', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark))),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 100, child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))),
        const Text(': ', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textDark))),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border), boxShadow: [AppColors.cardShadow]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
