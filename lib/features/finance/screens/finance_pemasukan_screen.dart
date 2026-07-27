import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/data/finance_models.dart';
import '../../../core/data/order_model.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/finance_service.dart';

class FinancePemasukanScreen extends StatefulWidget {
  const FinancePemasukanScreen({super.key});

  @override
  State<FinancePemasukanScreen> createState() => _FinancePemasukanScreenState();
}

class _FinancePemasukanScreenState extends State<FinancePemasukanScreen> {
  final FinanceService _financeService = FinanceService();
  bool _isLoading = true;
  String _error = '';
  
  List<PemasukanModel> _pemasukanList = [];
  double _totalPemasukan = 0;

  String _searchQuery = '';
  DateTime? _filterStart;
  DateTime? _filterEnd;

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
      final res = await _financeService.fetchPemasukan(
        search: _searchQuery,
        startDate: _filterStart != null ? DateFormat('yyyy-MM-dd').format(_filterStart!) : null,
        endDate: _filterEnd != null ? DateFormat('yyyy-MM-dd').format(_filterEnd!) : null,
      );
      
      final items = (res['items'] as List).map((e) => PemasukanModel.fromJson(e)).toList();
      if (mounted) {
        setState(() {
          _pemasukanList = items;
          _totalPemasukan = double.tryParse(res['total'].toString()) ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  String _formatCurrency(double val) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(val);
  }

  void _showDateFilter() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _filterStart = picked.start;
        _filterEnd = picked.end;
      });
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            child: Row(
              children: [
                const BackButton(color: Colors.white),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pemasukan', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('Daftar Pemasukan dari Pesanan', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      onSubmitted: (_) => _fetchData(),
                      decoration: const InputDecoration(
                        icon: Icon(Icons.search, size: 20, color: Colors.grey),
                        hintText: 'Cari Pesanan atau Pelanggan...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _showDateFilter,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _filterStart != null ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _filterStart != null ? AppColors.primary : Colors.grey.shade300),
                    ),
                    child: Icon(Icons.date_range_rounded, color: _filterStart != null ? Colors.white : Colors.grey, size: 20),
                  ),
                ),
              ],
            ),
          ),

          if (!_isLoading && _error.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL PEMASUKAN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 4),
                    Text(_formatCurrency(_totalPemasukan), style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
              ),
            ),
            
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                    : _pemasukanList.isEmpty
                        ? const Center(child: Text('Tidak ada data pemasukan'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _pemasukanList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _pemasukanList[index];
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          item.pesanan?.id ?? 'PESANAN KOSONG',
                                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        Text(
                                          item.tanggalPemasukan != null ? DateFormat('dd MMM yyyy, HH:mm').format(item.tanggalPemasukan!) : '-',
                                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Pelanggan: ${item.pesanan?.customer.name ?? '-'}',
                                      style: GoogleFonts.inter(fontSize: 12),
                                    ),
                                    Text(
                                      'Keterangan: ${item.keterangan}',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                    const Divider(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Nominal', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                        Text(
                                          _formatCurrency(item.nominal),
                                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
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
      ),
    );
  }
}
