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
    if (details.isNotEmpty) {
      jam = details[0]['waktu_pengerjaan'] ?? '-';
      tanggal = details[0]['tanggal_pengerjaan'] ?? '-';
    }

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('#${pesanan['id'] ?? '-'}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customerName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text('$tanggal · $jam', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(customerAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textDark)),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
              ],
            )
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
