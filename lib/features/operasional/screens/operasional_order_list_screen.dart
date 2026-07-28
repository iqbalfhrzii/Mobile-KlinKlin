import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/data/order_model.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/whatsapp_icon.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../orders/services/order_service.dart';
import '../../orders/screens/order_detail_screen.dart';

class OperasionalOrderListScreen extends StatefulWidget {
  final bool hideHeader;
  const OperasionalOrderListScreen({super.key, this.hideHeader = false});

  @override
  State<OperasionalOrderListScreen> createState() => _OperasionalOrderListScreenState();
}

class _OperasionalOrderListScreenState extends State<OperasionalOrderListScreen> {
  final OrderService _orderService = OrderService();
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  String _error = '';

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedCabang = 'Semua Cabang'; // For now we keep it simple or we can extract from orders
  String _selectedStatus = 'Semua Status Utama';
  String _selectedDayFilter = 'Semua Hari';
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  final List<String> _statusOptions = [
    'Semua Status Utama',
    'Draft',
    'Process',
    'Pending',
    'Done',
    'Cancelled'
  ];
  
  final List<String> _dayOptions = [
    'Semua Hari',
    'Hari Ini',
    'Kemarin',
    'Kustom Tanggal'
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      // In Operasional, we want to fetch all branches if they are a superadmin.
      // fetchOrders by default fetches all if no cabangId is specified and role isn't CS.
      final data = await _orderService.fetchOrders();
      setState(() {
        _orders = data;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<String> get _cabangOptions {
    final Set<String> cabangs = {'Semua Cabang'};
    for (var o in _orders) {
      cabangs.add(o.customer.area);
    }
    return cabangs.toList();
  }

  List<OrderModel> get _filteredOrders {
    return _orders.where((o) {
      // Search
      final q = _searchQuery.toLowerCase();
      final matchQ = q.isEmpty ||
          o.nomorPesanan.toLowerCase().contains(q) ||
          o.customer.name.toLowerCase().contains(q) ||
          o.cleaners.any((c) => c.name.toLowerCase().contains(q));

      // Cabang
      final matchCabang = _selectedCabang == 'Semua Cabang' || o.customer.area == _selectedCabang;

      // Status
      final matchStatus = _selectedStatus == 'Semua Status Utama' ||
          o.statusUtamaLabel.toLowerCase() == _selectedStatus.toLowerCase();

      // Date
      bool matchDate = true;
      final orderDate = o.tanggalInput;
      final now = DateTime.now();
      if (_selectedDayFilter == 'Hari Ini') {
        matchDate = orderDate.year == now.year && orderDate.month == now.month && orderDate.day == now.day;
      } else if (_selectedDayFilter == 'Kemarin') {
        final yesterday = now.subtract(const Duration(days: 1));
        matchDate = orderDate.year == yesterday.year && orderDate.month == yesterday.month && orderDate.day == yesterday.day;
      } else if (_selectedDayFilter == 'Kustom Tanggal' && _filterStartDate != null && _filterEndDate != null) {
        matchDate = orderDate.isAfter(_filterStartDate!.subtract(const Duration(days: 1))) &&
            orderDate.isBefore(_filterEndDate!.add(const Duration(days: 1)));
      }

      return matchQ && matchCabang && matchStatus && matchDate;
    }).toList();
  }

  void _onDayFilterChanged(String? val) async {
    if (val == null) return;
    if (val == 'Kustom Tanggal') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      if (picked != null) {
        setState(() {
          _selectedDayFilter = val;
          _filterStartDate = picked.start;
          _filterEndDate = picked.end;
        });
      }
    } else {
      setState(() {
        _selectedDayFilter = val;
      });
    }
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          if (!widget.hideHeader)
            GradientHeader(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daftar Pesanan Operasional',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Lihat semua data pesanan dari seluruh cabang',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _fetchData,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    tooltip: 'Refresh Data',
                  )
                ],
              ),
            ),
          
          // Filters
          const SizedBox(height: 16),
          _buildProMaxSearchAndFilterBar(),
          const SizedBox(height: 14),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                    : _buildTable(),
          )
        ],
      ),
    );
  }

  Widget _buildProMaxSearchAndFilterBar() {
    int activeFilterCount = 0;
    if (_selectedCabang != 'Semua Cabang') activeFilterCount++;
    if (_selectedStatus != 'Semua Status Utama') activeFilterCount++;
    if (_selectedDayFilter != 'Semua Hari') activeFilterCount++;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(23),
                border: Border.all(
                  color: _searchQuery.isNotEmpty ? AppColors.primary : Colors.grey.withOpacity(0.25),
                  width: _searchQuery.isNotEmpty ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _searchQuery.isNotEmpty ? AppColors.primary.withOpacity(0.12) : Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: _searchQuery.isNotEmpty ? AppColors.primary : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: 'Cari pelanggan atau no pesanan...',
                        hintStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.textMuted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 14, color: AppColors.textMuted),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _showFilterModal,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: activeFilterCount > 0 ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(23),
                border: Border.all(color: activeFilterCount > 0 ? AppColors.primary : Colors.grey.withOpacity(0.25)),
                boxShadow: [
                  BoxShadow(color: activeFilterCount > 0 ? AppColors.primary.withOpacity(0.3) : Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: activeFilterCount > 0 ? Colors.white : AppColors.textDark),
                  const SizedBox(width: 6),
                  Text(
                    activeFilterCount > 0 ? 'Filter ($activeFilterCount)' : 'Filter',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: activeFilterCount > 0 ? Colors.white : AppColors.textDark),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Filter Pesanan', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Cabang', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _cabangOptions.map((c) => _buildFilterChip(c, _selectedCabang == c, () {
                            setModalState(() => _selectedCabang = c);
                            setState(() => _selectedCabang = c);
                          })).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text('Status Utama', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _statusOptions.map((s) => _buildFilterChip(s, _selectedStatus == s, () {
                            setModalState(() => _selectedStatus = s);
                            setState(() => _selectedStatus = s);
                          })).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text('Periode', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _dayOptions.map((d) => _buildFilterChip(d, _selectedDayFilter == d, () {
                            setModalState(() => _selectedDayFilter = d);
                            _onDayFilterChanged(d);
                          })).toList(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _fetchData(); // Just in case, although filters apply locally
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Terapkan Filter', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
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

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildTable() {
    final data = _filteredOrders;
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Tidak ada pesanan ditemukan.', style: GoogleFonts.inter(fontSize: 16, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: data.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildOrderCard(data[index]),
    );
  }

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
      final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
      final months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      final dayNameReal = days[dt.weekday == 7 ? 0 : dt.weekday];
      final monthName = months[dt.month - 1];

      final formattedDate = '$dayNameReal, ${dt.day} $monthName ${dt.year}';
      return timePart.isNotEmpty ? '$formattedDate - $timePart' : formattedDate;
    } catch (e) {
      return schedule;
    }
  }

  Widget _buildSimpleBadge(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color),
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

  Widget _buildInfoItemCS(IconData icon, Color iconColor, String text) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
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
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textDark),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel o) {
    final double diskonPersen = o.pembayaran?.diskonPersen ?? 0.0;
    final int diskonValue = (o.total * (diskonPersen / 100)).round();
    final int totalSetelahDiskon = o.total - diskonValue;
    final int ppnPersen = o.ppn ?? o.pembayaran?.ppn ?? 0;
    final int ppnValue = (o.pembayaran != null || o.ppn != null) ? (totalSetelahDiskon * (ppnPersen / 100)).round() : 0;
    final int totalAkhir = totalSetelahDiskon + ppnValue;
    final dateStr = _formatDisplayDate(o.schedule);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o, isReadOnly: true)),
        ).then((_) => _fetchData());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withOpacity(0.8)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
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
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        o.customer.name.isNotEmpty ? o.customer.name.substring(0, 1).toUpperCase() : '?',
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.customer.name,
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 14, color: Colors.red.shade400),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                o.customer.address.isNotEmpty ? o.customer.address : '-',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
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
            
            Divider(height: 1, thickness: 1, color: AppColors.border.withOpacity(0.5)),
            
            // Details Grid
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildInfoItemCS(Icons.calendar_month_rounded, Colors.orange, dateStr),
                      const SizedBox(width: 12),
                      _buildInfoItemCS(Icons.cleaning_services_rounded, Colors.blue, o.services.isNotEmpty ? o.services.map((s) => s.name).join(', ') : '-'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildInfoItemCS(Icons.person_rounded, Colors.purple, o.cleaners.isNotEmpty ? o.cleaners.map((c) => c.name).join(', ') : 'Belum ada cleaner'),
                      const SizedBox(width: 12),
                      _buildInfoItemCS(Icons.payments_rounded, Colors.green, o.paymentMethod.toUpperCase()),
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
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Biaya', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                      Text(_fmt(totalAkhir), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
