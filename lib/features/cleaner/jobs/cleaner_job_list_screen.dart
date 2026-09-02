import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/weekly_date_picker.dart';
import '../../../core/widgets/whatsapp_icon.dart';
import '../services/cleaner_job_service.dart';
import 'cleaner_job_detail_screen.dart';

class CleanerJobListScreen extends StatefulWidget {
  final String? initialStatusFilter;
  final bool isTodayOnly;

  const CleanerJobListScreen({
    super.key,
    this.initialStatusFilter,
    this.isTodayOnly = false,
  });

  @override
  State<CleanerJobListScreen> createState() => CleanerJobListScreenState();
}

class CleanerJobListScreenState extends State<CleanerJobListScreen> {
  final CleanerJobService _service = CleanerJobService();
  bool _isLoading = true;
  String _error = '';
  List<dynamic> _allJobs = [];
  List<dynamic> _filteredJobs = [];
  
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();
  String _periodFilter = 'semua';
  DateTimeRange? _customRange;
  DateTime? _filterStart;
  DateTime? _filterEnd;
  String _statusFilter = 'Semua';
  Timer? _refreshTimer;

  static const _filters = [
    'Semua',
    'assigned',
    'in_progress',
    'finished',
  ];
  
  static const _filterLabels = {
    'Semua': 'Semua',
    'assigned': 'Tugas Baru',
    'in_progress': 'Sedang Dikerjakan',
    'finished': 'Selesai',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialStatusFilter != null) {
      _statusFilter = widget.initialStatusFilter!;
    }
    _fetchJobs();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchJobs(isSilent: true);
    });
  }

  void applyFilter({String? statusFilter, bool isTodayOnly = false}) {
    setState(() {
      if (statusFilter != null) {
        _statusFilter = statusFilter;
      }
      if (isTodayOnly) {
        _filterStart = DateTime.now();
        _filterEnd = DateTime.now();
      } else {
        _filterStart = null;
        _filterEnd = null;
      }
    });
    _filterJobs();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchJobs({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }
    try {
      final jobs = await _service.fetchJobs();
      if (mounted) {
        setState(() {
          _allJobs = jobs;
        });
        _filterJobs(isSilent: isSilent);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!isSilent) {
            _error = e.toString().replaceAll('Exception: ', '');
            _isLoading = false;
          }
        });
      }
    }
  }

  void _filterJobs({bool isSilent = false}) {
    final filtered = _allJobs.where((job) {
      final q = _query.toLowerCase();
      
      final pesanan = job['pesanan'] ?? {};
      final pelanggan = pesanan['pelanggan'] ?? {};
      final idStr = pesanan['id']?.toString() ?? '';
      final nameStr = pelanggan['nama_pelanggan']?.toString().toLowerCase() ?? '';

      final statusPesanan = (pesanan['status_pesanan'] ?? '').toString().toLowerCase();
      final statusUtama = (pesanan['status_order_utama'] ?? '').toString().toLowerCase();
      final isOrderCancelled = statusPesanan == 'cancelled' ||
          statusPesanan == 'waiting_cancel_approval' ||
          statusUtama == 'cancelled' ||
          pesanan['pembatalan'] != null ||
          pesanan['pembatalan_id'] != null ||
          job['status_pengerjaan'] == 'cancelled';

      // Cleaner tidak boleh melihat / mengerjakan pesanan yang telah dibatalkan
      if (isOrderCancelled) {
        return false;
      }
      
      bool matchQ = idStr.contains(q) || nameStr.contains(q);
      
      // Filter by selected date
      bool matchDate = false;
      if (pesanan['details'] != null) {
        final details = pesanan['details'] as List;
        if (details.isNotEmpty) {
          final tglStr = details[0]['tanggal_pengerjaan'];
          if (tglStr != null) {
            final d = DateTime.tryParse(tglStr.toString());
            if (d != null) {
              matchDate = _filterStart == null || (!d.isBefore(_filterStart!) && !d.isAfter(_filterEnd!));
            }
          }
        }
      }
      
      // Filter by status
      bool matchStatus = _statusFilter == 'Semua';
      if (!matchStatus) {
        final status = job['status_pengerjaan'];
        if (_statusFilter == 'assigned') {
          matchStatus = status == 'assigned' || status == 'notified';
        } else {
          matchStatus = status == _statusFilter;
        }
      }
      
      return matchQ && matchDate && matchStatus;
    }).toList();

    // Sort by status: notified/assigned -> in_progress -> finished
    int statusWeight(String? s) {
      if (s == 'in_progress') return 0;
      if (s == 'notified' || s == 'assigned') return 1;
      return 2;
    }
    
    filtered.sort((a, b) {
      return statusWeight(a['status_pengerjaan']).compareTo(statusWeight(b['status_pengerjaan']));
    });

    if (mounted) {
      setState(() {
        _filteredJobs = filtered;
        if (!isSilent) _isLoading = false;
      });
    }
  }

  String _formatDateWithDay(String? dateStr) {
    if (dateStr == null || dateStr == '-') return '-';
    try {
      final dt = DateTime.parse(dateStr);
      final weekdayNames = {
        1: 'Senin',
        2: 'Selasa',
        3: 'Rabu',
        4: 'Kamis',
        5: 'Jumat',
        6: 'Sabtu',
        7: 'Minggu',
      };
      final months = {
        1: 'Januari',
        2: 'Februari',
        3: 'Maret',
        4: 'April',
        5: 'Mei',
        6: 'Juni',
        7: 'Juli',
        8: 'Agustus',
        9: 'September',
        10: 'Oktober',
        11: 'November',
        12: 'Desember',
      };
      final dayName = weekdayNames[dt.weekday] ?? '';
      final monthName = months[dt.month] ?? '';
      return '$dayName, ${dt.day} $monthName ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String? _getRelativeDay(String? dateStr) {
    if (dateStr == null || dateStr == '-') return null;
    try {
      final parsedDate = DateTime.parse(dateStr);
      final today = DateTime.now();
      
      final dateOnly = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
      final todayOnly = DateTime(today.year, today.month, today.day);
      
      final difference = dateOnly.difference(todayOnly).inDays;
      
      if (difference == 0) {
        return 'Hari Ini';
      } else if (difference == 1) {
        return 'Besok';
      } else if (difference == -1) {
        return 'Kemarin';
      } else if (difference > 1 && difference <= 7) {
        return '$difference hari lagi';
      } else if (difference < -1 && difference >= -7) {
        return '${difference.abs()} hari lalu';
      }
      return null;
    } catch (_) {
      return null;
    }
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
              onRefresh: _fetchJobs,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 12, bottom: 16),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: WeeklyDatePicker(
                        initialDate: widget.isTodayOnly ? DateTime.now() : null,
                        showAllMonthButton: false,
                        onFilterChanged: (start, end) {
                          setState(() {
                            _filterStart = start;
                            _filterEnd = end;
                            _periodFilter = 'custom';
                          });
                          _filterJobs();
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildProMaxSearchAndFilterBar(),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      _buildShimmerLoading()
                    else if (_error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: _buildError(),
                      )
                    else if (_filteredJobs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: _buildEmpty(),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredJobs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _buildJobCard(_filteredJobs[index]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateDateFilters() {
    final now = DateTime.now();
    if (_periodFilter == 'semua') {
      _filterStart = null;
      _filterEnd = null;
    } else if (_periodFilter == 'hari_ini') {
      _filterStart = DateTime(now.year, now.month, now.day);
      _filterEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_periodFilter == 'kemarin') {
      final yest = now.subtract(const Duration(days: 1));
      _filterStart = DateTime(yest.year, yest.month, yest.day);
      _filterEnd = DateTime(yest.year, yest.month, yest.day, 23, 59, 59);
    } else if (_periodFilter == 'besok') {
      final tom = now.add(const Duration(days: 1));
      _filterStart = DateTime(tom.year, tom.month, tom.day);
      _filterEnd = DateTime(tom.year, tom.month, tom.day, 23, 59, 59);
    } else if (_periodFilter == 'bulan_ini') {
      _filterStart = DateTime(now.year, now.month, 1);
      _filterEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_periodFilter == 'custom' && _customRange != null) {
      _filterStart = DateTime(_customRange!.start.year, _customRange!.start.month, _customRange!.start.day);
      _filterEnd = DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day, 23, 59, 59);
    }
    _filterJobs();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _customRange ?? DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _periodFilter = 'custom';
        _customRange = picked;
        _updateDateFilters();
      });
      _showFilterBottomSheet();
    }
  }

  Widget _buildProMaxSearchAndFilterBar() {
    final int activeFilterCount = (_periodFilter != 'semua' ? 1 : 0) +
        (_statusFilter != 'Semua' ? 1 : 0);

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
                  color: _query.isNotEmpty ? const Color(0xFF3B82F6) : Colors.grey.withValues(alpha: 0.25),
                  width: _query.isNotEmpty ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _query.isNotEmpty ? const Color(0xFF3B82F6).withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.03),
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
                    color: _query.isNotEmpty ? const Color(0xFF2563EB) : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) {
                        setState(() => _query = val);
                        _filterJobs();
                      },
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: 'Cari tugas atau pelanggan...',
                        hintStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.textMuted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                        _filterJobs();
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
            onTap: () => _showFilterBottomSheet(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: activeFilterCount > 0
                    ? const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF4F46E5)])
                    : null,
                color: activeFilterCount > 0 ? null : Colors.white,
                borderRadius: BorderRadius.circular(23),
                border: Border.all(
                  color: activeFilterCount > 0 ? Colors.transparent : Colors.grey.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  if (activeFilterCount > 0)
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  else
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: activeFilterCount > 0 ? Colors.white : AppColors.textDark,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Filter',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: activeFilterCount > 0 ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  if (activeFilterCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$activeFilterCount',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Filter Tugas', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
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

                  // 1. Rentang Waktu
                  Text('Rentang Waktu', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
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
                                _updateDateFilters();
                              });
                              setState(() {
                                _periodFilter = item['key']!;
                                _customRange = null;
                                _updateDateFilters();
                              });
                            }
                          },
                          selectedColor: const Color(0xFFECFDF5),
                          labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? const Color(0xFF047857) : AppColors.textDark),
                          side: BorderSide(color: isSel ? const Color(0xFF10B981) : Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          showCheckmark: false,
                        );
                      }),
                      ActionChip(
                        avatar: const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF4F46E5)),
                        label: Text(
                          _periodFilter == 'custom' && _customRange != null
                              ? '${_customRange!.start.day}/${_customRange!.start.month} - ${_customRange!.end.day}/${_customRange!.end.month}'
                              : 'Pilih Tanggal',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: _periodFilter == 'custom' ? FontWeight.bold : FontWeight.w500, color: _periodFilter == 'custom' ? const Color(0xFF4F46E5) : AppColors.textDark),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _pickCustomRange();
                        },
                        backgroundColor: _periodFilter == 'custom' ? const Color(0xFFEEF2FF) : Colors.white,
                        side: BorderSide(color: _periodFilter == 'custom' ? const Color(0xFF6366F1) : Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. Status Tugas
                  Text('Status Tugas', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
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
                            _filterJobs();
                          }
                        },
                        selectedColor: const Color(0xFFFFFBEB),
                        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? const Color(0xFFD97706) : AppColors.textDark),
                        side: BorderSide(color: isSel ? const Color(0xFFF59E0B) : Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              _periodFilter = 'semua';
                              _customRange = null;
                              _statusFilter = 'Semua';
                              _updateDateFilters();
                            });
                            setState(() {
                              _periodFilter = 'semua';
                              _customRange = null;
                              _statusFilter = 'Semua';
                              _updateDateFilters();
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Reset', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Terapkan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (Navigator.canPop(context)) ...[
                HeaderBackButton(onTap: () => Navigator.pop(context)),
                const SizedBox(width: 12),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daftar Tugas', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Kelola tugas Anda', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
                ],
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _fetchJobs,
              tooltip: 'Refresh Data',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 48),
          const SizedBox(height: 16),
          Text(_error, style: GoogleFonts.inter(color: AppColors.error)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _fetchJobs, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available_rounded, color: AppColors.textMuted.withValues(alpha: 0.3), size: 80),
          const SizedBox(height: 16),
          Text('Tidak ada tugas untuk tanggal ini', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  String _formatRupiah(int n) =>
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(n);

  Future<void> _launchWA(String noWa) async {
    String phone = noWa.replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('0')) {
      phone = '62${phone.substring(1)}';
    }
    final url = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }



  Future<void> _openMap(String address) async {
    final query = Uri.encodeComponent(address);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final status = job['status_pengerjaan'];
    final pesanan = job['pesanan'] ?? {};
    final pelanggan = pesanan['pelanggan'] ?? {};
    final details = pesanan['details'] as List? ?? [];
    
    String customerName = pelanggan['nama_pelanggan'] ?? '-';
    String customerPhone = pelanggan['no_telp'] ?? pelanggan['no_hp'] ?? pelanggan['no_wa'] ?? '';
    String customerAddress = pelanggan['alamat_pelanggan'] ?? pelanggan['alamat'] ?? '-';
    
    String jam = '-';
    String tanggal = '-';
    String? rawTanggal;
    if (details.isNotEmpty) {
      jam = details[0]['waktu_pengerjaan'] ?? '-';
      rawTanggal = details[0]['tanggal_pengerjaan'];
      tanggal = _formatDateWithDay(rawTanggal);
    }

    if (jam.length > 5 && jam.contains(':')) {
      final parts = jam.split(':');
      if (parts.length >= 2) {
        jam = '${parts[0]}:${parts[1]}';
      }
    }

    final relativeDay = _getRelativeDay(rawTanggal);
    final num totalBonus = job['total_bonus'] is num
        ? job['total_bonus']
        : (num.tryParse(job['total_bonus']?.toString() ?? '0') ?? 0);
    final bool canShowWa = job['show_wa'] == true ||
        job['show_wa'] == 1 ||
        job['show_wa'] == '1' ||
        pesanan['show_wa'] == true ||
        pesanan['show_wa'] == 1 ||
        pesanan['show_wa'] == '1';

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CleanerJobDetailScreen(job: job)),
        );
        if (result == true) {
          _fetchJobs();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar with Order Code & Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.cleaning_services_rounded, size: 15, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tugas Pengerjaan',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (relativeDay != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: (relativeDay == 'Hari Ini' || relativeDay == 'Besok')
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF64748B),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            relativeDay,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                      _buildStatusBadge(status),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Header Row
                  Row(
                    children: [
                      InitialsAvatar(
                        name: customerName,
                        size: 46,
                        backgroundColor: const Color(0xFFEFF6FF),
                        textColor: const Color(0xFF2563EB),
                        borderColor: const Color(0xFFBFDBFE),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customerName,
                              style: GoogleFonts.inter(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (canShowWa && customerPhone.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const WhatsAppIcon(size: 13, color: Color(0xFF25D366)),
                                  const SizedBox(width: 5),
                                  Text(
                                    customerPhone,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (canShowWa && customerPhone.isNotEmpty) ...[
                        GestureDetector(
                          onTap: () => _launchWA(customerPhone),
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const WhatsAppIcon(size: 18, color: Color(0xFF25D366)),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Service Tags Preview
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: details.map((d) {
                        final l = d['layanan'] ?? {};
                        final nama = l['nama_layanan'] ?? 'Layanan';
                        final qty = d['qty'] ?? '1';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cleaning_services_rounded, size: 12, color: Color(0xFF3B82F6)),
                              const SizedBox(width: 5),
                              Text(
                                '$nama ($qty)',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Schedule & Location Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB), size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$tanggal · $jam WIB',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.location_on_rounded, color: Color(0xFFDC2626), size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                customerAddress,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF334155),
                                  height: 1.4,
                                ),
                              ),
                            ),
                            if (customerAddress.isNotEmpty && customerAddress != '-') ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _openMap(customerAddress),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.map_rounded, size: 12, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Maps',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF2563EB),
                                        ),
                                      ),
                                    ],
                                  ),
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

            // Card Footer Action
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (totalBonus > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded, size: 14, color: Color(0xFFD97706)),
                          const SizedBox(width: 4),
                          Text(
                            '+ ${_formatRupiah(totalBonus.toInt())}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status == 'assigned' || status == 'notified'
                            ? 'Mulai Pengerjaan'
                            : (status == 'in_progress' ? 'Lanjutkan Tugas' : 'Lihat Detail'),
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: const Color(0xFF2563EB),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, color: Color(0xFF2563EB), size: 15),
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

  Widget _buildStatusBadge(String? status) {
    Color bg = AppColors.border;
    Color fg = AppColors.textMuted;
    String text = 'Tidak Diketahui';

    switch (status) {
      case 'assigned':
      case 'notified':
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFD97706);
        text = 'Tugas Baru';
        break;
      case 'in_progress':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        text = 'Dikerjakan';
        break;
      case 'finished':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        text = 'Selesai';
        break;
      case 'cancelled':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFDC2626);
        text = 'Dibatalkan';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return Container(
            height: 190,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: Shimmer.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(width: 80, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                        Container(width: 60, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(width: 50, height: 50, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(width: 140, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                            const SizedBox(height: 8),
                            Container(width: 100, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(width: 150, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
