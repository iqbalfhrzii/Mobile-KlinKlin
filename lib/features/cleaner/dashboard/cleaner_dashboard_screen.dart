import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/animated_notification_bell.dart';
import '../../../core/services/auth_service.dart';
import '../services/cleaner_job_service.dart';
import 'dart:async';
import '../jobs/cleaner_job_detail_screen.dart';
import '../jobs/cleaner_job_list_screen.dart';
import '../history/cleaner_history_screen.dart';
import '../tukar_libur/screens/tukar_libur_screen.dart';
import '../../attendance/screens/attendance_screen.dart';
import '../../operasional/screens/operasional_pengumuman_screen.dart';
import '../../stok_opname/screens/stok_opname_screen.dart';
import '../../lapor_kecelakaan/screens/lapor_kecelakaan_screen.dart';
import '../sim/screens/cleaner_sim_screen.dart';

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
  String _userStatusPegawai = '';
  bool _isKoor = false;
  
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
    // Auto reload every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
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
    final cachedCustomName = prefs.getString('user_custom_name');
    final defaultName = prefs.getString('user_name') ?? 'Cleaner';

    setState(() {
      _userName = cachedCustomName ?? defaultName;
      _userPhoto = prefs.getString('user_photo');
      _userRole = prefs.getString('user_role') ?? 'Cleaner';
      _userBranch = prefs.getString('user_branch') ?? '-';
      _userStatusPegawai = prefs.getString('user_status_pegawai') ?? prefs.getString('user_status_karyawan') ?? '';
      _isKoor = prefs.getBool('is_koor') ?? 
          (_userRole.toLowerCase().contains('koor') || _userStatusPegawai.toLowerCase().contains('koor'));
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
        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          final cachedCustomName = prefs.getString('user_custom_name');

          final roleName = me['jabatan'] is Map ? me['jabatan']['nama_jabatan'] ?? _userRole : _userRole;
          final branchName = me['cabang'] is Map ? me['cabang']['nama_cabang'] ?? _userBranch : _userBranch;
          final statusPeg = (me['status_karyawan'] ?? me['status_pegawai'] ?? _userStatusPegawai).toString();
          final isKoorBool = (me['is_koor'] == true) || 
              roleName.toString().toLowerCase().contains('koor') || 
              statusPeg.toLowerCase().contains('koor');

          setState(() {
            _userName = cachedCustomName ?? me['nama'] ?? _userName;
            _userPhoto = me['foto_profil'];
            _userRole = roleName;
            _userBranch = branchName;
            _userStatusPegawai = statusPeg;
            _isKoor = isKoorBool;
          });

          prefs.setString('user_status_pegawai', _userStatusPegawai);
          prefs.setBool('is_koor', _isKoor);
        }
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
        final pesanan = job['pesanan'] ?? {};
        final statusPesanan = (pesanan['status_pesanan'] ?? '').toString().toLowerCase();
        final statusUtama = (pesanan['status_order_utama'] ?? '').toString().toLowerCase();
        final isCancelled = statusPesanan == 'cancelled' ||
            statusPesanan == 'waiting_cancel_approval' ||
            statusUtama == 'cancelled' ||
            pesanan['pembatalan'] != null ||
            pesanan['pembatalan_id'] != null ||
            job['status_pengerjaan'] == 'cancelled';
        if (isCancelled) continue;

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

      // Sort recent jobs: in_progress first, then assigned
      recentJobs.sort((a, b) {
        final aProgress = a['status_pengerjaan'] == 'in_progress' ? 0 : 1;
        final bProgress = b['status_pengerjaan'] == 'in_progress' ? 0 : 1;
        return aProgress.compareTo(bProgress);
      });

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
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryMid),
                  )
                : _error.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _error,
                                style: GoogleFonts.inter(color: Colors.red.shade700, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _fetchData(),
                                icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                                label: const Text('Coba Lagi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryMid,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchData,
                        color: AppColors.primaryMid,
                        backgroundColor: Colors.white,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Quick Actions Hub
                              _buildQuickActions(),
                              const SizedBox(height: 16),

                              // 1.5. Featured Coordinator Card (Khusus Cleaner Koor)
                              if (_isKoor) ...[
                                _buildKoorStokOpnameBanner(),
                                const SizedBox(height: 16),
                              ],

                              // 2. Ringkasan Tugas Grid (2x2 KPI)
                              _buildTaskSummary(),
                              const SizedBox(height: 16),

                              // 3. Bonus Bulan Ini Card
                              _buildBonusCard(),
                              const SizedBox(height: 20),

                              // 4. Tugas Aktif & Mendatang
                              _buildRecentJobs(),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ================= HEADER & STATUS BANNER =================

  Widget _buildHeader() {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Selamat Pagi'
        : hour < 15
            ? 'Selamat Siang'
            : hour < 18
                ? 'Selamat Sore'
                : 'Selamat Malam';

    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Logo, Name, Location, Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 22,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$greeting,',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_userName ✨',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (_userBranch != '-' && _userBranch.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_rounded, size: 11, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  _userBranch,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 11, color: Color(0xFFFDE047)),
                              const SizedBox(width: 4),
                              Text(
                                _userRole,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isKoor)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_rounded, size: 11, color: Color(0xFFFDE047)),
                                const SizedBox(width: 4),
                                Text(
                                  _userStatusPegawai.isNotEmpty ? _userStatusPegawai : 'Cleaner Koor',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AnimatedNotificationBell(size: 22),
                  const SizedBox(width: 8),
                  _buildAvatar(),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Shift / Motivation Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _inProgressJobsCount > 0
                        ? Icons.play_circle_fill_rounded
                        : _todayJobsCount > 0
                            ? Icons.assignment_rounded
                            : Icons.tips_and_updates_rounded,
                    color: _inProgressJobsCount > 0 ? const Color(0xFFFDE047) : Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _inProgressJobsCount > 0
                            ? 'Ada tugas sedang dikerjakan'
                            : _todayJobsCount > 0
                                ? 'Ada $_todayJobsCount tugas untukmu hari ini!'
                                : 'Belum ada tugas hari ini.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _inProgressJobsCount > 0
                            ? 'Segera selesaikan dan upload foto bukti ya!'
                            : _todayJobsCount > 0
                                ? 'Cek detail alamat dan mulai pengerjaan tepat waktu.'
                                : 'Tetap standby & jaga kesehatan selalu!',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_todayJobsCount > 0 || _inProgressJobsCount > 0) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CleanerJobListScreen()),
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Lihat',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryMid,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return AppAvatar(
      photoUrl: _userPhoto,
      name: _userName,
      size: 46,
      backgroundColor: Colors.white.withValues(alpha: 0.2),
      textColor: Colors.white,
      borderColor: Colors.white.withValues(alpha: 0.35),
      borderWidth: 1.5,
    );
  }

  // ================= 1. QUICK ACTIONS HUB =================

  Widget _buildQuickActions() {
    final actions = [
      _QuickActionItem(
        title: 'Tugas Saya',
        icon: Icons.work_outline_rounded,
        color: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CleanerJobListScreen()),
        ),
      ),
      if (_isKoor)
        _QuickActionItem(
          title: 'Stok Opname',
          icon: Icons.inventory_2_rounded,
          color: const Color(0xFF0284C7),
          bgColor: const Color(0xFFE0F2FE),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StokOpnameScreen()),
          ),
        ),
      _QuickActionItem(
        title: 'Absensi',
        icon: Icons.fingerprint_rounded,
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFFEF3C7),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
      ),
      _QuickActionItem(
        title: 'Tukar Libur',
        icon: Icons.sync_alt_rounded,
        color: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFF3E8FF),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TukarLiburScreen())),
      ),
      _QuickActionItem(
        title: 'Riwayat',
        icon: Icons.history_rounded,
        color: const Color(0xFF059669),
        bgColor: const Color(0xFFECFDF5),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CleanerHistoryScreen())),
      ),
      _QuickActionItem(
        title: 'Pengumuman',
        icon: Icons.campaign_rounded,
        color: const Color(0xFFE11D48),
        bgColor: const Color(0xFFFFF1F2),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OperasionalPengumumanScreen())),
      ),
      _QuickActionItem(
        title: 'Lapor Insiden',
        icon: Icons.healing_rounded,
        color: const Color(0xFFDC2626),
        bgColor: const Color(0xFFFEF2F2),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LaporKecelakaanScreen())),
      ),
      _QuickActionItem(
        title: 'Data SIM',
        icon: Icons.badge_outlined,
        color: const Color(0xFF0284C7),
        bgColor: const Color(0xFFE0F2FE),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CleanerSimScreen())),
      ),
    ];

    // Koor: 2 rows of 3 columns
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: () {
          // Chunk items into rows of 3
          final rows = <List<_QuickActionItem>>[];
          for (var i = 0; i < actions.length; i += 3) {
            rows.add(actions.sublist(i, (i + 3 > actions.length) ? actions.length : i + 3));
          }

          final widgets = <Widget>[];
          for (int r = 0; r < rows.length; r++) {
            if (r > 0) widgets.add(const SizedBox(height: 12));
            widgets.add(
              Row(
                children: [
                  for (final a in rows[r])
                    Expanded(
                      child: InkWell(
                        onTap: a.onTap,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: a.bgColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(a.icon, size: 22, color: a.color),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                a.title,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF334155),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (rows[r].length < 3)
                    for (int pad = 0; pad < 3 - rows[r].length; pad++)
                      const Expanded(child: SizedBox()),
                ],
              ),
            );
          }
          return widgets;
        }(),
      ),
    );
  }

  // ================= 1.5. KOOR STOK OPNAME BANNER =================

  Widget _buildKoorStokOpnameBanner() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0369A1), Color(0xFF0284C7), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StokOpnameScreen()),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded, size: 13, color: Color(0xFFFDE047)),
                          const SizedBox(width: 4),
                          Text(
                            'FITUR KOORDINATOR',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.inventory_2_rounded, size: 18, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Stok Opname Cabang',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Audit berkala stok alat kerja, mesin, dan barang habis pakai (BHP) cabang $_userBranch.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Mulai Stok Opname',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0369A1),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF0369A1)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= 2. RINGKASAN TUGAS (2x2 KPI) =================

  Widget _buildTaskSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMid.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.dashboard_customize_rounded, size: 14, color: AppColors.primaryMid),
                ),
                const SizedBox(width: 8),
                Text(
                  'Ringkasan Tugas',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CleanerJobListScreen()),
              ),
              child: Text(
                'Lihat Semua →',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryMid,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModernStatCard(
                title: 'Tugas Baru',
                value: '$_activeJobsCount',
                badgeText: 'Perlu Diambil',
                icon: Icons.notifications_active_rounded,
                primaryColor: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFEF3C7),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CleanerJobListScreen(initialStatusFilter: 'assigned'),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildModernStatCard(
                title: 'Hari Ini',
                value: '$_todayJobsCount',
                badgeText: 'Jadwal Hari Ini',
                icon: Icons.calendar_today_rounded,
                primaryColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CleanerJobListScreen(isTodayOnly: true),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildModernStatCard(
                title: 'Dikerjakan',
                value: '$_inProgressJobsCount',
                badgeText: 'Sedang Berjalan',
                icon: Icons.cleaning_services_rounded,
                primaryColor: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFF3E8FF),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CleanerJobListScreen(initialStatusFilter: 'in_progress'),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildModernStatCard(
                title: 'Selesai',
                value: '$_completedJobsCount',
                badgeText: 'Bulan Ini',
                icon: Icons.check_circle_rounded,
                primaryColor: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CleanerJobListScreen(initialStatusFilter: 'finished'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernStatCard({
    required String title,
    required String value,
    required String badgeText,
    required IconData icon,
    required Color primaryColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 17, color: primaryColor),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 3. BONUS BULAN INI CARD =================

  Widget _buildBonusCard() {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CleanerHistoryScreen()),
      ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFF59E0B),
              Color(0xFFD97706),
              Color(0xFFB45309),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD97706).withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -12,
            top: -16,
            child: Icon(
              Icons.stars_rounded,
              size: 110,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 13),
                        const SizedBox(width: 5),
                        Text(
                          'ESTIMASI BONUS BULAN INI',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.white70),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _formatRupiah(_bonusThisMonth),
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Akumulasi bonus dari tugas yang telah selesai di bulan ini.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  // ================= 4. TUGAS AKTIF & MENDATANG =================

  Widget _buildRecentJobs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 8),
                Text(
                  'Tugas Aktif & Mendatang',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_recentJobs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded, size: 28, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tidak ada tugas aktif saat ini',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tugas baru dari CS akan muncul di sini secara otomatis.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ..._recentJobs.map((job) {
            final p = job['pesanan'];
            String custName = 'Pelanggan';
            String serviceName = 'Layanan Kebersihan';
            String address = '-';
            String time = '-';
            String date = '-';

            if (p != null) {
              if (p['pelanggan'] != null) custName = p['pelanggan']['nama_pelanggan'] ?? 'Pelanggan';
              if (p['alamat'] != null) address = p['alamat'];
              if (p['details'] != null && (p['details'] as List).isNotEmpty) {
                serviceName = p['details'][0]['layanan']?['nama_layanan'] ?? 'Layanan Kebersihan';
                time = p['details'][0]['jam_pengerjaan'] ?? p['details'][0]['waktu_pengerjaan'] ?? '-';
                date = p['details'][0]['tanggal_pengerjaan'] ?? '-';
              }
            }
            final status = job['status_pengerjaan'];
            final isProgress = status == 'in_progress';
            final initial = custName.isNotEmpty ? custName[0].toUpperCase() : 'K';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isProgress ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                  width: isProgress ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isProgress
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Top Card Info
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Initial Circle
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isProgress
                                      ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                                      : [AppColors.primaryMid, AppColors.primaryLight],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                initial,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    custName,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    serviceName,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryMid,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: isProgress ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isProgress ? const Color(0xFFFDE047) : const Color(0xFFBFDBFE),
                                ),
                              ),
                              child: Text(
                                isProgress ? 'Sedang Berjalan' : 'Tugas Baru',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isProgress ? const Color(0xFFB45309) : const Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 10),

                        // Address & Time
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                address,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: const Color(0xFF64748B),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 5),
                            Text(
                              time != '-' ? '$time WIB' : 'Jadwal fleksibel',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF334155),
                              ),
                            ),
                            if (date != '-') ...[
                              const SizedBox(width: 8),
                              Text('•', style: TextStyle(color: Colors.grey.shade400)),
                              const SizedBox(width: 8),
                              Text(
                                date,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Bottom Action Button
                  InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CleanerJobDetailScreen(job: job)),
                      );
                      _fetchData();
                    },
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: isProgress ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                        border: const Border(
                          top: BorderSide(color: Color(0xFFF1F5F9)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isProgress ? Icons.play_arrow_rounded : Icons.arrow_forward_rounded,
                            size: 16,
                            color: isProgress ? const Color(0xFFD97706) : AppColors.primaryMid,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isProgress ? 'Lanjutkan Pengerjaan Tugas' : 'Buka Detail & Mulai Tugas',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isProgress ? const Color(0xFFD97706) : AppColors.primaryMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _QuickActionItem {
  final String title;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  _QuickActionItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });
}
