import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/services/auth_service.dart';
import '../services/cleaner_job_service.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../jobs/cleaner_job_detail_screen.dart';
import '../jobs/cleaner_job_list_screen.dart';

class CleanerDashboardScreen extends StatefulWidget {
  const CleanerDashboardScreen({super.key});

  @override
  State<CleanerDashboardScreen> createState() => _CleanerDashboardScreenState();
}

class _CleanerDashboardScreenState extends State<CleanerDashboardScreen> {
  final CleanerJobService _service = CleanerJobService();
  String _userName = 'Cleaner';
  String? _userPhoto;
  String _userRole = 'Cleaner';
  String _userBranch = '-';
  
  bool _isLoading = true;
  String _error = '';
  
  int _todayJobsCount = 0;
  int _activeJobsCount = 0;
  int _inProgressJobsCount = 0;
  int _completedJobsCount = 0;
  int _bonusThisMonth = 0;
  List<dynamic> _recentJobs = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _fetchData();
    // Auto reload every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchData(isSilent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Cleaner';
      _userPhoto = prefs.getString('user_photo');
      _userRole = prefs.getString('user_role') ?? 'Cleaner';
      _userBranch = prefs.getString('user_branch') ?? '-';
    });
  }

  Future<void> _fetchData({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }
    try {
      // Ambil data profil terbaru dari API
      try {
        final meResponse = await AuthService.getMe();
        final me = meResponse['data'] ?? meResponse;
        setState(() {
          _userName = me['nama'] ?? _userName;
          _userPhoto = me['foto_profil'];
          _userRole = me['jabatan'] is Map ? me['jabatan']['nama_jabatan'] ?? _userRole : _userRole;
          _userBranch = me['cabang'] is Map ? me['cabang']['nama_cabang'] ?? _userBranch : _userBranch;
        });
      } catch (_) {
        // Abaikan jika gagal ambil profil
      }

      final jobs = await _service.fetchJobs();
      final now = DateTime.now();
      
      int todayCount = 0;
      int activeCount = 0;
      int inProgressCount = 0;
      int completedCount = 0;
      int bonusMonth = 0;
      List<dynamic> recentJobs = [];

      for (var job in jobs) {
        // Cek aktif
        final status = job['status_pengerjaan'];
        if (status == 'assigned' || status == 'notified') {
          activeCount++;
          recentJobs.add(job);
        } else if (status == 'in_progress') {
          inProgressCount++;
          recentJobs.add(job);
        } else if (status == 'finished') {
          completedCount++;
        }
        
        // Cek tanggal pengerjaan di pesanan.details
        if (job['pesanan'] != null && job['pesanan']['details'] != null) {
          final details = job['pesanan']['details'] as List;
          if (details.isNotEmpty) {
            final tgl = details[0]['tanggal_pengerjaan'];
            if (tgl != null) {
              final jobDate = DateTime.tryParse(tgl.toString());
              if (jobDate != null) {
                if (jobDate.year == now.year && jobDate.month == now.month && jobDate.day == now.day) {
                  todayCount++;
                }
                
                // Jika job selesai dan di bulan ini, tambahkan bonus
                if (status == 'finished' && jobDate.year == now.year && jobDate.month == now.month) {
                  bonusMonth += int.tryParse(job['total_bonus']?.toString() ?? '0') ?? 0;
                }
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _todayJobsCount = todayCount;
          _activeJobsCount = activeCount;
          _inProgressJobsCount = inProgressCount;
          _completedJobsCount = completedCount;
          _bonusThisMonth = bonusMonth;
          _recentJobs = recentJobs.take(3).toList();
          if (!isSilent) _isLoading = false;
        });
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

  String _formatRupiah(int n) =>
      'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 40),
                        const SizedBox(height: 12),
                        Text(_error, style: GoogleFonts.inter(color: AppColors.error), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _fetchData, child: const Text('Coba Lagi')),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ringkasan Anda', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.8,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildStatCard('Tugas Baru', _activeJobsCount.toString(), Icons.work_outline, AppColors.primary, onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const CleanerJobListScreen(initialStatusFilter: 'assigned')));
                          }),
                          _buildStatCard('Hari Ini', _todayJobsCount.toString(), Icons.today_rounded, AppColors.statusPending, onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const CleanerJobListScreen(isTodayOnly: true)));
                          }),
                          _buildStatCard('Dikerjakan', _inProgressJobsCount.toString(), Icons.cleaning_services, AppColors.statusProgress, onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const CleanerJobListScreen(initialStatusFilter: 'in_progress')));
                          }),
                          _buildStatCard('Selesai', _completedJobsCount.toString(), Icons.check_circle_rounded, AppColors.statusDone, onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const CleanerJobListScreen(initialStatusFilter: 'finished')));
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildBonusCard(),
                      const SizedBox(height: 24),
                      _buildRecentJobs(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12 ? 'Selamat Pagi' : hour < 15 ? 'Selamat Siang' : hour < 18 ? 'Selamat Sore' : 'Selamat Malam';

    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(greeting + ',', style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
                    )),
                    Text('$_userName ✨', style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
                    )),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _userRole,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (_userBranch != '-')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _userBranch,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildAvatar(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (_userPhoto == null || _userPhoto!.isEmpty) {
      return InitialsAvatar(name: _userName, size: 56, backgroundColor: Colors.white.withOpacity(0.2), textColor: Colors.white, borderColor: Colors.white.withOpacity(0.35));
    }
    
    if (_userPhoto!.startsWith('data:image')) {
      try {
        final base64Str = _userPhoto!.split(',').last;
        return ClipOval(child: Image.memory(base64Decode(base64Str), width: 56, height: 56, fit: BoxFit.cover));
      } catch (_) {
        return InitialsAvatar(name: _userName, size: 56, backgroundColor: Colors.white.withOpacity(0.2), textColor: Colors.white, borderColor: Colors.white.withOpacity(0.35));
      }
    }
    
    if (_userPhoto!.startsWith('http')) {
      return ClipOval(child: Image.network(_userPhoto!, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => InitialsAvatar(name: _userName, size: 56, backgroundColor: Colors.white.withOpacity(0.2), textColor: Colors.white, borderColor: Colors.white.withOpacity(0.35))));
    }
    
    if (_userPhoto!.startsWith('/')) {
      return ClipOval(child: Image.file(File(_userPhoto!), width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => InitialsAvatar(name: _userName, size: 56, backgroundColor: Colors.white.withOpacity(0.2), textColor: Colors.white, borderColor: Colors.white.withOpacity(0.35))));
    }
    
    return ClipOval(child: Image.network('http://192.168.1.242:8000/storage/$_userPhoto', width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => InitialsAvatar(name: _userName, size: 56, backgroundColor: Colors.white.withOpacity(0.2), textColor: Colors.white, borderColor: Colors.white.withOpacity(0.35))));
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [AppColors.cardShadow],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: GoogleFonts.inter(
                  fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark,
                )),
                Text(title, style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textMuted,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBonusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3CD), Color(0xFFFFE69C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFC107).withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.stars_rounded, color: Color(0xFFE6A300), size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bonus Bulan Ini', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF996D00))),
                const SizedBox(height: 4),
                Text(_formatRupiah(_bonusThisMonth), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFFB38000))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentJobs() {
    if (_recentJobs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tugas Mendatang', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          ],
        ),
        const SizedBox(height: 12),
        ..._recentJobs.map((job) {
          final p = job['pesanan'];
          String custName = '-';
          String serviceName = 'Tugas Kebersihan';
          if (p != null) {
            if (p['pelanggan'] != null) custName = p['pelanggan']['nama_pelanggan'] ?? '-';
            if (p['details'] != null && (p['details'] as List).isNotEmpty) {
              serviceName = p['details'][0]['layanan']?['nama_layanan'] ?? 'Tugas Kebersihan';
            }
          }
          final status = job['status_pengerjaan'];
          final isProgress = status == 'in_progress';
          
          return InkWell(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => CleanerJobDetailScreen(job: job)));
              _fetchData();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: [AppColors.cardShadow],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: isProgress ? AppColors.statusProgressBg : AppColors.surfaceBlue, borderRadius: BorderRadius.circular(10)),
                    child: Icon(isProgress ? Icons.cleaning_services : Icons.assignment_rounded, color: isProgress ? AppColors.statusProgress : AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(custName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        Text(serviceName, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}
