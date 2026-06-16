import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/data/order_model.dart';
import '../../../core/data/customer_model.dart';
import '../services/order_service.dart';

class EditOrderScreen extends StatefulWidget {
  const EditOrderScreen({super.key, required this.order});
  final OrderModel order;

  @override
  State<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends State<EditOrderScreen> {
  final OrderService _orderService = OrderService();
  int _step = 0; // 0=customer, 1=services, 2=schedule, 3=cleaner, 4=summary
  late final OrderDraft _draft;
  bool _isSaving = false;

  static const _steps = ['Pelanggan', 'Layanan', 'Jadwal', 'Petugas', 'Ringkasan'];

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    String? date;
    String? time;
    if (o.schedule.contains('·')) {
      final parts = o.schedule.split('·');
      date = parts[0].trim();
      if (parts.length > 1) {
        time = parts[1].trim();
      }
    } else {
      date = o.schedule;
    }

    _draft = OrderDraft(
      customer: OrderCustomer(
        id: o.customer.id,
        name: o.customer.name,
        phone: o.customer.phone,
        address: o.customer.address,
        area: o.customer.area,
      ),
      services: List.from(o.services),
      scheduleDate: date,
      scheduleTime: time,
      cleaners: List.from(o.cleaners),
      notes: o.notes,
    );
  }

  void _next() => setState(() => _step = (_step + 1).clamp(0, 4));
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
              Text('Edit Pesanan', style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
              )),
              Text('Langkah ${_step + 1} dari 5 · ${_steps[_step]}', style: GoogleFonts.inter(
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
                      )),
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
      case 0: return _Step1Customer(draft: _draft, onChanged: () => setState(() {}));
      case 1: return _Step2Services(draft: _draft, onChanged: () => setState(() {}));
      case 2: return _Step3Schedule(draft: _draft, onChanged: () => setState(() {}));
      case 3: return _Step4Cleaner(draft: _draft, onChanged: () => setState(() {}));
      case 4: return _Step5Summary(draft: _draft);
      default: return const SizedBox();
    }
  }

  Widget _buildNavButtons() {
    final canNext = switch (_step) {
      0 => _draft.customer != null,
      1 => _draft.services.isNotEmpty,
      2 => _draft.scheduleDate != null,
      3 => true, // cleaner optional
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
              onPressed: (canNext && !_isSaving) ? (_step == 4 ? _submit : _next) : null,
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
                    _step == 4 ? '✓ Simpan Perubahan' : 'Lanjut →',
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
      if (_draft.scheduleDate != null && _draft.services.isNotEmpty) {
        _draft.services.first.tanggalPengerjaan = _draft.scheduleDate!;
        if (_draft.scheduleTime != null) {
          _draft.services.first.waktuPengerjaan = _draft.scheduleTime!;
        }
      }
      
      await _orderService.updateOrder(widget.order.id, _draft);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pesanan berhasil diperbarui!', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppColors.statusDone,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context, true); // Pop back and pass a true result to signify update
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

// ─── Step 1: Pilih Pelanggan ───────────────────────────────────────────────
class _Step1Customer extends StatefulWidget {
  const _Step1Customer({required this.draft, required this.onChanged});
  final OrderDraft draft;
  final VoidCallback onChanged;

  @override
  State<_Step1Customer> createState() => _Step1CustomerState();
}

class _Step1CustomerState extends State<_Step1Customer> {
  String _query = '';

  List<CustomerModel> get _filtered => mockCustomers.where((c) {
    final q = _query.toLowerCase();
    return c.name.toLowerCase().contains(q) || c.phone.contains(q) || c.address.toLowerCase().contains(q);
  }).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Cari nama, nomor HP, atau alamat...',
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final c = _filtered[i];
              final selected = widget.draft.customer?.id == c.id;
              final isAktif = c.status.toLowerCase() == 'aktif';
              return GestureDetector(
                onTap: () {
                  widget.draft.customer = OrderCustomer(
                    id: c.id, name: c.name, phone: c.phone,
                    address: c.address, area: '-',
                  );
                  widget.onChanged();
                  setState(() {});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.surfaceBlue : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                    boxShadow: selected ? [const BoxShadow(
                      color: Color(0x1A004F91), blurRadius: 8,
                    )] : [AppColors.cardShadow],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          InitialsAvatar(
                            name: c.name, size: 44,
                            backgroundColor: selected ? AppColors.primary : AppColors.surfaceBlue,
                            textColor: selected ? Colors.white : AppColors.primary,
                          ),
                          Positioned(
                            bottom: -2, right: -2,
                            child: Container(
                              width: 12, height: 12,
                              decoration: BoxDecoration(
                                color: isAktif ? AppColors.statusDone : AppColors.statusCancel,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark,
                            )),
                            Text(c.phone, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 10, color: AppColors.textMuted),
                                const SizedBox(width: 2),
                                Expanded(child: Text(c.address, style: GoogleFonts.inter(
                                  fontSize: 10, color: AppColors.textMuted,
                                ), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      selected
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                          : const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Step 2: Pilih Layanan ─────────────────────────────────────────────────
class _Step2Services extends StatelessWidget {
  const _Step2Services({required this.draft, required this.onChanged});
  final OrderDraft draft;
  final VoidCallback onChanged;

  String _formatRupiah(int n) =>
      'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: mockServices.length,
      itemBuilder: (_, i) {
        final s = mockServices[i];
        final idx = draft.services.indexWhere((x) => x.name == s['name']);
        final qty = idx >= 0 ? draft.services[idx].qty : 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: qty > 0 ? AppColors.surfaceBlue : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: qty > 0 ? AppColors.primary : AppColors.border),
            boxShadow: [AppColors.cardShadow],
          ),
          child: Row(
            children: [
              Text(s['icon'] as String, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['name'] as String, style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark,
                    )),
                    Text('${_formatRupiah(s['price'] as int)} / ${s['unit']}', style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600,
                    )),
                  ],
                ),
              ),
              if (qty == 0)
                GestureDetector(
                  onTap: () {
                    draft.services.add(ServiceItem(name: s['name'] as String, price: s['price'] as int, qty: 1));
                    onChanged();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('+ Tambah', style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600,
                    )),
                  ),
                )
              else
                Row(
                  children: [
                    _QtyBtn(Icons.remove, () {
                      if (qty <= 1) draft.services.removeAt(idx);
                      else draft.services[idx] = ServiceItem(name: s['name'] as String, price: s['price'] as int, qty: qty - 1);
                      onChanged();
                    }),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('$qty', style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark,
                      )),
                    ),
                    _QtyBtn(Icons.add, () {
                      draft.services[idx] = ServiceItem(name: s['name'] as String, price: s['price'] as int, qty: qty + 1);
                      onChanged();
                    }),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn(this.icon, this.onTap);
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: AppColors.surfaceBlue, borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}

// ─── Step 3: Jadwal ────────────────────────────────────────────────────────
class _Step3Schedule extends StatefulWidget {
  const _Step3Schedule({required this.draft, required this.onChanged});
  final OrderDraft draft;
  final VoidCallback onChanged;

  @override
  State<_Step3Schedule> createState() => _Step3ScheduleState();
}

class _Step3ScheduleState extends State<_Step3Schedule> {
  static const _dates = [
    'Rabu, 11 Jun 2026', 'Kamis, 12 Jun 2026', 'Jumat, 13 Jun 2026',
    'Sabtu, 14 Jun 2026', 'Senin, 16 Jun 2026', 'Selasa, 17 Jun 2026',
  ];
  static const _times = [
    '07:00 - 09:00', '09:00 - 11:00', '10:00 - 12:00',
    '13:00 - 15:00', '14:00 - 16:00', '15:00 - 17:00',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Pilih Tanggal'),
          const SizedBox(height: 10),
          ..._dates.map((d) => _SelectRow(
            label: d,
            selected: widget.draft.scheduleDate == d,
            icon: Icons.event_rounded,
            onTap: () {
              widget.draft.scheduleDate = d;
              widget.onChanged();
              setState(() {});
            },
          )),
          const SizedBox(height: 16),
          _sectionLabel('Pilih Waktu'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _times.map((t) {
              final sel = widget.draft.scheduleTime == t;
              return GestureDetector(
                onTap: () {
                  widget.draft.scheduleTime = t;
                  widget.onChanged();
                  setState(() {});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                  ),
                  child: Text(t, style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: sel ? Colors.white : AppColors.textDark,
                  )),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(t.toUpperCase(), style: GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5,
  ));
}

class _SelectRow extends StatelessWidget {
  const _SelectRow({required this.label, required this.selected, required this.icon, required this.onTap});
  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceBlue : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: selected ? AppColors.primary : AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.textDark,
            ))),
            if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Step 4: Pilih Petugas ─────────────────────────────────────────────────
class _Step4Cleaner extends StatelessWidget {
  const _Step4Cleaner({required this.draft, required this.onChanged});
  final OrderDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: mockCleaners.length,
      itemBuilder: (_, i) {
        final cl = mockCleaners[i];
        final busy = cl['status'] == 'busy';
        final sel = draft.cleaners.any((c) => c.id == cl['id']);
        return GestureDetector(
          onTap: busy ? null : () {
            if (sel) {
              draft.cleaners.removeWhere((c) => c.id == cl['id']);
            } else {
              draft.cleaners.add(OrderCleaner(
                id: cl['id'] as String,
                name: cl['name'] as String,
                rating: (cl['rating'] as num).toDouble(),
              ));
            }
            onChanged();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: sel ? AppColors.surfaceBlue : busy ? AppColors.background : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sel ? AppColors.primary : AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: busy ? const Color(0xFFF3F4F6) : AppColors.surfaceBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.cleaning_services_rounded,
                    color: busy ? AppColors.textMuted : AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cl['name'] as String, style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: busy ? AppColors.textMuted : AppColors.textDark,
                      )),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 2),
                          Text('${cl['rating']}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                          const Text(' · ', style: TextStyle(color: AppColors.textMuted)),
                          Text('${cl['orders']} order', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (busy)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.statusPendingBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Sibuk', style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.statusPending, fontWeight: FontWeight.w600,
                    )),
                  )
                else if (sel)
                  const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.statusDoneBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Tersedia', style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.statusDone, fontWeight: FontWeight.w600,
                    )),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Step 5: Ringkasan ─────────────────────────────────────────────────────
class _Step5Summary extends StatelessWidget {
  const _Step5Summary({required this.draft});
  final OrderDraft draft;

  String _formatRupiah(int n) =>
      'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryCard(title: 'Pelanggan', child: Text(
            draft.customer?.name ?? '-',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
          )),
          const SizedBox(height: 10),
          _SummaryCard(
            title: 'Layanan',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...draft.services.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${s.qty}x ${s.name}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark)),
                      Text(_formatRupiah(s.subtotal), style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark,
                      )),
                    ],
                  ),
                )),
                const Divider(height: 12, color: AppColors.border),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    Text(_formatRupiah(draft.total), style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary,
                    )),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _SummaryCard(title: 'Jadwal', child: Text(
            '${draft.scheduleDate ?? '-'} · ${draft.scheduleTime ?? '-'}',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
          )),
          const SizedBox(height: 10),
          _SummaryCard(title: 'Petugas', child: Text(
            draft.cleaners.isNotEmpty ? draft.cleaners.map((c) => c.name).join(', ') : 'Belum dipilih (akan diassign)',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
          )),
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
          Text(title.toUpperCase(), style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5,
          )),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
