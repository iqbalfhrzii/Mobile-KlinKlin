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
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (now.day >= 28) {
      _startDate = DateTime(now.year, now.month, 28);
      _endDate = DateTime(now.year, now.month + 1, 27);
    } else {
      _startDate = DateTime(now.year, now.month - 1, 28);
      _endDate = DateTime(now.year, now.month, 27);
    }
    _fetchHistory();
  }

  DateTime? _extractJobDate(dynamic job) {
    if (job is! Map) return null;

    // 1. Tanggal pengerjaan (utama, persis seperti sistem web HRD & Owner terkini)
    final detailDate = job['tanggal_pengerjaan'];
    if (detailDate != null) {
      final dt = DateTime.tryParse(detailDate.toString());
      if (dt != null) return dt.toLocal();
    }
    final details = job['pesanan']?['details'] as List?;
    if (details != null && details.isNotEmpty) {
      for (var d in details) {
        if (d is Map && d['tanggal_pengerjaan'] != null) {
          final dt = DateTime.tryParse(d['tanggal_pengerjaan'].toString());
          if (dt != null) return dt.toLocal();
        }
      }
    }

    // 2. Fallback: finished_at (waktu cleaner menyelesaikan pekerjaan)
    if (job['finished_at'] != null) {
      final dt = DateTime.tryParse(job['finished_at'].toString());
      if (dt != null) return dt.toLocal();
    }

    // 3. Fallback: tanggal input pesanan
    final tanggalInput = job['tanggal_input'] ?? job['pesanan']?['tanggal_input'];
    if (tanggalInput != null) {
      final dt = DateTime.tryParse(tanggalInput.toString());
      if (dt != null) return dt.toLocal();
    }

    // 4. Fallback: created_at
    if (job['created_at'] != null) {
      final dt = DateTime.tryParse(job['created_at'].toString());
      if (dt != null) return dt.toLocal();
    }

    return null;
  }

  bool _jobMatchesDateRange(dynamic job, DateTime startDateOnly, DateTime endDateOnly) {
    if (job is! Map) return false;

    // 1. Prioritas Utama: Tanggal pengerjaan (persis seperti sistem web HRD & Owner terkini: DATE(tanggal_pengerjaan))
    final List<DateTime> dates = [];

    final detailDate = job['tanggal_pengerjaan'];
    if (detailDate != null) {
      final dt = DateTime.tryParse(detailDate.toString());
      if (dt != null) dates.add(dt.toLocal());
    }
    final details = job['pesanan']?['details'] as List?;
    if (details != null && details.isNotEmpty) {
      for (var d in details) {
        if (d is Map && d['tanggal_pengerjaan'] != null) {
          final dt = DateTime.tryParse(d['tanggal_pengerjaan'].toString());
          if (dt != null) dates.add(dt.toLocal());
        }
      }
    }

    if (dates.isNotEmpty) {
      return dates.any((d) {
        final dOnly = DateTime(d.year, d.month, d.day);
        return !dOnly.isBefore(startDateOnly) && !dOnly.isAfter(endDateOnly);
      });
    }

    // 2. Fallback jika tidak ada data tanggal pengerjaan sama sekali:
    DateTime? fallbackDate;
    if (job['finished_at'] != null) {
      fallbackDate = DateTime.tryParse(job['finished_at'].toString())?.toLocal();
    }
    fallbackDate ??= DateTime.tryParse((job['tanggal_input'] ?? job['pesanan']?['tanggal_input'] ?? '').toString())?.toLocal();
    fallbackDate ??= DateTime.tryParse((job['created_at'] ?? '').toString())?.toLocal();

    if (fallbackDate != null) {
      final dOnly = DateTime(fallbackDate.year, fallbackDate.month, fallbackDate.day);
      return !dOnly.isBefore(startDateOnly) && !dOnly.isAfter(endDateOnly);
    }

    return false;
  }

  String _formatShortDate(dynamic dateVal) {
    if (dateVal == null) return '-';
    try {
      DateTime dt;
      if (dateVal is DateTime) {
        dt = dateVal.toLocal();
      } else {
        dt = DateTime.parse(dateVal.toString()).toLocal();
      }
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return dateVal.toString();
    }
  }

  num _calculateJobBonus(dynamic job) {
    if (job is! Map) return 0;
    num bonus = 0;
    if (job['bonuses'] is List && (job['bonuses'] as List).isNotEmpty) {
      for (var b in job['bonuses']) {
        bonus += _parseNum(b['nominal']);
      }
    }
    if (bonus > 0) return bonus;
    return _parseNum(job['total_bonus']);
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      List<DateTime> monthsToFetch = [];
      DateTime cur = DateTime(_startDate.year, _startDate.month, 1);
      final endMonth = DateTime(_endDate.year, _endDate.month, 1);
      while (!cur.isAfter(endMonth)) {
        monthsToFetch.add(cur);
        cur = DateTime(cur.year, cur.month + 1, 1);
      }

      num totalBonus = 0;

      final results = await Future.wait(
        monthsToFetch.map((m) => _service.fetchHistory(month: m.month, year: m.year)),
      );

      final Map<String, dynamic> uniqueJobs = {};
      for (final data in results) {
        if (data['pesanans'] is List) {
          for (final job in data['pesanans']) {
            if (job is Map) {
              final pcId = (job['pesanan_cleaner_id'] ?? job['id'])?.toString();
              final pesananId = (job['pesanan_id'] ?? job['pesanan']?['id'])?.toString();
              final key = pcId != null ? 'pc_$pcId' : (pesananId != null ? 'order_$pesananId' : identityHashCode(job).toString());
              uniqueJobs[key] = job;
            }
          }
        }
      }

      final allPesanans = uniqueJobs.values.toList();

      // Filter inklusif per tanggal pengerjaan & selesai (persis seperti di web HRD)
      final startDateOnly = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final endDateOnly = DateTime(_endDate.year, _endDate.month, _endDate.day);

      final filteredPesanans = allPesanans.where((job) {
        return _jobMatchesDateRange(job, startDateOnly, endDateOnly);
      }).toList();
      
      // Hitung total bonus dari seluruh riwayat pekerjaan yang difilter
      for (var job in filteredPesanans) {
        totalBonus += _calculateJobBonus(job);
      }
      
      // Urutkan pekerjaan terbaru di paling atas berdasarkan tanggal pengerjaan/selesai
      filteredPesanans.sort((a, b) {
        final dateA = _extractJobDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = _extractJobDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _historyData = {
            'total_bonus': totalBonus,
            'pesanans': filteredPesanans,
          };
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
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 12 : 16),
            child: Row(
              children: [
                if (Navigator.canPop(context)) ...[
                  HeaderBackButton(onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Riwayat Pekerjaan', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('Daftar pekerjaan selesai dan bonusmu', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.history_rounded, color: Colors.white),
                ),
              ],
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
            Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error.withValues(alpha: 0.5)),
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

    final filteredPesanans = pesanans.where((job) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      final pesanan = job['pesanan'] ?? {};
      final pelanggan = pesanan['pelanggan'] ?? {};
      final namaPelanggan = (pelanggan['nama_pelanggan'] ?? '').toString().toLowerCase();
      final nomorPesanan = (pesanan['nomor_pesanan'] ?? '').toString().toLowerCase();
      final alamat = (pesanan['alamat'] ?? '').toString().toLowerCase();
      final details = pesanan['details'] as List? ?? [];
      final layananMatch = details.any((d) => (d['layanan']?['nama_layanan'] ?? '').toString().toLowerCase().contains(q));

      return namaPelanggan.contains(q) || nomorPesanan.contains(q) || alamat.contains(q) || layananMatch;
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildDateRangePicker(),
          _buildTotalBonusCard(totalBonus),
          const SizedBox(height: 20),
          _buildSearchBar(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daftar Riwayat',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${filteredPesanans.length} Tugas',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (filteredPesanans.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 30, bottom: 30),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.history_rounded,
                        size: 32,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'Tidak ada hasil untuk "$_searchQuery"'
                          : 'Belum ada riwayat pekerjaan selesai.',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...filteredPesanans.map((job) => _buildJobCard(job)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _searchQuery.isNotEmpty ? AppColors.primary : const Color(0xFFE2E8F0),
          width: _searchQuery.isNotEmpty ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _searchQuery.isNotEmpty
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 20,
            color: _searchQuery.isNotEmpty ? AppColors.primary : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
              decoration: InputDecoration(
                hintText: 'Cari pelanggan, layanan, alamat...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.normal,
                  color: const Color(0xFF94A3B8),
                ),
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
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF64748B)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textMuted.withValues(alpha: 0.08),
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
                '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
            onPressed: _showDateRangePicker,
          ),
        ],
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchHistory();
    }
  }

  Widget _buildTotalBonusCard(num totalBonus) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
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
              color: Colors.white.withValues(alpha: 0.8),
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
    final nomorPesanan = pesanan['nomor_pesanan'] ?? pesanan['kode_display'] ?? '';
    final jobDate = _extractJobDate(job);
    final finishedAt = job['finished_at'];
    final finishedAtText = finishedAt != null ? _formatDate(finishedAt.toString()) : null;
    final tanggalInput = job['tanggal_input'] ?? pesanan['tanggal_input'];
    final jobBonus = _calculateJobBonus(job);
    final List<dynamic> details = pesanan['details'] ?? [];

    final statusPengerjaan = (job['status_pengerjaan'] ?? '').toString().toLowerCase();
    final statusPesanan = (pesanan['status_pesanan'] ?? '').toString().toLowerCase();
    final isFinished = statusPengerjaan == 'finished' || statusPesanan == 'completed' || statusPesanan == 'selesai';
    
    final dateDisplay = jobDate != null ? DateFormat('dd/MM/yyyy').format(jobDate) : '-';
    final tglOrderDisplay = tanggalInput != null ? _formatShortDate(tanggalInput) : dateDisplay;
    final statusText = isFinished
        ? (finishedAtText != null ? 'Selesai pada $finishedAtText' : 'Selesai • $dateDisplay')
        : 'Pesanan • $dateDisplay';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textMuted.withValues(alpha: 0.08),
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
                          Expanded(
                            child: Text(
                              statusText,
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        namaPelanggan,
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (nomorPesanan.toString().isNotEmpty)
                            Text(
                              nomorPesanan.toString(),
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                            ),
                          Text(
                            '•  Tgl Kerja: $dateDisplay',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                          Text(
                            '•  Tgl Order: $tglOrderDisplay',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                          ),
                        ],
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
                if (finishedAtText != null) ...[
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 14, color: AppColors.success),
                      const SizedBox(width: 6),
                      Text(
                        'Waktu Selesai: $finishedAtText',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 1, color: AppColors.border),
                  const SizedBox(height: 12),
                ],
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
                if (job['bonuses'] != null && (job['bonuses'] as List).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 1, color: AppColors.border),
                  const SizedBox(height: 12),
                  Text(
                    'Bonus Tambahan:',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  ...(job['bonuses'] as List).map((b) {
                    final tarif = b['tarif_bonus_cabang'] ?? {};
                    final jenis = tarif['jenis_bonus'] ?? {};
                    String namaBonus = b['keterangan'] ?? 'Bonus';
                    String? catatan;
                    
                    if (tarif.isNotEmpty && jenis.isNotEmpty) {
                      namaBonus = jenis['nama_bonus'] ?? namaBonus;
                      if (b['keterangan'] != null && b['keterangan'].toString().trim().isNotEmpty) {
                         String raw = b['keterangan'].toString().trim();
                         if (!raw.startsWith('[BONUS_LAYANAN]') && raw != namaBonus) {
                            catatan = raw;
                         }
                      }
                    }
                    
                    if (b['keterangan'] != null && b['keterangan'].toString().startsWith('[BONUS_LAYANAN]')) {
                      final parts = b['keterangan'].toString().split('|');
                      if (parts.length > 1) {
                        namaBonus = parts[1].trim(); 
                      }
                      if (parts.length > 2 && parts[2].trim().isNotEmpty) {
                        catatan = parts[2].trim();
                      }
                    }

                    final nominal = _parseNum(b['nominal']);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  namaBonus,
                                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                                ),
                                if (catatan != null)
                                  Text(
                                    'Catatan: $catatan',
                                    style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                                  ),
                              ],
                            ),
                          ),
                          if (nominal > 0)
                            Text(
                              '+ ${_formatRupiah(nominal)}',
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
