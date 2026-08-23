with open('lib/features/orders/screens/create_order_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

start_marker = '// ─── Step 1: Info Pesanan ─────────────────────────────────────────────────'
end_marker = 'class _CustomerSearchSheet extends StatefulWidget {'

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx == -1 or end_idx == -1:
    print('Markers not found!')
    exit(1)

new_step1 = '''// ─── Step 1: Info Pesanan ─────────────────────────────────────────────────
class _Step1Info extends StatefulWidget {
  const _Step1Info({
    required this.draft,
    required this.onChanged,
  });
  final OrderDraft draft;
  final VoidCallback onChanged;

  @override
  State<_Step1Info> createState() => _Step1InfoState();
}

class _Step1InfoState extends State<_Step1Info> {
  List<CustomerModel> _customers = [];
  bool _isLoading = true;
  String? _error;
  String _userBranch = 'Memuat...';

  late final TextEditingController _tglCtrl;
  late final TextEditingController _waktuCtrl;

  @override
  void initState() {
    super.initState();
    _tglCtrl = TextEditingController(text: widget.draft.tanggalPengerjaan);
    _waktuCtrl = TextEditingController(text: widget.draft.waktuPengerjaan);
    _loadUserBranch();
    _loadCustomers();
  }

  Future<void> _loadUserBranch() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userBranch = prefs.getString('user_branch') ?? '-';
      });
    }
  }

  @override
  void dispose() {
    _tglCtrl.dispose();
    _waktuCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final data = await CustomerService.getCustomers();
      if (mounted) {
        setState(() {
          _customers = data;
          _isLoading = false;
        });

        if (widget.draft.customer != null) {
          final matched = _customers.firstWhere(
            (c) => c.id == widget.draft.customer!.id,
            orElse: () => CustomerModel(
              id: widget.draft.customer!.id,
              name: widget.draft.customer!.name,
              phone: widget.draft.customer!.phone,
              address: widget.draft.customer!.address,
              status: 'aktif',
              totalOrders: 0,
              totalSpending: 0,
              lastOrderDate: '-',
              notes: widget.draft.customer!.notes,
              orders: const [],
            ),
          );
          final isReturning = matched.totalOrders > 0 || matched.orders.isNotEmpty;
          if (isReturning) {
            widget.draft.tipeCustomer = CustomerType.lama;
            widget.draft.chatDari = ChatSource.lama;
          } else {
            widget.draft.tipeCustomer = CustomerType.baru;
            if (widget.draft.chatDari == ChatSource.lama) {
              widget.draft.chatDari = ChatSource.organik;
            }
          }
          widget.onChanged();
        }
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

  bool get _isCustomerLama {
    if (widget.draft.customer == null) return false;
    final matched = _customers.where((c) => c.id == widget.draft.customer!.id);
    if (matched.isNotEmpty) {
      final c = matched.first;
      return c.totalOrders > 0 || c.orders.isNotEmpty;
    }
    return widget.draft.tipeCustomer == CustomerType.lama;
  }

  Future<void> _handleCustomerSelected(CustomerModel c) async {
    widget.draft.customer = OrderCustomer(
      id: c.id,
      name: c.name,
      phone: c.phone,
      address: c.address,
      area: '-',
      notes: c.notes,
    );

    final isReturning = c.totalOrders > 0 || c.orders.isNotEmpty;
    if (isReturning) {
      widget.draft.tipeCustomer = CustomerType.lama;
      widget.draft.chatDari = ChatSource.lama;
    } else {
      widget.draft.tipeCustomer = CustomerType.baru;
      if (widget.draft.chatDari == ChatSource.lama) {
        widget.draft.chatDari = ChatSource.organik;
      }
    }

    widget.onChanged();

    // Auto-fetch last order if customer has ordered previously (quietly in background)
    if (isReturning) {
      try {
        final fullCust = await CustomerService.getCustomer(c.id);
        if (fullCust.rawOrders.isNotEmpty) {
          final sortedOrders = List<Map<String, dynamic>>.from(fullCust.rawOrders);
          sortedOrders.sort((a, b) {
            final idA = int.tryParse(a['id']?.toString() ?? '0') ?? 0;
            final idB = int.tryParse(b['id']?.toString() ?? '0') ?? 0;
            return idB.compareTo(idA);
          });
          final lastOrder = sortedOrders.first;
          final details = (lastOrder['details'] as List?) ?? [];

          if (details.isNotEmpty) {
            widget.draft.services.clear();
            for (var d in details) {
              if (d is Map) {
                final lay = d['layanan'] as Map<String, dynamic>? ?? {};
                widget.draft.services.add(
                  ServiceItem(
                    id: d['id']?.toString() ?? '',
                    layananId: d['layanan_id']?.toString() ?? lay['id']?.toString(),
                    name: lay['nama_layanan']?.toString() ?? d['nama_layanan']?.toString() ?? 'Layanan Kebersihan',
                    price: (d['harga'] ?? d['subtotal'] ?? lay['harga']) != null
                        ? (double.tryParse((d['harga'] ?? d['subtotal'] ?? lay['harga']).toString())?.toInt() ?? 0)
                        : 0,
                    qty: d['qty']?.toString() ?? '1',
                    tanggalPengerjaan: widget.draft.tanggalPengerjaan,
                    waktuPengerjaan: widget.draft.waktuPengerjaan,
                    bonusLayanan: d['bonus_layanan'] != null
                        ? (double.tryParse(d['bonus_layanan'].toString())?.toInt() ?? 0)
                        : 0,
                  ),
                );
              }
            }

            // Copy notes if draft notes is empty
            final prevNotes = lastOrder['keterangan_order']?.toString();
            if (prevNotes != null && prevNotes.trim().isNotEmpty && widget.draft.notes.isEmpty) {
              widget.draft.notes = prevNotes;
            }

            // Copy PPN
            final ppnVal = lastOrder['ppn'] ?? lastOrder['pembayaran']?['ppn'] ?? 0;
            widget.draft.applyPpn = (double.tryParse(ppnVal.toString()) ?? 0) > 0;

            // Copy cleaners if any
            final cleaners = (lastOrder['cleaners'] as List?) ?? [];
            if (cleaners.isNotEmpty) {
              widget.draft.cleaners.clear();
              for (var clItem in cleaners) {
                if (clItem is Map) {
                  final cl = clItem['cleaner'] as Map<String, dynamic>? ?? {};
                  widget.draft.cleaners.add(
                    OrderCleaner(
                      id: cl['id']?.toString() ?? clItem['cleaner_id']?.toString() ?? '',
                      pesananCleanerId: clItem['id']?.toString() ?? '',
                      name: cl['nama']?.toString() ?? 'Cleaner',
                      rating: (cl['rating'] != null ? double.tryParse(cl['rating'].toString()) : null) ?? 5.0,
                      phone: cl['no_wa']?.toString() ?? '',
                      statusPengerjaan: CleanerWorkStatus.assigned,
                    ),
                  );
                }
              }
            }
            widget.onChanged();
          }
        }
      } catch (e) {
        debugPrint('Gagal mengambil data pesanan terakhir: $e');
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
          Navigator.pop(ctx);
          _handleCustomerSelected(c);
        },
      ),
    );
  }

  String _formatDateYmd(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.draft.customer;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Customer Card
          _buildSectionHeader(
            icon: Icons.person_rounded,
            title: 'Data Pelanggan',
            badge: customer != null ? (_isCustomerLama ? 'Pelanggan Lama' : 'Pelanggan Baru') : null,
            badgeColor: _isCustomerLama ? AppColors.primary : const Color(0xFF10B981),
          ),
          const SizedBox(height: 10),

          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 13)),
                  ),
                ],
              ),
            )
          else
            customer == null
                ? InkWell(
                    onTap: _showCustomerSearchSheet,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBlue.withValues(alpha: 0.35),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pilih / Cari Pelanggan',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ketuk untuk memilih pelanggan terdaftar atau buat baru',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            InitialsAvatar(
                              name: customer.name,
                              size: 46,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              textColor: AppColors.primary,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.phone_rounded,
                                        size: 13,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        customer.phone,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _showCustomerSearchSheet,
                              icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                              label: const Text('Ganti'),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                side: const BorderSide(color: AppColors.primary),
                                foregroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                customer.address.isNotEmpty ? customer.address : 'Alamat belum diatur',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

          const SizedBox(height: 20),

          // Section 2: Cabang Pemroses
          _buildSectionHeader(
            icon: Icons.storefront_rounded,
            title: 'Cabang Pemroses',
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.store_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userBranch,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Cabang tempat order akan diproses',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        'Terkunci',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
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

          // Section 3: Sumber Chat & Tipe Customer
          _buildSectionHeader(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Sumber Chat & Tipe Customer',
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SUMBER CHAT',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (_isCustomerLama)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Otomatis: Pernah Order',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: ChatSource.values.map((e) {
                    final isLama = _isCustomerLama;
                    final isSelected = isLama
                        ? (e == ChatSource.lama)
                        : (widget.draft.chatDari == e);
                    final isEnabled = isLama
                        ? (e == ChatSource.lama)
                        : (e != ChatSource.lama);

                    IconData icon;
                    String label;
                    switch (e) {
                      case ChatSource.organik:
                        icon = Icons.eco_rounded;
                        label = 'ORGANIK';
                        break;
                      case ChatSource.ads:
                        icon = Icons.campaign_rounded;
                        label = 'IKLAN (ADS)';
                        break;
                      case ChatSource.lama:
                        icon = Icons.history_rounded;
                        label = 'LAMA';
                        break;
                    }

                    return Expanded(
                      child: GestureDetector(
                        onTap: isEnabled
                            ? () {
                                widget.draft.chatDari = e;
                                widget.onChanged();
                              }
                            : null,
                        child: Opacity(
                          opacity: isEnabled ? 1.0 : 0.35,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.only(
                              right: e == ChatSource.values.last ? 0 : 8,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.border,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  icon,
                                  size: 18,
                                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  label,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? AppColors.primary : AppColors.textMuted,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TIPE CUSTOMER',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (_isCustomerLama)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Terkunci Otomatis',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: CustomerType.values.map((e) {
                    final isLama = _isCustomerLama;
                    final isSelected = isLama
                        ? (e == CustomerType.lama)
                        : (widget.draft.tipeCustomer == e);
                    final isEnabled = isLama ? (e == CustomerType.lama) : true;

                    return Expanded(
                      child: GestureDetector(
                        onTap: isEnabled
                            ? () {
                                widget.draft.tipeCustomer = e;
                                widget.onChanged();
                              }
                            : null,
                        child: Opacity(
                          opacity: isEnabled ? 1.0 : 0.35,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.only(
                              right: e == CustomerType.values.last ? 0 : 10,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.border,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                e == CustomerType.baru ? 'BARU' : 'LAMA',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section 4: Jadwal Pengerjaan
          _buildSectionHeader(
            icon: Icons.calendar_month_rounded,
            title: 'Jadwal Pengerjaan',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _dateField(context, _tglCtrl, hint: 'Pilih Tanggal'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _timeField(context, _waktuCtrl, hint: 'Pilih Jam'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Section 5: Keterangan
          _buildSectionHeader(
            icon: Icons.notes_rounded,
            title: 'Keterangan Order',
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: widget.draft.notes,
            maxLines: 3,
            onChanged: (v) {
              widget.draft.notes = v;
              widget.onChanged();
            },
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
            decoration: InputDecoration(
              hintText: 'Tambahkan catatan atau instruksi khusus pesanan ini (opsional)...',
              hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    String? badge,
    Color? badgeColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        if (badge != null) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (badgeColor ?? AppColors.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: badgeColor ?? AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _dateField(
    BuildContext context,
    TextEditingController ctrl, {
    String hint = '',
  }) {
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
          ctrl.text = _formatDateYmd(picked);
          widget.draft.tanggalPengerjaan = ctrl.text;
          widget.onChanged();
          setState(() {});
        }
      },
      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        prefixIcon: const Icon(
          Icons.calendar_today_rounded,
          size: 18,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _timeField(
    BuildContext context,
    TextEditingController ctrl, {
    String hint = '',
  }) {
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
          widget.draft.waktuPengerjaan = ctrl.text;
          widget.onChanged();
          setState(() {});
        }
      },
      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        prefixIcon: const Icon(
          Icons.access_time_rounded,
          size: 18,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

'''

new_content = content[:start_idx] + new_step1 + content[end_idx:]

with open('lib/features/orders/screens/create_order_screen.dart', 'w', encoding='utf-8') as f:
    f.write(new_content)

print('Cleaned Step 1 successfully')
