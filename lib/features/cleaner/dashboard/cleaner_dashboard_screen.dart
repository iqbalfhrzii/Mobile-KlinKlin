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
import '../shell/cleaner_main_shell.dart';

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
                      Text('Ringkasan Tugas', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.1,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildStatCard('Tugas Baru', _activeJobsCount.toString(), Icons.notifications_active_rounded, Colors.orange, onTap: () {
                            CleanerMainShell.navigateToJobs(context, statusFilter: 'assigned');
                          }),
                          _buildStatCard('Hari Ini', _todayJobsCount.toString(), Icons.today_rounded, Colors.blue, onTap: () {
                            CleanerMainShell.navigateToJobs(context, isTodayOnly: true);
                          }),
                          _buildStatCard('Dikerjakan', _inProgressJobsCount.toString(), Icons.cleaning_services, Colors.purple, onTap: () {
                            CleanerMainShell.navigateToJobs(context, statusFilter: 'in_progress');
                          }),
                          _buildStatCard('Selesai', _completedJobsCount.toString(), Icons.check_circle_rounded, Colors.green, onTap: () {
                            CleanerMainShell.navigateToJobs(context, statusFilter: 'finished');
                          }),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildBonusCard(),
                      const SizedBox(height: 32),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$greeting,',
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userName,
                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            _userBranch,
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 2),
                  ],
                ),
                child: _buildAvatar(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.tips_and_updates_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _todayJobsCount > 0 
                            ? 'Ada $_todayJobsCount tugas untukmu hari ini!'
                            : 'Belum ada tugas hari ini.',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tetap semangat dan jaga kesehatan ya!',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
      return ClipOval(
        child: Image.network(
          _userPhoto!, 
          width: 56, 
          height: 56, 
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const SizedBox(width: 56, height: 56, child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)));
          },
          errorBuilder: (_, __, ___) => InitialsAvatar(name: _userName, size: 56, backgroundColor: Colors.white.withOpacity(0.2), textColor: Colors.white, borderColor: Colors.white.withOpacity(0.35))
        )
      );
    }
    
    if (_userPhoto!.startsWith('/')) {
      return ClipOval(child: Image.file(File(_userPhoto!), width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => InitialsAvatar(name: _userName, size: 56, backgroundColor: Colors.white.withOpacity(0.2), textColor: Colors.white, borderColor: Colors.white.withOpacity(0.35))));
    }
    
    return ClipOval(
      child: Image.network(
        'http://159.223.59.109/storage/$_userPhoto', 
        width: 56, 
        height: 56, 
        fit: BoxFit.cover, 
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const SizedBox(width: 56, height: 56, child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)));
        },
        errorBuilder: (_, __, ___) => InitialsAvatar(name: _userName, size: 56, backgroundColor: Colors.white.withOpacity(0.2), textColor: Colors.white, borderColor: Colors.white.withOpacity(0.35))
      )
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -15,
              bottom: -15,
              child: Icon(icon, size: 80, color: color.withOpacity(0.05)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value, style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                      Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
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

  Widget _buildBonusCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFDB931), Color(0xFF9F7928)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(Icons.star_rounded, size: 120, color: Colors.white.withOpacity(0.2)),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bonus Bulan Ini', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.9))),
                    const SizedBox(height: 4),
                    Text(_formatRupiah(_bonusThisMonth), style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
              ),
            ],
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
        Text('Tugas Mendatang', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(height: 16),
        ..._recentJobs.map((job) {
          final p = job['pesanan'];
          String custName = '-';
          String serviceName = 'Tugas Kebersihan';
          String address = '-';
          String time = '-';
          
          if (p != null) {
            if (p['pelanggan'] != null) custName = p['pelanggan']['nama_pelanggan'] ?? '-';
            if (p['alamat'] != null) address = p['alamat'];
            if (p['details'] != null && (p['details'] as List).isNotEmpty) {
              serviceName = p['details'][0]['layanan']?['nama_layanan'] ?? 'Tugas Kebersihan';
              time = p['details'][0]['jam_pengerjaan'] ?? '-';
            }
          }
          final status = job['status_pengerjaan'];
          final isProgress = status == 'in_progress';
          final initial = custName.isNotEmpty ? custName[0].toUpperCase() : '?';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: [AppColors.cardShadow],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Text(initial, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(custName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.cleaning_services_rounded, size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Expanded(child: Text(serviceName, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on_rounded, size: 14, color: Colors.orange),
                                const SizedBox(width: 4),
                                Expanded(child: Text(address, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(time, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                InkWell(
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => CleanerJobDetailScreen(job: job)));
                    _fetchData();
                  },
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isProgress ? Colors.orange.shade50 : AppColors.surfaceBlue,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isProgress ? Icons.play_circle_fill_rounded : Icons.visibility_rounded, size: 18, color: isProgress ? Colors.orange.shade700 : AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          isProgress ? 'Lanjutkan Pengerjaan' : 'Lihat Detail Tugas',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isProgress ? Colors.orange.shade700 : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
