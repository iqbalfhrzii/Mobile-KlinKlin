import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';

class UangKasTransaction {
  final String id;
  final String title;
  final String description;
  final int amount;
  final bool isIncome;
  final DateTime date;

  UangKasTransaction({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.isIncome,
    required this.date,
  });
}

class UangKasScreen extends StatefulWidget {
  const UangKasScreen({super.key});

  @override
  State<UangKasScreen> createState() => _UangKasScreenState();
}

class _UangKasScreenState extends State<UangKasScreen> {
  // Mock Data
  final List<UangKasTransaction> _transactions = [
    UangKasTransaction(
      id: '1',
      title: 'Pemasukan Kas Pusat',
      description: 'Modal kas awal bulan untuk cabang',
      amount: 1500000,
      isIncome: true,
      date: DateTime.now().subtract(const Duration(days: 5)),
    ),
    UangKasTransaction(
      id: '2',
      title: 'Beli Sabun Cuci & Pembersih',
      description: 'Restock cairan pembersih lantai dan kaca',
      amount: 150000,
      isIncome: false,
      date: DateTime.now().subtract(const Duration(days: 4)),
    ),
    UangKasTransaction(
      id: '3',
      title: 'Bensin Operasional',
      description: 'Isi bensin untuk transport cleaner',
      amount: 50000,
      isIncome: false,
      date: DateTime.now().subtract(const Duration(days: 3)),
    ),
    UangKasTransaction(
      id: '4',
      title: 'Tambahan Kas',
      description: 'Tambahan dana operasional mendadak',
      amount: 500000,
      isIncome: true,
      date: DateTime.now().subtract(const Duration(days: 2)),
    ),
    UangKasTransaction(
      id: '5',
      title: 'Ganti Sapu & Pel',
      description: 'Beli 2 sapu lidi dan 1 kain pel baru',
      amount: 80000,
      isIncome: false,
      date: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  DateTimeRange? _selectedDateRange;
  bool? _typeFilter;

  String _formatRupiah(int n) =>
      'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  String _formatDate(DateTime dt) => DateFormat('dd MMM yyyy, HH:mm').format(dt);

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (range != null) {
      setState(() => _selectedDateRange = range);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter transactions
    final filteredTransactions = _transactions.where((tx) {
      if (_typeFilter != null && tx.isIncome != _typeFilter) return false;
      if (_selectedDateRange != null) {
        final date = DateTime(tx.date.year, tx.date.month, tx.date.day);
        final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
        if (date.isBefore(start) || date.isAfter(end)) return false;
      }
      return true;
    }).toList();

    filteredTransactions.sort((a, b) => b.date.compareTo(a.date));

    // Calculate totals based on ALL transactions for the header balance, OR filtered by date?
    // Usually header totals are filtered by date, but NOT by typeFilter so it always shows the period's balance.
    int totalPemasukan = 0;
    int totalPengeluaran = 0;

    for (var tx in _transactions) {
      if (_selectedDateRange != null) {
        final date = DateTime(tx.date.year, tx.date.month, tx.date.day);
        final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
        if (date.isBefore(start) || date.isAfter(end)) continue;
      }
      if (tx.isIncome) {
        totalPemasukan += tx.amount;
      } else {
        totalPengeluaran += tx.amount;
      }
    }

    final int saldoSekarang = totalPemasukan - totalPengeluaran;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(saldoSekarang, totalPemasukan, totalPengeluaran),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Riwayat Transaksi',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                InkWell(
                  onTap: _pickDateRange,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedDateRange != null ? AppColors.primary.withOpacity(0.1) : Colors.white,
                      border: Border.all(color: _selectedDateRange != null ? AppColors.primary : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 14, color: _selectedDateRange != null ? AppColors.primary : AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          _selectedDateRange != null 
                              ? '${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM').format(_selectedDateRange!.end)}'
                              : 'Filter Tanggal',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _selectedDateRange != null ? AppColors.primary : AppColors.textMuted,
                          ),
                        ),
                        if (_selectedDateRange != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => setState(() => _selectedDateRange = null),
                            child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 12, bottom: 24, left: 16, right: 16),
              itemCount: filteredTransactions.length,
              itemBuilder: (context, index) {
                final tx = filteredTransactions[index];
                return _buildTransactionCard(tx);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implement add transaction
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fitur Tambah Kas belum tersedia')),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Catat Kas',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildHeader(int saldo, int pemasukan, int pengeluaran) {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Uang Kas Cabang',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Saldo Saat Ini',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatRupiah(saldo),
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Pemasukan',
                  amount: pemasukan,
                  icon: Icons.arrow_downward_rounded,
                  color: Colors.greenAccent,
                  isSelected: _typeFilter == true,
                  onTap: () {
                    setState(() {
                      _typeFilter = _typeFilter == true ? null : true;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Pengeluaran',
                  amount: pengeluaran,
                  icon: Icons.arrow_upward_rounded,
                  color: Colors.redAccent,
                  isSelected: _typeFilter == false,
                  onTap: () {
                    setState(() {
                      _typeFilter = _typeFilter == false ? null : false;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required int amount,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color.withOpacity(0.5) : Colors.white.withOpacity(0.2), width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.3) : color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatRupiah(amount),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
    );
  }

  Widget _buildTransactionCard(UangKasTransaction tx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tx.isIncome 
                  ? const Color(0xFF10B981).withOpacity(0.1) 
                  : const Color(0xFFEF4444).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              tx.isIncome ? Icons.account_balance_wallet_rounded : Icons.shopping_bag_rounded,
              color: tx.isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        tx.title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${tx.isIncome ? '+' : '-'}${_formatRupiah(tx.amount)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: tx.isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  tx.description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _formatDate(tx.date),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
