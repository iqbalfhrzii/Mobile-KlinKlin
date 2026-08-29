import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/whatsapp_icon.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/data/order_model.dart';
import '../../../core/services/pdf_invoice_service.dart';
import '../../../core/widgets/weekly_date_picker.dart';
import 'order_detail_screen.dart';
import 'create_order_screen.dart';
import '../services/order_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class OrderListScreen extends StatefulWidget {
  final String? initialStatusFilter;
  final bool isTodayOnly;

  const OrderListScreen({
    super.key,
    this.initialStatusFilter,
    this.isTodayOnly = false,
  });

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final OrderService _orderService = OrderService();
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  String _error = '';

  String _query = '';
  String _statusFilter = 'Semua';
  String _statusUtamaFilter = 'Semua';
  String _statusPembayaranFilter = 'Semua';
  String _statusBonusFilter = 'Semua';
  String _periodFilter = 'weekly_date';
  DateTimeRange? _customRange;

  DateTime? _filterStart;
  DateTime? _filterEnd;

  static const _filters = [
    'Semua',
    'draft',
    'assigned',
    'inProgress',
    'finishedByCleaner',
    'waitingPaymentApproval',
    'completed',
    'cancelled',
  ];
  static const _filterLabels = {
    'Semua': 'Semua',
    'draft': 'Draft',
    'assigned': 'Ditugaskan',
    'inProgress': 'Dikerjakan',
    'finishedByCleaner': 'Selesai (Cleaner)',
    'waitingPaymentApproval': 'Pending',
    'completed': 'Selesai',
    'cancelled': 'Dibatalkan',
  };

  static const _statusUtamaFilters = [
    'Semua',
    'Selesai',
    'Process',
    'Pending',
    'Draft',
    'Dibatalkan',
  ];
  static const _statusPembayaranFilters = [
    'Semua',
    'Belum Dibayar',
    'Pending',
    'Disetujui',
    'Ditolak',
    'Dibatalkan',
  ];

  static const _statusBonusFilters = ['Semua', 'Pending', 'Selesai'];

  @override
  void initState() {
    super.initState();
    if (widget.initialStatusFilter != null) {
      _statusFilter = widget.initialStatusFilter!;
    }
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final data = await _orderService.fetchOrders();
      setState(() {
        _orders = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<OrderModel> get _filtered {
    final list = _orders.where((o) {
      final q = _query.toLowerCase();
      final matchQ =
          o.nomorPesanan.toLowerCase().contains(q) ||
          o.customer.name.toLowerCase().contains(q) ||
          o.customer.phone.toLowerCase().contains(q) ||
          o.services.any((s) => s.name.toLowerCase().contains(q));
      final matchStatusPengerjaan =
          _statusFilter == 'Semua' || o.status.name == _statusFilter;

      final matchStatusUtama =
          _statusUtamaFilter == 'Semua' ||
          (o.statusUtamaLabel.toLowerCase() ==
              (_statusUtamaFilter.toLowerCase() == 'selesai'
                  ? 'done'
                  : _statusUtamaFilter.toLowerCase()));

      final matchStatusPembayaran =
          _statusPembayaranFilter == 'Semua' ||
          o.statusPembayaranLabel.toLowerCase() ==
              _statusPembayaranFilter.toLowerCase();
      final matchStatusBonus =
          _statusBonusFilter == 'Semua' ||
          o.statusBonusLabel.toLowerCase() == _statusBonusFilter.toLowerCase();

      bool matchDate = true;
      if (q.isEmpty) {
        final dt = o.scheduleDateTime;
        if (_periodFilter == 'semua') {
          matchDate = true;
        } else if (_periodFilter == 'weekly_date' &&
            _filterStart != null &&
            _filterEnd != null) {
          final start = DateTime(
            _filterStart!.year,
            _filterStart!.month,
            _filterStart!.day,
          );
          final end = DateTime(
            _filterEnd!.year,
            _filterEnd!.month,
            _filterEnd!.day,
            23,
            59,
            59,
          );
          matchDate = !dt.isBefore(start) && !dt.isAfter(end);
        } else {
          final now = DateTime.now();
          if (_periodFilter == 'hari_ini') {
            matchDate =
                dt.year == now.year &&
                dt.month == now.month &&
                dt.day == now.day;
          } else if (_periodFilter == 'kemarin') {
            final yest = now.subtract(const Duration(days: 1));
            matchDate =
                dt.year == yest.year &&
                dt.month == yest.month &&
                dt.day == yest.day;
          } else if (_periodFilter == 'besok') {
            final tom = now.add(const Duration(days: 1));
            matchDate =
                dt.year == tom.year &&
                dt.month == tom.month &&
                dt.day == tom.day;
          } else if (_periodFilter == 'bulan_ini') {
            matchDate = dt.year == now.year && dt.month == now.month;
          } else if (_periodFilter == 'custom' && _customRange != null) {
            final cStart = DateTime(
              _customRange!.start.year,
              _customRange!.start.month,
              _customRange!.start.day,
            );
            final cEnd = DateTime(
              _customRange!.end.year,
              _customRange!.end.month,
              _customRange!.end.day,
              23,
              59,
              59,
            );
            matchDate = !dt.isBefore(cStart) && !dt.isAfter(cEnd);
          }
        }
      }
      return matchQ &&
          matchStatusUtama &&
          matchStatusPengerjaan &&
          matchStatusPembayaran &&
          matchStatusBonus &&
          matchDate;
    }).toList();

    // Sorting:
    // 1. Yang belum upload bukti transfer diutamakan di posisi paling atas
    // 2. Yang paling pagi (jam kerja mulai paling awal / ascending) di posisi paling atas
    list.sort((a, b) {
      final aNeedsProof = a.needsTransferProofUpload;
      final bNeedsProof = b.needsTransferProofUpload;

      if (aNeedsProof && !bNeedsProof) return -1; // a di atas
      if (!aNeedsProof && bNeedsProof) return 1;  // b di atas

      // Urutkan berdasarkan waktu jadwal paling pagi (Ascending)
      final aTime = a.scheduleFullDateTime;
      final bTime = b.scheduleFullDateTime;
      final timeCmp = aTime.compareTo(bTime);
      if (timeCmp != 0) return timeCmp;

      return b.tanggalInput.compareTo(a.tanggalInput);
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    WeeklyDatePicker(
                      showAllMonthButton: false,
                      searchQuery: _query,
                      initialDate: widget.isTodayOnly ? DateTime.now() : null,
                      onSearchChanged: (val) => setState(() => _query = val),
                      onFilterChanged: (start, end) {
                        setState(() {
                          _filterStart = start;
                          _filterEnd = end;
                          if (start != null) _periodFilter = 'weekly_date';
                        });
                      },
                      trailingWidget: _buildFilterButton(),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                                size: 40,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _error,
                                style: GoogleFonts.inter(
                                  color: AppColors.error,
                                ),
                              ),
                              TextButton(
                                onPressed: _fetchData,
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            'Tidak ada pesanan',
                            style: GoogleFonts.inter(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._filtered.map(
                        (o) => _OrderCard(
                          order: o,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderDetailScreen(order: o),
                              ),
                            );
                            _fetchData();
                          },
                          onRefresh: _fetchData,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'order_fab',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
          );
          _fetchData();
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (Navigator.canPop(context)) ...[
                const AppBackButton(),
                const SizedBox(width: 14),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manajemen',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    'Pesanan',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_filtered.length} Pesanan',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange:
          _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _periodFilter = 'custom';
      });
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
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
                    // Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter Transaksi',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // 1. Status Utama
                    Text(
                      'Status Utama',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _statusUtamaFilters.map((f) {
                        final isSel = _statusUtamaFilter == f;
                        return ChoiceChip(
                          label: Text(f == 'Semua' ? 'Semua Status' : f),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => _statusUtamaFilter = f);
                              setState(() => _statusUtamaFilter = f);
                            }
                          },
                          selectedColor: const Color(0xFFEFF6FF),
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSel
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSel
                                ? const Color(0xFF1D4ED8)
                                : AppColors.textDark,
                          ),
                          side: BorderSide(
                            color: isSel
                                ? const Color(0xFF3B82F6)
                                : Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // 2. Status Pengerjaan
                    Text(
                      'Status Pengerjaan',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _filters.map((f) {
                        final isSel = _statusFilter == f;
                        return ChoiceChip(
                          label: Text(_filterLabels[f]!),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => _statusFilter = f);
                              setState(() => _statusFilter = f);
                            }
                          },
                          selectedColor: const Color(0xFFEFF6FF),
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSel
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSel
                                ? const Color(0xFF1D4ED8)
                                : AppColors.textDark,
                          ),
                          side: BorderSide(
                            color: isSel
                                ? const Color(0xFF3B82F6)
                                : Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // 3. Status Pembayaran
                    Text(
                      'Status Pembayaran',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _statusPembayaranFilters.map((f) {
                        final isSel = _statusPembayaranFilter == f;
                        return ChoiceChip(
                          label: Text(f),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => _statusPembayaranFilter = f);
                              setState(() => _statusPembayaranFilter = f);
                            }
                          },
                          selectedColor: const Color(0xFFFFFBEB),
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSel
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSel
                                ? const Color(0xFFD97706)
                                : AppColors.textDark,
                          ),
                          side: BorderSide(
                            color: isSel
                                ? const Color(0xFFF59E0B)
                                : Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // 4. Status Bonus
                    Text(
                      'Status Bonus',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _statusBonusFilters.map((f) {
                        final isSel = _statusBonusFilter == f;
                        return ChoiceChip(
                          label: Text(f == 'Semua' ? 'Semua Bonus' : f),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => _statusBonusFilter = f);
                              setState(() => _statusBonusFilter = f);
                            }
                          },
                          selectedColor: const Color(0xFFF3E8FF),
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSel
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSel
                                ? const Color(0xFF7E22CE)
                                : AppColors.textDark,
                          ),
                          side: BorderSide(
                            color: isSel
                                ? const Color(0xFFA855F7)
                                : Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // 5. Rentang Waktu
                    Text(
                      'Rentang Waktu',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...[
                          {'key': 'semua', 'label': 'Semua Waktu'},
                          {'key': 'hari_ini', 'label': 'Hari Ini'},
                          {'key': 'kemarin', 'label': 'Kemarin'},
                          {'key': 'besok', 'label': 'Besok'},
                          {'key': 'bulan_ini', 'label': 'Bulan Ini'},
                        ].map((item) {
                          final isSel = _periodFilter == item['key'];
                          return ChoiceChip(
                            label: Text(item['label']!),
                            selected: isSel,
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  _periodFilter = item['key']!;
                                  _customRange = null;
                                  if (_periodFilter == 'semua') {
                                    _filterStart = null;
                                    _filterEnd = null;
                                  }
                                });
                                setState(() {
                                  _periodFilter = item['key']!;
                                  _customRange = null;
                                  if (_periodFilter == 'semua') {
                                    _filterStart = null;
                                    _filterEnd = null;
                                  }
                                });
                              } else {
                                setModalState(() {
                                  _periodFilter = 'weekly_date';
                                  _customRange = null;
                                });
                                setState(() {
                                  _periodFilter = 'weekly_date';
                                  _customRange = null;
                                });
                              }
                            },
                            selectedColor: const Color(0xFFECFDF5),
                            labelStyle: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSel
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSel
                                  ? const Color(0xFF047857)
                                  : AppColors.textDark,
                            ),
                            side: BorderSide(
                              color: isSel
                                  ? const Color(0xFF10B981)
                                  : Colors.grey.shade300,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            showCheckmark: false,
                          );
                        }),
                        ActionChip(
                          avatar: const Icon(
                            Icons.calendar_month_rounded,
                            size: 14,
                            color: Color(0xFF4F46E5),
                          ),
                          label: Text(
                            _periodFilter == 'custom' && _customRange != null
                                ? '${DateFormat('dd/MM').format(_customRange!.start)} - ${DateFormat('dd/MM').format(_customRange!.end)}'
                                : 'Pilih Tanggal',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: _periodFilter == 'custom'
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _periodFilter == 'custom'
                                  ? const Color(0xFF4F46E5)
                                  : AppColors.textDark,
                            ),
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _pickCustomRange();
                          },
                          backgroundColor: _periodFilter == 'custom'
                              ? const Color(0xFFEEF2FF)
                              : Colors.white,
                          side: BorderSide(
                            color: _periodFilter == 'custom'
                                ? const Color(0xFF6366F1)
                                : Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Button Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                _statusFilter = 'Semua';
                                _statusUtamaFilter = 'Semua';
                                _statusPembayaranFilter = 'Semua';
                                _statusBonusFilter = 'Semua';
                                _periodFilter = 'weekly_date';
                                _customRange = null;
                                _filterStart = null;
                                _filterEnd = null;
                              });
                              setState(() {
                                _statusFilter = 'Semua';
                                _statusUtamaFilter = 'Semua';
                                _statusPembayaranFilter = 'Semua';
                                _statusBonusFilter = 'Semua';
                                _periodFilter = 'weekly_date';
                                _customRange = null;
                                _filterStart = null;
                                _filterEnd = null;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Reset',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Terapkan Filter',
                              style: GoogleFonts.inter(
                                fontSize: 14,
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
            );
          },
        );
      },
    );
  }

  Widget _buildFilterButton() {
    return GestureDetector(
      onTap: _showFilterBottomSheet,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.tune_rounded, size: 16, color: AppColors.textDark),
            const SizedBox(width: 6),
            Text(
              'Filter',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onTap,
    required this.onRefresh,
  });
  final OrderModel order;
  final VoidCallback onTap;
  final VoidCallback onRefresh;

  String _fmt(int n) =>
      'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  String _formatDisplayDate(String schedule) {
    if (schedule.isEmpty || schedule == '-') return '-';
    final parts = schedule.split('·');
    final datePart = parts[0].trim();
    String timePart = parts.length > 1 ? parts[1].trim() : '';

    if (timePart.endsWith(':00')) {
      final tParts = timePart.split(':');
      if (tParts.length >= 2) {
        timePart = '${tParts[0]}:${tParts[1]}';
      }
    }

    try {
      final dt = DateTime.parse(datePart);
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
      final dayNameReal = days[dt.weekday == 7 ? 0 : dt.weekday];
      final monthName = months[dt.month - 1];

      final formattedDate = '$dayNameReal, ${dt.day} $monthName ${dt.year}';
      return timePart.isNotEmpty ? '$formattedDate - $timePart' : formattedDate;
    } catch (e) {
      return schedule;
    }
  }

  Future<void> _launchWA(
    BuildContext context,
    String noWa, {
    String? template,
  }) async {
    String phone = noWa.replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('0')) {
      phone = '62${phone.substring(1)}';
    }
    final url = Uri.parse(
      'https://wa.me/$phone${template != null ? '?text=${Uri.encodeComponent(template)}' : ''}',
    );
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
        );
      }
    }
  }

  String _formatWADate(String rawDate) {
    if (rawDate.isEmpty) return ' | ';
    try {
      final parts = rawDate.split('-');
      if (parts.length != 3) return ' |$rawDate';
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final weekdays = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      return '${weekdays[dt.weekday - 1]}|${dt.day}-${dt.month}-${dt.year}';
    } catch (_) {
      return ' |$rawDate';
    }
  }

  String _generateInvoiceMessage(OrderModel o) {
    final customerName = o.customer.name;
    final branchName = o.customer.area.toUpperCase();
    final orderId = o.nomorPesanan.isNotEmpty ? o.nomorPesanan : o.id.toString();
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

    final int baseSubtotal = (o.subtotal > 0)
        ? o.subtotal
        : (o.services.isNotEmpty
            ? o.services.fold(0, (sum, s) => sum + s.subtotal)
            : o.total);
    final double diskonPersen = o.pembayaran?.diskonPersen ?? 0.0;
    final int diskonValue = (baseSubtotal * (diskonPersen / 100)).round();
    final int totalSetelahDiskon = baseSubtotal - diskonValue;

    final int ppnPersen = o.ppn ?? (o.pembayaran?.ppn ?? (o.isWajibPpn ? 11 : 0));
    final int ppnValue = (o.pembayaran != null || o.ppn != null || o.isWajibPpn)
        ? (totalSetelahDiskon * (ppnPersen / 100)).round()
        : 0;
    final int pphPersen = o.pph ?? o.pembayaran?.pph ?? 0;
    final int pphValue = (totalSetelahDiskon * (pphPersen / 100)).round();
    final int totalAkhir = totalSetelahDiskon + ppnValue - pphValue;

    return '''Halo Kak $customerName
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
Total Awal : ${_fmt(baseSubtotal).replaceAll('Rp ', '')}
Diskon : ${diskonValue > 0 ? _fmt(diskonValue).replaceAll('Rp ', '') : '0'}
PPn : ${_fmt(ppnValue).replaceAll('Rp ', '')}
*TOTAL BAYAR : ${_fmt(totalAkhir).replaceAll(' ', '')}*
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
  }

  String _generateTugasMessage(OrderModel o, {String? targetName}) {
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

    return '''Halo $haloNames, ada tugas baru untukmu! 
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
  }

  void _showCleanerSelectionModal(BuildContext context, OrderModel o) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pilih Cleaner',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              ...o.cleaners.map((c) {
                return ListTile(
                  leading: AppAvatar(
                    photoUrl: c.fotoProfil,
                    name: c.name,
                    size: 40,
                  ),
                  title: Text(
                    c.name,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    c.phone,
                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (c.phone.isNotEmpty) {
                      _launchWA(
                        context,
                        c.phone,
                        template: _generateTugasMessage(o, targetName: c.name),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nomor HP Cleaner tidak tersedia')),
                      );
                    }
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSimpleBadge(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusUtama(String label) {
    Color color;
    Color bg;
    final l = label.toLowerCase();
    if (l == 'done') {
      color = const Color(0xFF047857);
      bg = const Color(0xFFD1FAE5);
    } else if (l == 'process') {
      color = const Color(0xFF0284C7);
      bg = const Color(0xFFE0F2FE);
    } else if (l == 'dibatalkan') {
      color = const Color(0xFFDC2626);
      bg = const Color(0xFFFEE2E2);
    } else {
      color = const Color(0xFFD97706);
      bg = const Color(0xFFFEF3C7);
    }
    return _buildSimpleBadge(label, color, bg);
  }

  Widget _buildStatusBonus(String label) {
    Color color;
    Color bg;
    final l = label.toLowerCase();
    if (l == 'selesai' || l == 'disetujui') {
      color = const Color(0xFF7E22CE);
      bg = const Color(0xFFF3E8FF);
    } else {
      color = const Color(0xFF6B7280);
      bg = const Color(0xFFF3F4F6);
    }
    return _buildSimpleBadge('Bonus: $label', color, bg);
  }

  Widget _buildInfoItem(IconData icon, Color iconColor, String text) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWAButton({
    required String label,
    required VoidCallback onTap,
    required bool isOutlined,
  }) {
    const color = Color(0xFF25D366);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : color,
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            WhatsAppIcon(size: 16, color: isOutlined ? color : Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isOutlined ? color : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = order;
    final isCancelled = o.status == OrderStatus.cancelled;

    // Calculate total price accurately
    final int baseSubtotal = (o.subtotal > 0)
        ? o.subtotal
        : (o.services.isNotEmpty
            ? o.services.fold(0, (sum, s) => sum + s.subtotal)
            : o.total);
    final double diskonPersen = o.pembayaran?.diskonPersen ?? 0.0;
    final int diskonValue = (baseSubtotal * (diskonPersen / 100)).round();
    final int totalSetelahDiskon = baseSubtotal - diskonValue;
    final int ppnPersen = o.ppn ?? o.pembayaran?.ppn ?? 0;
    final int ppnValue = (o.pembayaran != null || o.ppn != null)
        ? (totalSetelahDiskon * (ppnPersen / 100)).round()
        : 0;
    final int totalAkhir = totalSetelahDiskon + ppnValue;

    String dateStr = _formatDisplayDate(o.schedule);
    final bool isDone = o.status == OrderStatus.completed;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        o.customer.name.isNotEmpty
                            ? o.customer.name.substring(0, 1).toUpperCase()
                            : '?',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (o.nomorPesanan.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              o.nomorPesanan,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        Text(
                          o.customer.name,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: Colors.red.shade400,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                o.customer.address.isNotEmpty
                                    ? o.customer.address
                                    : '-',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusUtama(o.statusUtamaLabel),
                ],
              ),
            ),

            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border.withValues(alpha: 0.5),
            ),

            // Details Grid
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildInfoItem(
                        Icons.calendar_month_rounded,
                        Colors.orange,
                        dateStr,
                      ),
                      const SizedBox(width: 12),
                      _buildInfoItem(
                        Icons.cleaning_services_rounded,
                        Colors.blue,
                        o.services.isNotEmpty
                            ? o.services.map((s) => s.name).join(', ')
                            : '-',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildInfoItem(
                        Icons.person_rounded,
                        Colors.purple,
                        o.cleaners.isNotEmpty
                            ? o.cleaners.map((c) => c.name).join(', ')
                            : 'Belum ada cleaner',
                      ),
                      const SizedBox(width: 12),
                      _buildInfoItem(
                        Icons.payments_rounded,
                        Colors.green,
                        o.paymentMethod.toUpperCase(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Action Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Biaya',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _fmt(totalAkhir),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        WorkStatusBadge(status: o.status),
                        PaymentStatusBadge(order: o),
                        _buildStatusBonus(o.statusBonusLabel),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => PdfInvoiceService.showPrintDialog(context, o),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Icon(
                            Icons.print_rounded,
                            color: Color(0xFF0284C7),
                            size: 19,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildWAButton(
                          label: 'Chat Customer',
                          onTap: () => _launchWA(
                            context,
                            o.customer.phone,
                            template: _generateInvoiceMessage(o),
                          ),
                          isOutlined: true,
                        ),
                      ),
                      if (o.cleaners.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildWAButton(
                            label: 'Chat Cleaner',
                            onTap: () {
                              if (o.cleaners.length == 1) {
                                _launchWA(
                                  context,
                                  o.cleaners.first.phone,
                                  template: _generateTugasMessage(o, targetName: o.cleaners.first.name),
                                );
                              } else {
                                _showCleanerSelectionModal(context, o);
                              }
                            },
                            isOutlined: false,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
