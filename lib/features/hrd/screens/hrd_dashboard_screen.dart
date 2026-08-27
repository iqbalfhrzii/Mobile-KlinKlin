import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/animated_notification_bell.dart';
import '../../attendance/screens/admin_attendance_list_screen.dart';
import '../../attendance/services/attendance_service.dart';
import '../../operasional/screens/operasional_pengumuman_screen.dart';
import '../../operasional/screens/operasional_permintaan_design_screen.dart';
import '../services/hrd_service.dart';
import 'karyawan/karyawan_list_screen.dart';
import 'gaji_karyawan/gaji_karyawan_list_screen.dart';
import 'insentif/insentif_cleaner_list_screen.dart';
import 'jadwal_libur/hrd_jadwal_libur_screen.dart';
import 'tukar_libur/hrd_tukar_libur_screen.dart';
import 'cuti/hrd_cuti_screen.dart';
import 'cabang/cabang_list_screen.dart';
import 'hrd_data_master_screen.dart';

class HrdDashboardScreen extends StatefulWidget {
  const HrdDashboardScreen({super.key});

  @override
  State<HrdDashboardScreen> createState() => _HrdDashboardScreenState();
}

class _HrdDashboardScreenState extends State<HrdDashboardScreen> {
  final HrdService _hrdService = HrdService();
  final AttendanceService _attendanceService = AttendanceService();

  bool _isLoading = true;
  int _totalKaryawan = 0;
  int _totalCabang = 0;
  int _totalJabatan = 0;
  int _totalLayanan = 0;

  // Today's live attendance metrics
  int _todayMasuk = 0;
  int _todayTelat = 0;
  int _todayTidakAbsen = 0;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('user_name') ?? 'HRD Admin';

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      final results = await Future.wait([
        _hrdService.fetchKaryawan(),
        _hrdService.fetchCabang(),
        _hrdService.fetchJabatan(),
        _hrdService.fetchLayanan(),
        _attendanceService.getAllAbsensi(date: todayStr),
      ]);

      final cleaners = (results[0] as List).where((k) {
        final role = k.jabatan?.namaJabatan.toLowerCase() ?? '';
        return role.contains('cleaner');
      }).toList();

      final todayItems = results[4] as List;

      int masuk = 0;
      int telat = 0;
      final Set<int> presentCleanerIds = {};

      for (var item in todayItems) {
        if (item.type == 'check_in' || item.type == 'masuk') {
          masuk++;
          if (item.karyawanId != null) presentCleanerIds.add(item.karyawanId!);

          // Check late (> 08:15)
          final timeStr = item.time ?? '';
          if (timeStr.contains(' ')) {
            final parts = timeStr.split(' ').last.split(':');
            if (parts.length >= 2) {
              final h = int.tryParse(parts[0]) ?? 0;
              final m = int.tryParse(parts[1]) ?? 0;
              if (h > 8 || (h == 8 && m > 15)) telat++;
            }
          }
        }
      }

      final totalCleanersCount = cleaners.isNotEmpty ? cleaners.length : (results[0] as List).length;
      final tidakAbsen = totalCleanersCount - presentCleanerIds.length;

      if (mounted) {
        setState(() {
          _totalKaryawan = (results[0] as List).length;
          _totalCabang = (results[1] as List).length;
          _totalJabatan = (results[2] as List).length;
          _totalLayanan = (results[3] as List).length;
          _todayMasuk = masuk;
          _todayTelat = telat;
          _todayTidakAbsen = tidakAbsen < 0 ? 0 : tidakAbsen;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  String _getFormattedDate() {
    final dt = DateTime.now();
    final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // --- 1. Fast Buttons / Menu Pintas (Icon Grid 4 per Baris) ---
                  _buildFastButtonsSection(context),
                  const SizedBox(height: 16),

                  // --- 2. Live Kehadiran Hari Ini Card ---
                  _buildLiveAttendanceSummary(context),
                  const SizedBox(height: 16),

                  // --- 3. Ringkasan SDM & Perusahaan (4 Mini Cards) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ringkasan SDM & Perusahaan',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          'Real-time',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_isLoading) _buildShimmerGrid() else _buildStatsGrid(),
                  const SizedBox(height: 16),

                  // --- 4. Informasi & Pengumuman Operasional ---
                  _buildInformasiSection(context),
                  const SizedBox(height: 14),

                  // --- 5. Info Jadwal & Tips HRD ---
                  _buildTipsCard(),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 1. HEADER =================
  Widget _buildHeader(BuildContext context) {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
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
                    Image.asset('assets/images/logo.png', height: 22),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getFormattedDate(),
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_getGreeting()},',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    Text(
                      '$_userName ✨',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Panel Kontrol HRD & Kepegawaian',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AnimatedNotificationBell(size: 24),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= 2. FAST BUTTONS (4 per baris) =================
  Widget _buildFastButtonsSection(BuildContext context) {
    final items = [
      _FastButtonItem(
        title: 'Karyawan',
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KaryawanListScreen())),
      ),
      _FastButtonItem(
        title: 'Gaji',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF059669),
        bgColor: const Color(0xFFECFDF5),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GajiKaryawanListScreen())),
      ),
      _FastButtonItem(
        title: 'Insentif',
        icon: Icons.payments_rounded,
        color: const Color(0xFF0D9488),
        bgColor: const Color(0xFFCCFBF1),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InsentifCleanerListScreen())),
      ),
      _FastButtonItem(
        title: 'Jadwal Libur',
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF4F46E5),
        bgColor: const Color(0xFFEEF2FF),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrdJadwalLiburScreen())),
      ),
      _FastButtonItem(
        title: 'Tukar Libur',
        icon: Icons.swap_horiz_rounded,
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFFEF3C7),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrdTukarLiburScreen())),
      ),
      _FastButtonItem(
        title: 'Cuti & Izin',
        icon: Icons.beach_access_rounded,
        color: const Color(0xFFE11D48),
        bgColor: const Color(0xFFFFE4E6),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrdCutiScreen())),
      ),
      _FastButtonItem(
        title: 'Desain',
        icon: Icons.brush_rounded,
        color: const Color(0xFFEA580C),
        bgColor: const Color(0xFFFFEDD5),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OperasionalPermintaanDesignScreen(department: 'hrd'))),
      ),
      _FastButtonItem(
        title: 'Cabang',
        icon: Icons.storefront_rounded,
        color: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFF3E8FF),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CabangListScreen())),
      ),
    ];

    // Chunk items into rows of 4
    final List<List<_FastButtonItem>> rows = [];
    for (var i = 0; i < items.length; i += 4) {
      rows.add(items.sublist(i, (i + 4 > items.length) ? items.length : i + 4));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: rows.map((rowItems) {
          final isLast = rowItems == rows.last;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Row(
              children: [
                ...rowItems.map((item) => Expanded(child: _buildSingleFastButton(item))),
                ...List.generate(4 - rowItems.length, (_) => const Expanded(child: SizedBox())),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSingleFastButton(_FastButtonItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: item.bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, size: 22, color: item.color),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ================= 3. LIVE ATTENDANCE SUMMARY =================
  Widget _buildLiveAttendanceSummary(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: Color(0xFF2563EB),
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Kehadiran Karyawan Hari Ini',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminAttendanceListScreen(),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Lihat Log',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: Color(0xFF2563EB),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Stat Pills
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: _buildLiveStatItem(
                    label: 'Absen Masuk',
                    value: '$_todayMasuk',
                    color: const Color(0xFF15803D),
                    bgColor: const Color(0xFFECFDF5),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildLiveStatItem(
                    label: 'Terlambat',
                    value: '$_todayTelat',
                    color: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFFFBEB),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildLiveStatItem(
                    label: 'Belum Absen',
                    value: '$_todayTidakAbsen',
                    color: const Color(0xFFDC2626),
                    bgColor: const Color(0xFFFEF2F2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatItem({
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ================= 4. STATS MINI CARDS =================
  Widget _buildStatsGrid() {
    return GridView.count(
      padding: EdgeInsets.zero,
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      children: [
        _buildStatCard(
          title: 'Total Karyawan',
          value: '$_totalKaryawan',
          subtitle: 'SDM Aktif Terdaftar',
          icon: Icons.people_alt_rounded,
          color: const Color(0xFF2563EB),
          bgColor: const Color(0xFFEFF6FF),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KaryawanListScreen())),
        ),
        _buildStatCard(
          title: 'Cabang Aktif',
          value: '$_totalCabang',
          subtitle: 'Titik Operasional',
          icon: Icons.storefront_rounded,
          color: const Color(0xFF7C3AED),
          bgColor: const Color(0xFFF5F3FF),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CabangListScreen())),
        ),
        _buildStatCard(
          title: 'Posisi Jabatan',
          value: '$_totalJabatan',
          subtitle: 'Struktur Organisasi',
          icon: Icons.work_outline_rounded,
          color: const Color(0xFF0D9488),
          bgColor: const Color(0xFFCCFBF1),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrdDataMasterScreen())),
        ),
        _buildStatCard(
          title: 'Katalog Layanan',
          value: '$_totalLayanan',
          subtitle: 'Jasa Pembersihan',
          icon: Icons.cleaning_services_rounded,
          color: const Color(0xFFD97706),
          bgColor: const Color(0xFFFEF3C7),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrdDataMasterScreen())),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF475569),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      color: const Color(0xFF94A3B8),
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

  // ================= 5. INFORMASI & PENGUMUMAN =================
  Widget _buildInformasiSection(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OperasionalPengumumanScreen()),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Papan Pengumuman & Kebijakan HRD',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Publikasikan memo, jadwal kerja, atau info internal',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF2563EB)),
          ],
        ),
      ),
    );
  }

  // ================= 6. TIPS / INFO JADWAL =================
  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFD97706), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Catatan Operasional HRD',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Batas toleransi jam masuk absensi karyawan adalah 08:15 WIB. Pastikan approval permohonan tukar libur disetujui sebelum H-1.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: GridView.count(
        padding: EdgeInsets.zero,
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.45,
        children: List.generate(
          4,
          (i) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

class _FastButtonItem {
  final String title;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  _FastButtonItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });
}
