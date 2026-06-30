import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/cleaner_job_service.dart';

class CleanerHistoryScreen extends StatefulWidget {
  const CleanerHistoryScreen({super.key});

  @override
  State<CleanerHistoryScreen> createState() => _CleanerHistoryScreenState();
}

class _CleanerHistoryScreenState extends State<CleanerHistoryScreen> {
  final CleanerJobService _service = CleanerJobService();
  bool _isLoading = true;
  String _error = '';
  Map<String, dynamic>? _historyData;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  static const List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final data = await _service.fetchHistory(month: _selectedMonth, year: _selectedYear);
      if (mounted) {
        setState(() {
          _historyData = data;
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

  String _formatRupiah(num value) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(value);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  num _parseNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Riwayat Pekerjaan', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('Daftar pekerjaan selesai dan bonusmu', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.8))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.history_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchHistory,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    final totalBonus = _parseNum(_historyData?['total_bonus']);
    final List<dynamic> pesanans = _historyData?['pesanans'] ?? [];

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildMonthPicker(),
          _buildTotalBonusCard(totalBonus),
          const SizedBox(height: 24),
          Text(
            'Daftar Riwayat',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          if (pesanans.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  'Belum ada riwayat pekerjaan selesai.',
                  style: GoogleFonts.inter(color: AppColors.textMuted),
                ),
              ),
            )
          else
            ...pesanans.map((job) => _buildJobCard(job)),
        ],
      ),
    );
  }

  Widget _buildMonthPicker() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textMuted.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Periode',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                '${_monthNames[_selectedMonth - 1]} $_selectedYear',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
            onPressed: _showMonthYearPicker,
          ),
        ],
      ),
    );
  }

  Future<void> _showMonthYearPicker() async {
    int tempMonth = _selectedMonth;
    int tempYear = _selectedYear;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Pilih Periode', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
              content: Row(
                children: [
                  Expanded(
                    child: DropdownButton<int>(
                      value: tempMonth,
                      isExpanded: true,
                      items: List.generate(12, (index) {
                        return DropdownMenuItem(
                          value: index + 1,
                          child: Text(_monthNames[index], style: GoogleFonts.inter()),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) setStateDialog(() => tempMonth = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButton<int>(
                      value: tempYear,
                      isExpanded: true,
                      items: List.generate(5, (index) {
                        int year = DateTime.now().year - 2 + index;
                        return DropdownMenuItem(
                          value: year,
                          child: Text(year.toString(), style: GoogleFonts.inter()),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) setStateDialog(() => tempYear = val);
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedMonth = tempMonth;
                      _selectedYear = tempYear;
                    });
                    _fetchHistory();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Terapkan', style: GoogleFonts.inter(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTotalBonusCard(num totalBonus) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Total Bonus Terkumpul',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatRupiah(totalBonus),
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final pesanan = job['pesanan'] ?? {};
    final pelanggan = pesanan['pelanggan'] ?? {};
    final namaPelanggan = pelanggan['nama_pelanggan'] ?? 'Unknown';
    final finishedAt = job['finished_at'];
    final jobBonus = _parseNum(job['total_bonus']);
    final List<dynamic> details = pesanan['details'] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textMuted.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                          const SizedBox(width: 8),
                          Text(
                            'Selesai pada ${_formatDate(finishedAt)}',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        namaPelanggan,
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Bonus Job',
                        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFE6A300), fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _formatRupiah(jobBonus),
                        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFFE6A300), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Layanan yang Dikerjakan:',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                ...details.map((d) {
                  final layanan = d['layanan'] ?? {};
                  final namaLayanan = layanan['nama_layanan'] ?? 'Unknown';
                  final qty = d['qty'] ?? '';
                  final bonusLayanan = _parseNum(d['bonus_layanan']);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$namaLayanan ($qty)',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                          ),
                        ),
                        if (bonusLayanan > 0)
                          Text(
                            '+ ${_formatRupiah(bonusLayanan)}',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
