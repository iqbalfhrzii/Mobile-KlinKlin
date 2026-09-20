import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/data/order_model.dart';
import '../../../core/data/hrd_models.dart';
import '../../orders/services/order_service.dart';
import '../../orders/screens/order_detail_screen.dart';
import '../../hrd/services/hrd_service.dart';

class CeoTransaksiBesarScreen extends StatefulWidget {
  final String? initialPesananId;

  const CeoTransaksiBesarScreen({
    super.key,
    this.initialPesananId,
  });

  @override
  State<CeoTransaksiBesarScreen> createState() => _CeoTransaksiBesarScreenState();
}

class _CeoTransaksiBesarScreenState extends State<CeoTransaksiBesarScreen> {
  final OrderService _orderService = OrderService();
  final HrdService _hrdService = HrdService();

  bool _isLoading = true;
  String _errorMessage = '';

  List<OrderModel> _allOrders = [];
  List<CabangModel> _cabangList = [];

  String _searchQuery = '';
  int? _selectedCabangId;
  String _selectedPeriode = 'Semua'; // 'Semua', 'Hari Ini', 'Bulan Ini', '30 Hari'

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. Ambil data cabang
      try {
        final cabangs = await _hrdService.fetchCabang();
        _cabangList = cabangs;
      } catch (e) {
        debugPrint('Gagal memuat cabang: $e');
      }

      // 2. Ambil list order secara global (tanpa filter cabang untuk CEO)
      final orders = await _orderService.fetchOrders(
        fetchAllPages: true,
        perPage: 100,
      );

      // 3. Jika ada initialPesananId dari notifikasi, pastikan order tersebut ada di list
      if (widget.initialPesananId != null && widget.initialPesananId!.isNotEmpty) {
        final exists = orders.any((o) => o.id == widget.initialPesananId);
        if (!exists) {
          try {
            final specificOrder = await _orderService.fetchOrderDetail(widget.initialPesananId!);
            orders.insert(0, specificOrder);
          } catch (e) {
            debugPrint('Gagal mengambil order spesifik dari notifikasi: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _allOrders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data transaksi: $e';
          _isLoading = false;
        });
      }
    }
  }

  int _getOrderNominal(OrderModel order) {
    if (order.pembayaran?.total != null && order.pembayaran!.total! > 0) {
      return order.pembayaran!.total!;
    }
    if (order.total > 0) {
      return order.total;
    }
    if (order.subtotal > 0) {
      return order.subtotal;
    }
    return 0;
  }

  bool _isTransaksiBesar(OrderModel order) {
    // Selalu tampilkan jika ini order yang diklik dari notifikasi
    if (widget.initialPesananId != null && order.id == widget.initialPesananId) {
      return true;
    }
    final nominal = _getOrderNominal(order);
    return nominal >= 1000000;
  }

  List<OrderModel> get _filteredOrders {
    final now = DateTime.now();

    return _allOrders.where((order) {
      // 1. Hanya transaksi > 1 Juta (atau target order dari notifikasi)
      if (!_isTransaksiBesar(order)) {
        return false;
      }

      // 2. Filter Cabang
      if (_selectedCabangId != null) {
        if (order.cabangId != _selectedCabangId.toString()) {
          return false;
        }
      }

      // 3. Filter Periode
      final orderDate = order.tanggalInput;
      if (_selectedPeriode == 'Hari Ini') {
        final isSameDay = orderDate.year == now.year &&
            orderDate.month == now.month &&
            orderDate.day == now.day;
        if (!isSameDay) return false;
      } else if (_selectedPeriode == 'Bulan Ini') {
        final isSameMonth = orderDate.year == now.year && orderDate.month == now.month;
        if (!isSameMonth) return false;
      } else if (_selectedPeriode == '30 Hari') {
        final diff = now.difference(orderDate).inDays;
        if (diff > 30) return false;
      }

      // 4. Filter Pencarian
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final noOrder = order.nomorPesanan.toLowerCase();
        final custName = order.customer.name.toLowerCase();
        final custPhone = order.customer.phone.toLowerCase();
        final cabang = order.cabangNama.toLowerCase();
        final csName = order.createdByName.toLowerCase();

        final match = noOrder.contains(q) ||
            custName.contains(q) ||
            custPhone.contains(q) ||
            cabang.contains(q) ||
            csName.contains(q);
        if (!match) return false;
      }

      return true;
    }).toList()
      ..sort((a, b) {
        // Prioritaskan order dari notifikasi di paling atas
        if (widget.initialPesananId != null) {
          if (a.id == widget.initialPesananId) return -1;
          if (b.id == widget.initialPesananId) return 1;
        }
        return b.tanggalInput.compareTo(a.tanggalInput);
      });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;
    final totalNominal = filtered.fold<int>(0, (sum, o) => sum + _getOrderNominal(o));
    final count = filtered.length;
    final avgNominal = count > 0 ? (totalNominal / count).round() : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary KPI Cards
                    _buildSummaryCards(count, totalNominal, avgNominal),
                    const SizedBox(height: 18),

                    // Filter & Search Controls
                    _buildFilterSection(),
                    const SizedBox(height: 16),

                    // Content Area
                    if (_isLoading)
                      _buildLoadingIndicator()
                    else if (_errorMessage.isNotEmpty)
                      _buildErrorWidget()
                    else if (filtered.isEmpty)
                      _buildEmptyState()
                    else
                      _buildOrderList(filtered),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Transaksi > Rp 1 Jt',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        'CEO / Eksekutif',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFEF3C7),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Monitoring pembayaran & pesanan bernilai tinggi',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            onPressed: _loadData,
            tooltip: 'Segarkan data',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(int count, int totalNominal, int avgNominal) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            label: 'Total Pesanan',
            value: '$count Order',
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFFF59E0B),
            bgColor: const Color(0xFFFFFBEB),
            borderColor: const Color(0xFFFDE68A),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            label: 'Total Nilai',
            value: _currencyFormat.format(totalNominal),
            icon: Icons.payments_rounded,
            iconColor: const Color(0xFF10B981),
            bgColor: const Color(0xFFECFDF5),
            borderColor: const Color(0xFFA7F3D0),
            isHighlighted: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            label: 'Rata-rata',
            value: _currencyFormat.format(avgNominal),
            icon: Icons.analytics_rounded,
            iconColor: const Color(0xFF3B82F6),
            bgColor: const Color(0xFFEFF6FF),
            borderColor: const Color(0xFFBFDBFE),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: isHighlighted ? const Color(0xFF047857) : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          // Search Input
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Cari no. order, customer, cabang...',
              hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          const SizedBox(height: 12),

          // Cabang & Periode Filter
          Row(
            children: [
              // Dropdown Cabang
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _selectedCabangId,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                      hint: Text(
                        'Semua Cabang',
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF475569)),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'Semua Cabang',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        ..._cabangList.map((c) => DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text(
                                c.namaCabang,
                                style: GoogleFonts.inter(fontSize: 11.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                      ],
                      onChanged: (val) => setState(() => _selectedCabangId = val),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Filter Periode Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Semua', 'Hari Ini', 'Bulan Ini'].map((periode) {
                    final isSelected = _selectedPeriode == periode;
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: InkWell(
                        onTap: () => setState(() => _selectedPeriode = periode),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            periode,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<OrderModel> orders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Text(
            'Daftar Transaksi (${orders.length})',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF334155),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = orders[index];
            final isTargetFromNotification = widget.initialPesananId != null && order.id == widget.initialPesananId;
            return _buildOrderCard(order, isTargetFromNotification);
          },
        ),
      ],
    );
  }

  Widget _buildOrderCard(OrderModel order, bool isTarget) {
    final nominal = _getOrderNominal(order);
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(order.tanggalInput);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTarget ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
          width: isTarget ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isTarget ? const Color(0xFFF59E0B).withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.03),
            blurRadius: isTarget ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Highlight Banner jika diklik dari notifikasi
          if (isTarget)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFFFFFBEB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, size: 14, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Text(
                    'Pesanan yang dipilih dari Notifikasi',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris 1: No. Pesanan & Badge Nominal Besar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  order.cabangNama.isNotEmpty ? order.cabangNama : 'KlinKlin',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  order.nomorPesanan.isNotEmpty ? order.nomorPesanan : '#${order.id}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Badge Nominal Utama (> 1 Juta)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.attach_money_rounded, size: 16, color: Color(0xFF059669)),
                          Text(
                            _currencyFormat.format(nominal),
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),

                // Baris 2: Data Pelanggan & Alamat
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.person_rounded, size: 18, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customer.name,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.customer.address.isNotEmpty
                                ? order.customer.address
                                : (order.customer.area.isNotEmpty ? order.customer.area : '-'),
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Baris 3: Ringkasan Layanan
                if (order.services.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0).withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Layanan yang dipesan:',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...order.services.take(3).map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF0284C7)),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      '${s.name} (${s.qty}x)',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        color: const Color(0xFF334155),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    _currencyFormat.format(s.price),
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        if (order.services.length > 3)
                          Text(
                            '+ ${order.services.length - 3} layanan lainnya',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Baris 4: Status Badges & Button Lihat Detail
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Badges
                    Row(
                      children: [
                        _buildStatusChip(
                          label: order.statusPembayaranLabel,
                          color: order.statusPembayaranLabel == 'Disetujui' || order.statusPembayaranLabel == 'Lunas'
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B),
                          bgColor: order.statusPembayaranLabel == 'Disetujui' || order.statusPembayaranLabel == 'Lunas'
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFFFBEB),
                        ),
                        const SizedBox(width: 6),
                        _buildStatusChip(
                          label: order.statusPengerjaanLabel,
                          color: const Color(0xFF0284C7),
                          bgColor: const Color(0xFFF0F9FF),
                        ),
                      ],
                    ),

                    // Button Action
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderDetailScreen(
                              order: order,
                              isReadOnly: true,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Detail',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 11),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 14),
            Text(
              'Memuat data transaksi besar...',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 36, color: Color(0xFFEF4444)),
          const SizedBox(height: 10),
          Text(
            _errorMessage,
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF991B1B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.monetization_on_outlined, size: 36, color: Color(0xFFD97706)),
          ),
          const SizedBox(height: 14),
          Text(
            'Tidak Ada Transaksi > Rp 1 Juta',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty || _selectedCabangId != null || _selectedPeriode != 'Semua'
                ? 'Tidak ditemukan transaksi yang cocok dengan filter yang Anda pilih.'
                : 'Belum ada transaksi pesanan senilai di atas Rp 1.000.000.',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
