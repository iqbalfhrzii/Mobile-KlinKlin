import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/weekly_date_picker.dart';
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
  State<CleanerJobListScreen> createState() => _CleanerJobListScreenState();
}

class _CleanerJobListScreenState extends State<CleanerJobListScreen> {
  final CleanerJobService _service = CleanerJobService();
  bool _isLoading = true;
  String _error = '';
  List<dynamic> _allJobs = [];
  List<dynamic> _filteredJobs = [];
  
  String _query = '';
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
                        searchQuery: _query,
                        initialDate: widget.isTodayOnly ? DateTime.now() : null,
                        onSearchChanged: (val) {
                          setState(() => _query = val);
                          _filterJobs();
                        },
                        onFilterChanged: (start, end) {
                          setState(() {
                            _filterStart = start;
                            _filterEnd = end;
                          });
                          _filterJobs();
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFilterRow(),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
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

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _filters.map((f) {
          final active = _statusFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                _filterLabels[f]!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                  color: active ? Colors.white : AppColors.textMuted,
                ),
              ),
              selected: active,
              onSelected: (val) {
                if (val) {
                  setState(() => _statusFilter = f);
                  _filterJobs();
                }
              },
              backgroundColor: Colors.white,
              selectedColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: active ? AppColors.primary : AppColors.border,
                ),
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return GradientHeader(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daftar Tugas', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Kelola tugas Anda', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.8))),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
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
          ],
        ),
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
          Icon(Icons.event_available_rounded, color: AppColors.textMuted.withOpacity(0.3), size: 80),
          const SizedBox(height: 16),
          Text('Tidak ada tugas untuk tanggal ini', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final status = job['status_pengerjaan'];
    final pesanan = job['pesanan'] ?? {};
    final pelanggan = pesanan['pelanggan'] ?? {};
    final details = pesanan['details'] as List? ?? [];
    
    String customerName = pelanggan['nama_pelanggan'] ?? '-';
    String customerAddress = pelanggan['alamat'] ?? '-';
    
    String jam = '-';
    String tanggal = '-';
    String? rawTanggal;
    if (details.isNotEmpty) {
      jam = details[0]['waktu_pengerjaan'] ?? '-';
      rawTanggal = details[0]['tanggal_pengerjaan'];
      tanggal = _formatDateWithDay(rawTanggal);
    }

    // Format jam pengerjaan (remove seconds if present)
    if (jam.length > 5 && jam.contains(':')) {
      final parts = jam.split(':');
      if (parts.length >= 2) {
        jam = '${parts[0]}:${parts[1]}';
      }
    }

    final relativeDay = _getRelativeDay(rawTanggal);

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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [AppColors.cardShadow],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row (ID and Status)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text('#${pesanan['id'] ?? '-'}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (relativeDay != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: (relativeDay == 'Hari Ini' || relativeDay == 'Besok') 
                              ? AppColors.primary.withOpacity(0.08) 
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (relativeDay == 'Hari Ini' || relativeDay == 'Besok') 
                                ? AppColors.primary.withOpacity(0.15) 
                                : Colors.grey.shade200
                          ),
                        ),
                        child: Text(
                          relativeDay,
                          style: GoogleFonts.inter(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold, 
                            color: (relativeDay == 'Hari Ini' || relativeDay == 'Besok') 
                                ? AppColors.primary 
                                : AppColors.textMuted
                          ),
                        ),
                      ),
                    ],
                    _buildStatusBadge(status),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Customer Row (Top and Prominent)
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: const Icon(Icons.person_rounded, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    customerName,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            
            // Highlighted Schedule (Waktu & Tanggal)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceBlue, // A soft blue background for schedule
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jadwal Pengerjaan',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary.withOpacity(0.8), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$tanggal · $jam WIB',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            
            // Address Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on_rounded, color: AppColors.error, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alamat Pengerjaan',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customerAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            
            // Card Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Text('Lihat Detail', style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 16),
                  ],
                ),
              ],
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
        bg = AppColors.statusPending.withOpacity(0.1);
        fg = AppColors.statusPending;
        text = 'Tugas Baru';
        break;
      case 'in_progress':
        bg = AppColors.statusProgress.withOpacity(0.1);
        fg = AppColors.statusProgress;
        text = 'Dikerjakan';
        break;
      case 'finished':
        bg = AppColors.statusDone.withOpacity(0.1);
        fg = AppColors.statusDone;
        text = 'Selesai';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}
