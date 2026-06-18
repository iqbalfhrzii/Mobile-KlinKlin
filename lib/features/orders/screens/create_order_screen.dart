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

  static const _steps = ['Info Pesanan', 'Detail Layanan', 'Ringkasan'];

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
      // Cleaners cannot be edited through this form according to API (only assign cleaner endpoint)
    }
  }

  void _next() => setState(() => _step = (_step + 1).clamp(0, 2));
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
      case 2: return _Step3Summary(draft: _draft);
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
              onPressed: (canNext && !_isSaving) ? (_step == 2 ? _submit : _next) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.border,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isSaving 
                ? const SizedBox(
                    width: 20, height: 20, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                : Text(
                    _step == 2 ? (widget.existingOrder == null ? '✓ Buat Pesanan' : '✓ Simpan Perubahan') : 'Lanjut →',
                    style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white,
                    ),
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
        await _orderService.createOrder(_draft);
      } else {
        await _orderService.updateOrder(widget.existingOrder!.id, _draft);
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
  String _query = '';
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
          _customers = data;
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

  List<CustomerModel> get _filtered => _customers.where((c) {
    final q = _query.toLowerCase();
    return c.name.toLowerCase().contains(q) || c.phone.contains(q) || c.address.toLowerCase().contains(q);
  }).toList();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pilih Pelanggan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Cari nama, nomor HP, atau alamat...',
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading) const Center(child: CircularProgressIndicator())
          else if (_error != null) Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
          else Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final c = _filtered[i];
                final selected = widget.draft.customer?.id == c.id;
                final isAktif = c.status.toLowerCase() == 'aktif';
                return ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  tileColor: selected ? AppColors.surfaceBlue : null,
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      InitialsAvatar(name: c.name, size: 36, backgroundColor: selected ? AppColors.primary : AppColors.surfaceBlue, textColor: selected ? Colors.white : AppColors.primary),
                      Positioned(bottom: -2, right: -2, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: isAktif ? AppColors.statusDone : AppColors.statusCancel, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)))),
                    ],
                  ),
                  title: Text(c.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  subtitle: Text(c.phone, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  trailing: selected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                  onTap: () {
                    widget.draft.customer = OrderCustomer(id: c.id, name: c.name, phone: c.phone, address: c.address, area: '-');
                    widget.onChanged();
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 20),
          Text('Sumber Chat', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ChatSource>(
                value: widget.draft.chatDari,
                isExpanded: true,
                items: ChatSource.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
                onChanged: (v) {
                  if (v != null) { widget.draft.chatDari = v; widget.onChanged(); }
                },
              ),
            ),
          ),

          const SizedBox(height: 16),
          Text('Tipe Customer', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CustomerType>(
                value: widget.draft.tipeCustomer,
                isExpanded: true,
                items: CustomerType.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
                onChanged: (v) {
                  if (v != null) { widget.draft.tipeCustomer = v; widget.onChanged(); }
                },
              ),
            ),
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

  String _formatRupiah(int n) =>
      'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

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
        Expanded(
          child: draft.services.isEmpty
              ? Center(child: Text('Belum ada layanan yang ditambahkan', style: GoogleFonts.inter(color: AppColors.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(s.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                              Row(
                                children: [
                                  IconButton(icon: const Icon(Icons.edit, size: 16, color: AppColors.primary), onPressed: () => _showAddServiceSheet(context, existing: s, index: i), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                                  const SizedBox(width: 12),
                                  IconButton(icon: const Icon(Icons.delete, size: 16, color: AppColors.statusCancel), onPressed: () { draft.services.removeAt(i); onChanged(); }, constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _infoRow('Qty', s.qty),
                        ],
                      ),
                    );
                  },
                ),
        ),
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
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 60, child: Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted))),
          Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textDark))),
        ],
      ),
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

  @override
  void initState() {
    super.initState();
    _fetchLayanan();
    if (widget.existing != null) {
      _qtyCtrl.text = widget.existing!.qty;
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
      price: 0,
      qty: _qtyCtrl.text,
      tanggalPengerjaan: '',
      waktuPengerjaan: '',
      bonusLayanan: 0,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
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
               Text(_error!, style: const TextStyle(color: Colors.red))
            else if (_availableServices.isEmpty)
               const Text('Tidak ada layanan di cabang ini.')
            else 
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Map<String, dynamic>>(
                  value: _selectedLayanan,
                  isExpanded: true,
                  items: _availableServices.map((e) => DropdownMenuItem(value: e, child: Text(e['nama_layanan']))).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedLayanan = v;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            _label('Qty (Contoh: 3 jam 2 cleaner)'),
            _textField(_qtyCtrl, hint: 'Teks bebas...'),
            const SizedBox(height: 12),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Simpan', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)));
  Widget _textField(TextEditingController ctrl, {TextInputType type = TextInputType.text, String hint = ''}) => TextField(
    controller: ctrl, keyboardType: type, decoration: InputDecoration(hintText: hint, filled: true, fillColor: AppColors.surface, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border))),
  );
}

// ─── Step 3: Ringkasan ─────────────────────────────────────────────────────
class _Step3Summary extends StatelessWidget {
  const _Step3Summary({required this.draft});
  final OrderDraft draft;

  String _formatRupiah(int n) =>
      'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryCard(title: 'Info Pesanan', child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pelanggan: ${draft.customer?.name ?? '-'}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text('Sumber: ${draft.chatDari.name} | Tipe: ${draft.tipeCustomer.name}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              if (draft.notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Catatan: ${draft.notes}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              ]
            ],
          )),
          const SizedBox(height: 12),
          _SummaryCard(
            title: 'Detail Layanan',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...draft.services.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(s.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          Text('-', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        ],
                      ),
                      Text('Qty: ${s.qty}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                )),
                const Divider(height: 16, color: AppColors.border),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      Text('Rp 0', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
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
