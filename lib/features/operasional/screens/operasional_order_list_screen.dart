import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/data/order_model.dart';
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Search
                  Container(
                    width: 200,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Cari pelanggan, ID...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      style: GoogleFonts.inter(fontSize: 12),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Cabang
                  _buildDropdown(_cabangOptions, _selectedCabang, (v) => setState(() => _selectedCabang = v!)),
                  const SizedBox(width: 8),
                  
                  // Status
                  _buildDropdown(_statusOptions, _selectedStatus, (v) => setState(() => _selectedStatus = v!)),
                  const SizedBox(width: 8),

                  // Hari
                  _buildDropdown(_dayOptions, _selectedDayFilter, _onDayFilterChanged),
                ],
              ),
            ),
          ),

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

  Widget _buildDropdown(List<String> items, String value, ValueChanged<String?> onChanged) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTable() {
    final data = _filteredOrders;
    if (data.isEmpty) {
      return const Center(child: Text('Tidak ada pesanan ditemukan.'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('CABANG')),
            DataColumn(label: Text('PELANGGAN')),
            DataColumn(label: Text('JADWAL')),
            DataColumn(label: Text('SUBTOTAL')),
            DataColumn(label: Text('CLEANER')),
            DataColumn(label: Text('STATUS UTAMA')),
            DataColumn(label: Text('AKSI')),
          ],
          rows: data.map((o) {
            return DataRow(
              cells: [
                DataCell(Text(o.nomorPesanan, style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
                DataCell(Text(o.customer.area)),
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.customer.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      Text(o.customer.phone, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                    ],
                  )
                ),
                DataCell(Text(DateFormat('dd MMM yyyy HH:mm').format(o.scheduleDateTime))),
                DataCell(Text(_formatCurrency(o.subtotal))),
                DataCell(Text(o.cleaners.isNotEmpty ? o.cleaners.map((c) => c.name).join('\n') : '-')),
                DataCell(_buildStatusUtamaBadge(o.statusUtamaLabel)),
                DataCell(
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o)),
                      ).then((_) => _fetchData());
                    },
                    child: const Text('Detail'),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusUtamaBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'done':
        color = Colors.green;
        break;
      case 'process':
        color = Colors.blue;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      case 'draft':
      default:
        color = Colors.grey;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
