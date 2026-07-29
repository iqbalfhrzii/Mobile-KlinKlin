import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/data/finance_models.dart';
import '../../../core/data/hrd_models.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/finance_service.dart';

class FinancePengeluaranScreen extends StatefulWidget {
  const FinancePengeluaranScreen({super.key});

  @override
  State<FinancePengeluaranScreen> createState() => _FinancePengeluaranScreenState();
}

class _FinancePengeluaranScreenState extends State<FinancePengeluaranScreen> {
  final FinanceService _financeService = FinanceService();
  bool _isLoading = true;
  String _error = '';
  
  List<PengeluaranModel> _pengeluaranList = [];
  double _totalPengeluaran = 0;

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
      final res = await _financeService.fetchPengeluaran(
        search: _searchQuery,
        startDate: _filterStart != null ? DateFormat('yyyy-MM-dd').format(_filterStart!) : null,
        endDate: _filterEnd != null ? DateFormat('yyyy-MM-dd').format(_filterEnd!) : null,
      );
      
      final items = res.map((e) => PengeluaranModel.fromJson(e)).toList();
      double total = 0;
      for (var p in items) {
        total += p.nominal;
      }

      if (mounted) {
        setState(() {
          _pengeluaranList = items;
          _totalPengeluaran = total;
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement Create Pengeluaran Form
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form Tambah Pengeluaran belum tersedia')));
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
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
                      Text('Pengeluaran', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('Daftar Pengeluaran Operasional', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
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
                        hintText: 'Cari Keterangan atau Kategori...',
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
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL PENGELUARAN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                    const SizedBox(height: 4),
                    Text(_formatCurrency(_totalPengeluaran), style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                  ],
                ),
              ),
            ),
            
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                    : _pengeluaranList.isEmpty
                        ? const Center(child: Text('Tidak ada data pengeluaran'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _pengeluaranList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _pengeluaranList[index];
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          item.nomorTransaksi,
                                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        Text(
                                          item.tanggalPengeluaran != null ? DateFormat('dd MMM yyyy').format(item.tanggalPengeluaran!) : '-',
                                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.orange.shade200),
                                      ),
                                      child: Text(
                                        item.kategori.toUpperCase(),
                                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Keterangan: ${item.keterangan}',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                    if (item.cabang != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Cabang: ${item.cabang!.namaCabang}',
                                          style: GoogleFonts.inter(fontSize: 12),
                                        ),
                                      ),
                                    const Divider(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Nominal', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                        Text(
                                          _formatCurrency(item.nominal),
                                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red.shade700),
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
