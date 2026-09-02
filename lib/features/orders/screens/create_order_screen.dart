import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/app_confirmation_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/data/order_model.dart';
import '../../../core/data/customer_model.dart';
import '../../../core/services/customer_service.dart';
import '../services/order_service.dart';
import '../../../core/api/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/currency_formatter.dart';
import 'order_detail_screen.dart';
import '../../customers/screens/add_customer_screen.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key, this.existingOrder, this.initialCustomer});
  final OrderModel? existingOrder;
  final CustomerModel? initialCustomer;

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final OrderService _orderService = OrderService();
  int _step = 0; // 0=info, 1=services, 2=cleaners, 3=summary
  final _draft = OrderDraft();
  bool _isSaving = false;
  bool _isBranchWajibPpn = false;

  static const _steps = [
    'Info Pesanan',
    'Detail Layanan',
    'Pilih Cleaner',
    'Ringkasan',
  ];

  static const _stepIcons = [
    Icons.assignment_outlined,
    Icons.cleaning_services_outlined,
    Icons.badge_outlined,
    Icons.receipt_long_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _checkBranchPpn();
    if (widget.existingOrder != null) {
      final o = widget.existingOrder!;
      _draft.customer = o.customer;
      _draft.chatDari = o.chatDari;
      _draft.tipeCustomer = o.tipeCustomer;
      _draft.notes = o.notes;
      _draft.services = List.from(o.services);
      _draft.cleaners = List.from(o.cleaners);
      _draft.applyPpn = (o.ppn ?? o.pembayaran?.ppn ?? 0) > 0;
      _draft.applyPph = (o.pph ?? o.pembayaran?.pph ?? 0) > 0;
      _draft.diskonPersen = (o.discount ?? (o.pembayaran?.diskonPersen?.toInt() ?? 0)).toDouble();

      if (o.services.isNotEmpty) {
        _draft.tanggalPengerjaan = o.services.first.tanggalPengerjaan;
        _draft.waktuPengerjaan = o.services.first.waktuPengerjaan;
      }
    } else if (widget.initialCustomer != null) {
      final c = widget.initialCustomer!;
      _draft.customer = OrderCustomer(
        id: c.id,
        name: c.name,
        phone: c.phone,
        address: c.address,
        area: '-',
        notes: c.notes,
      );
      final isReturning = c.totalOrders > 0 || c.orders.isNotEmpty;
      if (isReturning) {
        _draft.tipeCustomer = CustomerType.lama;
        _draft.chatDari = ChatSource.lama;
      } else {
        _draft.tipeCustomer = CustomerType.baru;
        _draft.chatDari = ChatSource.organik;
      }
    }
  }

  Future<void> _checkBranchPpn() async {
    final prefs = await SharedPreferences.getInstance();
    final branchName = prefs.getString('user_branch') ?? '-';
    try {
      final response = await ApiClient.instance.get('/cabangs');
      if (response.data != null && response.data['data'] != null) {
        final List list = response.data['data'];
        final matched = list.firstWhere(
          (c) => (c['nama_cabang']?.toString().toLowerCase() == branchName.toLowerCase()),
          orElse: () => null,
        );
        if (matched != null) {
          final isPpn = matched['is_ppn_enabled'] == true ||
              matched['is_ppn_enabled'] == 1 ||
              matched['is_ppn_enabled']?.toString() == '1' ||
              matched['is_ppn_enabled']?.toString().toLowerCase() == 'true';
          if (mounted) {
            setState(() {
              _isBranchWajibPpn = isPpn;
              if (widget.existingOrder == null && !_draft.hasUserToggledPpn) {
                _draft.applyPpn = isPpn;
              }
            });
          }
        }
      }
    } catch (_) {}
  }

  void _next() => setState(() => _step = (_step + 1).clamp(0, 3));
  void _prev() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existingOrder == null
                      ? 'Buat Pesanan Baru'
                      : 'Edit Pesanan',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Langkah ${_step + 1} dari 4 · ${_steps[_step]}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _stepIcons[_step],
                  size: 13,
                  color: Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  '${((_step + 1) / 4 * 100).toInt()}%',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: List.generate(_steps.length, (i) {
          final isDone = i < _step;
          final isActive = i == _step;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: isDone ? () => setState(() => _step = i) : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isDone
                                  ? const Color(0xFF10B981)
                                  : isActive
                                      ? AppColors.primary
                                      : AppColors.surfaceBlue.withValues(alpha: 0.8),
                              shape: BoxShape.circle,
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : [],
                              border: Border.all(
                                color: isActive
                                    ? Colors.white
                                    : isDone
                                        ? const Color(0xFF10B981)
                                        : AppColors.border,
                                width: isActive ? 2 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: isDone
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : Icon(
                                    _stepIcons[i],
                                    size: 15,
                                    color: isActive
                                        ? Colors.white
                                        : AppColors.textMuted,
                                  ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _steps[i],
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: isActive
                                  ? AppColors.primary
                                  : isDone
                                      ? AppColors.textDark
                                      : AppColors.textMuted,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : isDone
                                      ? FontWeight.w600
                                      : FontWeight.w500,
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
                if (i < _steps.length - 1)
                  Container(
                    width: 14,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: i < _step
                          ? const Color(0xFF10B981)
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(1),
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
      case 0:
        return _Step1Info(
          draft: _draft,
          isBranchWajibPpn: _isBranchWajibPpn,
          onChanged: () => setState(() {}),
        );
      case 1:
        return _Step2Services(draft: _draft, onChanged: () => setState(() {}));
      case 2:
        return _Step3Cleaner(draft: _draft, onChanged: () => setState(() {}));
      case 3:
        return _Step4Summary(draft: _draft, isBranchWajibPpn: _isBranchWajibPpn);
      default:
        return const SizedBox();
    }
  }

  Widget _buildNavButtons() {
    final canNext = switch (_step) {
      0 =>
        _draft.customer != null &&
            _draft.tanggalPengerjaan.isNotEmpty &&
            _draft.waktuPengerjaan.isNotEmpty,
      1 => _draft.services.isNotEmpty,
      _ => true,
    };

    String nextButtonLabel;
    IconData nextButtonIcon;
    switch (_step) {
      case 0:
        nextButtonLabel = 'Lanjut: Pilih Layanan';
        nextButtonIcon = Icons.arrow_forward_rounded;
        break;
      case 1:
        nextButtonLabel = 'Lanjut: Pilih Cleaner';
        nextButtonIcon = Icons.arrow_forward_rounded;
        break;
      case 2:
        nextButtonLabel = 'Lanjut: Ringkasan';
        nextButtonIcon = Icons.arrow_forward_rounded;
        break;
      case 3:
      default:
        nextButtonLabel = widget.existingOrder == null ? 'Simpan Pesanan' : 'Perbarui Pesanan';
        nextButtonIcon = Icons.check_circle_rounded;
        break;
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          if (_step > 0) ...[
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: _prev,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: const BorderSide(color: AppColors.border, width: 1.5),
                  backgroundColor: AppColors.surface,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textDark),
                    const SizedBox(width: 6),
                    Text(
                      'Kembali',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: (canNext && !_isSaving)
                  ? (_step == 3 ? _submit : _next)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.border.withValues(alpha: 0.6),
                disabledForegroundColor: AppColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: canNext && !_isSaving ? 3 : 0,
                shadowColor: AppColors.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          nextButtonLabel,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: canNext ? Colors.white : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          nextButtonIcon,
                          size: 18,
                          color: canNext ? Colors.white : AppColors.textMuted,
                        ),
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
      String? createdOrderId;
      if (widget.existingOrder == null) {
        createdOrderId = await _orderService.createOrder(_draft);
        if (_draft.cleaners.isNotEmpty) {
          await _orderService.assignCleaner(
            createdOrderId,
            _draft.cleaners.map((c) => c.id).toList(),
          );
        }
      } else {
        final int? origCabang = int.tryParse(widget.existingOrder!.cabangId.replaceAll(RegExp(r'[^0-9]'), ''));
        await _orderService.updateOrder(
          widget.existingOrder!.id,
          _draft,
          originalCabangId: origCabang,
        );
        if (_draft.cleaners.isNotEmpty) {
          await _orderService.assignCleaner(
            widget.existingOrder!.id,
            _draft.cleaners.map((c) => c.id).toList(),
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                widget.existingOrder == null
                    ? 'Pesanan berhasil dibuat!'
                    : 'Pesanan berhasil diperbarui!',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: AppColors.statusDone,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      if (createdOrderId != null) {
        final newOrder = await _orderService.fetchOrderDetail(createdOrderId);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(order: newOrder),
          ),
          result: true,
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

// ─── Step 1: Info Pesanan ─────────────────────────────────────────────────
class _Step1Info extends StatefulWidget {
  const _Step1Info({
    required this.draft,
    this.isBranchWajibPpn = false,
    required this.onChanged,
  });
  final OrderDraft draft;
  final bool isBranchWajibPpn;
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

            // Copy PPN: Cabang Wajib PPN wajib default true
            if (widget.isBranchWajibPpn) {
              widget.draft.applyPpn = true;
            } else {
              final ppnVal = lastOrder['ppn'] ?? lastOrder['pembayaran']?['ppn'] ?? 0;
              widget.draft.applyPpn = (double.tryParse(ppnVal.toString()) ?? 0) > 0;
            }

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
                      fotoProfil: cl['foto_profil'] ?? cl['foto'] ?? cl['foto_url'] ?? cl['foto_profil_url'] ?? (cl['user'] != null && cl['user'] is Map ? (cl['user']['foto_profil'] ?? cl['user']['foto_url']) : null),
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
                Text(
                  'SUMBER CHAT',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: ChatSource.values.map((e) {
                    final isSelected = widget.draft.chatDari == e;

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
                        onTap: () {
                          widget.draft.chatDari = e;
                          widget.onChanged();
                          setState(() {});
                        },
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
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 14),

                Text(
                  'TIPE CUSTOMER',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: CustomerType.values.map((e) {
                    final isSelected = widget.draft.tipeCustomer == e;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          widget.draft.tipeCustomer = e;
                          widget.onChanged();
                          setState(() {});
                        },
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

class _CustomerSearchSheet extends StatefulWidget {
  const _CustomerSearchSheet({
    required this.customers,
    this.selectedId,
    required this.onSelect,
  });
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
    return c.name.toLowerCase().contains(q) ||
        c.phone.contains(q) ||
        c.address.toLowerCase().contains(q);
  }).toList();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pilih Pelanggan',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Cari nama, nomor HP, atau alamat...',
                hintStyle: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                filled: true,
                fillColor: AppColors.surface,
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
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final newCust = await Navigator.push<CustomerModel>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddCustomerScreen(),
                    ),
                  );
                  if (newCust != null && mounted) {
                    widget.onSelect(newCust);
                  }
                },
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Tambah Pelanggan Baru'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search_rounded, size: 48, color: AppColors.textMuted.withValues(alpha: 0.4)),
                        const SizedBox(height: 10),
                        Text(
                          'Tidak ada pelanggan ditemukan',
                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final c = _filtered[i];
                      final selected = widget.selectedId == c.id;
                      final isReturning = c.totalOrders > 0 || c.orders.isNotEmpty;

                      return InkWell(
                        onTap: () => widget.onSelect(c),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.05)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? AppColors.primary : AppColors.border,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              InitialsAvatar(
                                name: c.name,
                                size: 42,
                                backgroundColor: selected
                                    ? AppColors.primary
                                    : AppColors.surfaceBlue,
                                textColor: selected
                                    ? Colors.white
                                    : AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            c.name,
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isReturning
                                                ? AppColors.primary.withValues(alpha: 0.1)
                                                : const Color(0xFF10B981).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isReturning ? 'Lama' : 'Baru',
                                            style: GoogleFonts.inter(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: isReturning ? AppColors.primary : const Color(0xFF10B981),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.phone_rounded,
                                          size: 12,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          c.phone,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (c.address.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_rounded,
                                            size: 12,
                                            color: AppColors.textMuted,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              c.address,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: AppColors.textMuted,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (selected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
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

  void _showAddServiceSheet(
    BuildContext context, {
    ServiceItem? existing,
    int? index,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddServiceSheet(
        existing: existing,
        onSave: (item) {
          if (index != null) {
            draft.services[index] = item;
          } else {
            draft.services.add(item);
          }
          onChanged();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = draft.total;

    return Column(
      children: [
        // Action Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: ElevatedButton.icon(
            onPressed: () => _showAddServiceSheet(context),
            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 18),
            label: Text(
              'Tambah Layanan Kebersihan',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),

        // Service List
        Expanded(
          child: draft.services.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBlue.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cleaning_services_rounded,
                            size: 48,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum Ada Layanan Dipilih',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ketuk tombol "+ Tambah Layanan Kebersihan" di atas untuk menambahkan layanan pada pesanan ini.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: draft.services.length,
                  itemBuilder: (_, i) {
                    final s = draft.services[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceBlue,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.cleaning_services_rounded,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              s.name,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textDark,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Rp ${CurrencyInputFormatter.format(s.price.toInt())}',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Qty: ',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                s.qty.isNotEmpty ? s.qty : '1',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textDark,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: AppColors.border)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _showAddServiceSheet(
                                      context,
                                      existing: s,
                                      index: i,
                                    ),
                                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16)),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.edit_rounded, size: 15, color: AppColors.primary),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Edit Layanan',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(width: 1, height: 24, color: AppColors.border),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final confirm = await AppConfirmationDialog.show(
                                        context,
                                        title: 'Hapus Layanan?',
                                        message: 'Apakah Anda yakin ingin menghapus layanan "${s.name}" dari pesanan?',
                                        type: ConfirmationDialogType.danger,
                                        confirmText: 'Hapus',
                                        cancelText: 'Batal',
                                        isDestructive: true,
                                      );
                                      if (confirm == true) {
                                        draft.services.removeAt(i);
                                        onChanged();
                                      }
                                    },
                                    borderRadius: const BorderRadius.only(bottomRight: Radius.circular(16)),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.delete_outline_rounded, size: 15, color: AppColors.error),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Hapus',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.error,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Running Subtotal Banner
        if (draft.services.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: const Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${draft.services.length} Layanan Terpilih',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'Subtotal: ',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                    ),
                    Text(
                      'Rp ${CurrencyInputFormatter.format(subtotal)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
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

  final List<String> _quickQtyPresets = [
    '1 Jam',
    '2 Jam',
    '3 Jam',
    '4 Jam',
    '1 Unit',
    '1 Ruangan',
    '1 Kasur',
    '1 Sofa',
  ];

  @override
  void initState() {
    super.initState();
    _fetchLayanan();
    if (widget.existing != null) {
      _qtyCtrl.text = widget.existing!.qty;
      _hargaCtrl.text = CurrencyInputFormatter.format(widget.existing!.price);
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
                orElse: () => _availableServices.first,
              );
            } else {
              _selectedLayanan = _availableServices.first;
              final price = _selectedLayanan!['harga'] ?? _selectedLayanan!['harga_default'];
              final num priceVal = price is num ? price : (num.tryParse(price?.toString() ?? '0') ?? 0);
              if (priceVal > 0 && _hargaCtrl.text.isEmpty) {
                _hargaCtrl.text = CurrencyInputFormatter.format(priceVal.toInt());
              }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Silakan lengkapi jenis layanan dan jumlah (qty)',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    widget.onSave(
      ServiceItem(
        id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        layananId: _selectedLayanan!['id']?.toString() ?? '1',
        name: _selectedLayanan!['nama_layanan'],
        price: int.tryParse(_hargaCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        qty: _qtyCtrl.text,
        tanggalPengerjaan: '',
        waktuPengerjaan: '',
        bonusLayanan: 0,
      ),
    );
    Navigator.pop(context);
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                    const SizedBox(height: 16),
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
                        hintText: 'Cari nama layanan...',
                        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cleaning_services_rounded, color: AppColors.textMuted.withValues(alpha: 0.3), size: 48),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Layanan tidak ditemukan',
                                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
                              itemBuilder: (context, index) {
                                final e = filtered[index];
                                final price = e['harga'] ?? e['harga_default'];
                                final num priceVal = price is num ? price : (num.tryParse(price?.toString() ?? '0') ?? 0);
                                final isSelected = _selectedLayanan?['id'] == e['id'];

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary.withValues(alpha: 0.1)
                                          : AppColors.primary.withValues(alpha: 0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.cleaning_services_rounded,
                                      size: 18,
                                      color: isSelected ? AppColors.primary : AppColors.textMuted,
                                    ),
                                  ),
                                  title: Text(
                                    e['nama_layanan'],
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected ? AppColors.primary : AppColors.textDark,
                                    ),
                                  ),
                                  subtitle: priceVal > 0
                                      ? Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            'Harga default: Rp ${CurrencyInputFormatter.format(priceVal.toInt())}',
                                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                          ),
                                        )
                                      : null,
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                                      : const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
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
          final price = _selectedLayanan!['harga'] ?? _selectedLayanan!['harga_default'];
          final num priceVal = price is num ? price : (num.tryParse(price?.toString() ?? '0') ?? 0);
          _hargaCtrl.text = priceVal > 0 ? CurrencyInputFormatter.format(priceVal.toInt()) : '';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  widget.existing == null ? Icons.add_circle_outline_rounded : Icons.edit_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.existing == null ? 'Tambah Layanan' : 'Edit Layanan',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _label('Jenis Layanan'),
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    else if (_error != null)
                      Text(_error!, style: const TextStyle(color: AppColors.error))
                    else if (_availableServices.isEmpty)
                      const Text('Tidak ada layanan di cabang ini.')
                    else
                      InkWell(
                        onTap: _showSearchServiceDialog,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
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
                                    fontWeight: _selectedLayanan != null ? FontWeight.w600 : FontWeight.normal,
                                    color: _selectedLayanan != null ? AppColors.textDark : AppColors.textMuted,
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
                    _label('Harga Layanan (Rp)'),
                    _textField(
                      _hargaCtrl,
                      type: TextInputType.number,
                      hint: 'Contoh: 150.000',
                      prefixText: 'Rp ',
                      inputFormatters: [CurrencyInputFormatter()],
                    ),
                    const SizedBox(height: 14),
                    _label('Jumlah / Qty (Contoh: 3 jam / 1 sofa)'),
                    _textField(
                      _qtyCtrl,
                      hint: 'Tulis durasi, jumlah barang/ruangan...',
                      type: TextInputType.multiline,
                      minLines: 2,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 8),
                    // Quick Qty Preset Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _quickQtyPresets.map((preset) {
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _qtyCtrl.text = preset;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceBlue.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              '+ $preset',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                elevation: 3,
                shadowColor: AppColors.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ),
    ),
  );

  Widget _textField(
    TextEditingController ctrl, {
    TextInputType type = TextInputType.text,
    String hint = '',
    String? prefixText,
    List<TextInputFormatter>? inputFormatters,
    int? minLines,
    int? maxLines = 1,
  }) => TextField(
    controller: ctrl,
    keyboardType: type,
    inputFormatters: inputFormatters,
    minLines: minLines,
    maxLines: maxLines,
    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w600),
    decoration: InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      prefixStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.bold),
      hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.normal),
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
    ),
  );
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
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchCleaners();
  }

  Future<void> _fetchCleaners() async {
    try {
      final svc = OrderService();
      final data = await svc.fetchAvailableCleaners(
        tanggal: widget.draft.tanggalPengerjaan.isNotEmpty ? widget.draft.tanggalPengerjaan : null,
        waktu: widget.draft.waktuPengerjaan.isNotEmpty ? widget.draft.waktuPengerjaan : null,
      );
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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: AppColors.error)),
      );
    }
    if (_availableCleaners.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, size: 48, color: AppColors.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            Text(
              'Tidak ada cleaner tersedia pada cabang ini.',
              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final filtered = _availableCleaners.where((c) {
      final name = (c['name'] ?? c['nama'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Search & Count Banner
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          color: AppColors.surface,
          child: Column(
            children: [
              TextField(
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Cari nama cleaner...',
                  hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pilih cleaner yang akan bertugas:',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.draft.cleaners.length} Dipilih',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline_rounded, color: AppColors.textMuted.withValues(alpha: 0.3), size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Cleaner tidak ditemukan',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final c = filtered[index];
                    final idStr = c['id'].toString();
                    final isSelected = widget.draft.cleaners.any((x) => x.id == idStr);

                    final statusLabel = c['status_label']?.toString() ?? 'Tersedia (Bebas)';
                    final statusType = c['status_type']?.toString().toLowerCase() ?? 'tersedia';
                    final bool isDisabled = c['is_disabled'] == true;

                    final String? foto = c['foto_profil']?.toString().replaceAll('\\', '/').trim();

                    return Opacity(
                      opacity: isDisabled && !isSelected ? 0.65 : 1.0,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : (isDisabled ? AppColors.border.withValues(alpha: 0.5) : AppColors.border),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

                            setState(() {
                              if (isSelected) {
                                widget.draft.cleaners.removeWhere((x) => x.id == idStr);
                              } else {
                                widget.draft.cleaners.add(
                                  OrderCleaner(
                                    id: idStr,
                                    pesananCleanerId: '',
                                    name: c['name'] ?? c['nama'] ?? 'Unknown',
                                    rating: c['rating'] != null
                                        ? double.tryParse(c['rating'].toString()) ?? 0.0
                                        : 0.0,
                                    statusPengerjaan: CleanerWorkStatus.assigned,
                                    totalBonus: 0,
                                    bonuses: [],
                                    fotoProfil: foto,
                                  ),
                                );
                              }
                              widget.onChanged();
                            });
                          },
                          leading: AppAvatar(
                            photoUrl: foto,
                            name: c['name'] ?? c['nama'] ?? 'C',
                            size: 44,
                            borderColor: isSelected ? AppColors.primary : null,
                            backgroundColor: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceBlue,
                            textColor: isSelected ? AppColors.primary : AppColors.primary,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c['name'] ?? c['nama'] ?? '-',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? AppColors.primary : AppColors.textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: _buildCleanerStatusBadge(statusLabel, statusType),
                          ),
                          trailing: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? AppColors.primary : (isDisabled ? AppColors.border : AppColors.border),
                                width: 2,
                              ),
                              color: isSelected ? AppColors.primary : Colors.transparent,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 15,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
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
}

// ─── Step 4: Ringkasan ─────────────────────────────────────────────────────
class _Step4Summary extends StatefulWidget {
  const _Step4Summary({required this.draft, this.isBranchWajibPpn = false});
  final OrderDraft draft;
  final bool isBranchWajibPpn;

  @override
  State<_Step4Summary> createState() => _Step4SummaryState();
}

class _Step4SummaryState extends State<_Step4Summary> {
  late final TextEditingController _diskonCustomCtrl;
  bool _isCustomDiskon = false;

  @override
  void initState() {
    super.initState();
    if (widget.isBranchWajibPpn && !widget.draft.hasUserToggledPpn) {
      widget.draft.applyPpn = true;
    }
    final p = widget.draft.diskonPersen;
    _diskonCustomCtrl = TextEditingController(
      text: p > 0 ? (p == p.toInt() ? p.toInt().toString() : p.toString()) : '',
    );
    final standardPresets = [0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 50.0];
    _isCustomDiskon = p > 0 && !standardPresets.contains(p);
  }

  @override
  void didUpdateWidget(covariant _Step4Summary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBranchWajibPpn && !widget.draft.hasUserToggledPpn) {
      widget.draft.applyPpn = true;
    }
  }

  @override
  void dispose() {
    _diskonCustomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int subtotal = widget.draft.total;
    final double diskonPersen = widget.draft.diskonPersen;
    final int diskonValue = (diskonPersen > 0)
        ? ((subtotal * diskonPersen) / 100).round()
        : 0;
    final int totalSetelahDiskon = (subtotal - diskonValue) > 0 ? (subtotal - diskonValue) : 0;
    final int ppn = widget.draft.applyPpn ? (totalSetelahDiskon * 0.11).round() : 0;
    final int pph = widget.draft.applyPph ? (totalSetelahDiskon * 0.02).round() : 0;
    final int totalAkhir = totalSetelahDiskon + ppn - pph;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Notice banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Periksa kembali seluruh data pesanan sebelum menyimpan ke sistem.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Card 1: Data Pelanggan & Jadwal
          _SummaryCard(
            title: 'DATA PELANGGAN & JADWAL',
            icon: Icons.person_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Nama', widget.draft.customer?.name ?? '-'),
                const SizedBox(height: 8),
                _infoRow('Telepon', widget.draft.customer?.phone ?? '-'),
                const SizedBox(height: 8),
                _infoRow('Alamat', widget.draft.customer?.address ?? '-'),
                const SizedBox(height: 10),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 10),
                _infoRow('Sumber Chat', widget.draft.chatDari.name.toUpperCase()),
                const SizedBox(height: 8),
                _infoRow('Tipe Customer', widget.draft.tipeCustomer.name.toUpperCase()),
                const SizedBox(height: 8),
                _infoRow(
                  'Jadwal',
                  '${widget.draft.tanggalPengerjaan} · ${widget.draft.waktuPengerjaan}',
                ),
                if (widget.draft.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoRow('Catatan', widget.draft.notes),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Card 2: Layanan Terpilih
          _SummaryCard(
            title: 'LAYANAN TERPILIH (${widget.draft.services.length})',
            icon: Icons.cleaning_services_rounded,
            child: widget.draft.services.isEmpty
                ? Text(
                    'Belum ada layanan yang dipilih.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...widget.draft.services.asMap().entries.map(
                        (entry) {
                          final i = entry.key;
                          final s = entry.value;
                          return Padding(
                            padding: EdgeInsets.only(bottom: i < widget.draft.services.length - 1 ? 12 : 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceBlue,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.cleaning_services_rounded,
                                    size: 14,
                                    color: AppColors.primary,
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
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Qty: ${s.qty}',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'Rp ${CurrencyInputFormatter.format(s.price)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),

          // Card 3: Petugas Kebersihan
          if (widget.draft.cleaners.isNotEmpty) ...[
            _SummaryCard(
              title: 'PETUGAS CLEANER (${widget.draft.cleaners.length})',
              icon: Icons.badge_rounded,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.draft.cleaners.map((c) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBlue,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppAvatar(
                          photoUrl: c.fotoProfil,
                          name: c.name,
                          size: 20,
                          borderWidth: 1,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          c.name,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Card 4: Rincian Biaya, Diskon & Pajak
          _SummaryCard(
            title: 'RINCIAN BIAYA & DISKON',
            icon: Icons.receipt_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subtotal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal Layanan',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      'Rp ${CurrencyInputFormatter.format(subtotal)}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Diskon Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_offer_outlined,
                          size: 16,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Diskon Pesanan',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    if (diskonValue > 0)
                      Text(
                        '- Rp ${CurrencyInputFormatter.format(diskonValue)} (${diskonPersen == diskonPersen.toInt() ? diskonPersen.toInt() : diskonPersen}%)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF059669),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Quick Diskon Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...[0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 50.0].map((val) {
                      final bool isSelected = !_isCustomDiskon && widget.draft.diskonPersen == val;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _isCustomDiskon = false;
                            widget.draft.diskonPersen = val;
                            _diskonCustomCtrl.text = val > 0 ? val.toInt().toString() : '';
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF059669) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Text(
                            val == 0.0 ? 'Tanpa Diskon' : '${val.toInt()}%',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      );
                    }),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isCustomDiskon = true;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _isCustomDiskon ? const Color(0xFF059669) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isCustomDiskon ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Text(
                          'Custom %',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: _isCustomDiskon ? FontWeight.bold : FontWeight.w600,
                            color: _isCustomDiskon ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Custom Discount Input Field
                if (_isCustomDiskon) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _diskonCustomCtrl,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                            decoration: InputDecoration(
                              hintText: 'Tulis persentase diskon (1 - 100)...',
                              hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                              prefixIcon: const Icon(Icons.percent_rounded, size: 16, color: Color(0xFF059669)),
                              suffixText: '%',
                              suffixStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                              ),
                            ),
                            onChanged: (val) {
                              final parsed = double.tryParse(val.trim()) ?? 0.0;
                              final clamped = parsed.clamp(0.0, 100.0);
                              setState(() {
                                widget.draft.diskonPersen = clamped;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                if (diskonValue > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal Setelah Diskon',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Rp ${CurrencyInputFormatter.format(totalSetelahDiskon)}',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ],

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: AppColors.border, height: 1),
                ),

                // PPN 11%
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: widget.draft.applyPpn,
                              onChanged: null, // Terkunci sesuai wajib PPN cabang
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
                                        color: widget.draft.applyPpn ? AppColors.textDark : AppColors.textMuted,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: widget.isBranchWajibPpn ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.lock_rounded, 
                                            size: 9.5, 
                                            color: widget.isBranchWajibPpn ? const Color(0xFF1E40AF) : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            widget.isBranchWajibPpn ? 'Terkunci (Wajib PPN)' : 'Terkunci (Tanpa PPN)',
                                            style: GoogleFonts.inter(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: widget.isBranchWajibPpn ? const Color(0xFF1E40AF) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  widget.draft.applyPpn 
                                      ? 'Dikenakan PPN 11% (Dapat diatur saat pembayaran)' 
                                      : 'Tanpa PPN (Dapat diatur saat pembayaran)',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: widget.draft.applyPpn ? const Color(0xFF2563EB) : AppColors.textMuted,
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
                    const SizedBox(width: 8),
                    Text(
                      'Rp ${CurrencyInputFormatter.format(ppn)}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // PPh 23 (2%)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: widget.draft.applyPph,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  widget.draft.applyPph = val;
                                });
                              }
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            activeColor: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PPh 23 (2%)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '- Rp ${CurrencyInputFormatter.format(pph)}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: AppColors.border),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBlue.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL AKHIR',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Rp ${CurrencyInputFormatter.format(totalAkhir)}',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        const Text(
          ': ',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.child,
    this.icon,
  });
  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
              ],
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

