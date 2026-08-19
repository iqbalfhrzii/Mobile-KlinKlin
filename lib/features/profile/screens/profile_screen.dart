import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/api/api_client.dart';
import 'dart:io';
import 'dart:convert';
import '../../auth/screens/login_screen.dart';
import '../../auth/screens/change_pin_screen.dart';
import 'edit_profile_screen.dart';
import 'kpi_screen.dart';
import '../../stok_opname/screens/stok_opname_screen.dart';
import '../../master_barang/screens/master_barang_screen.dart';
import '../../cleaner/tukar_libur/screens/tukar_libur_screen.dart';
import '../../cleaner/tukar_libur/services/tukar_libur_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Memuat...';
  String _userRole = 'Cleaner';
  String _userBranch = '-';
  String _userEmail = 'memuat...';
  String _userId = 'KLK-CS-0...';
  String? _userPhoto;

  // Jadwal Libur Cleaner State
  List<dynamic> _jadwalLiburs = [];
  bool _isLoadingLibur = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Pengguna';
      _userRole = prefs.getString('user_role') ?? 'Cleaner';
      _userBranch = prefs.getString('user_branch') ?? '-';
      _userEmail = prefs.getString('user_email') ?? '';
      _userId = prefs.getString('user_id') ?? '-';
      _userPhoto = prefs.getString('user_photo');
    });

    try {
      final meResponse = await AuthService.getMe();
      final me = meResponse['data'] ?? meResponse;
      if (mounted) {
        setState(() {
          _userName = me['nama'] ?? _userName;
          _userPhoto = me['foto_profil'];
          _userRole = me['jabatan'] is Map ? me['jabatan']['nama_jabatan'] ?? _userRole : _userRole;
          _userBranch = me['cabang'] is Map ? me['cabang']['nama_cabang'] ?? _userBranch : _userBranch;
          _userEmail = me['email'] ?? _userEmail;
        });
      }
    } catch (_) {
      // Ignore if fetch fails
    }

    if (_isCleanerRole()) {
      _loadJadwalLibur();
    }
  }

  bool _isCleanerRole() {
    return _userRole.toLowerCase().contains('cleaner');
  }

  Future<void> _loadJadwalLibur() async {
    setState(() => _isLoadingLibur = true);
    try {
      final data = await TukarLiburService.getRekanKerja();
      if (mounted) {
        setState(() {
          _jadwalLiburs = data['libur_saya'] ?? [];
          _isLoadingLibur = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLibur = false);
    }
  }

  String _formatIndoDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '-';
    try {
      final dt = DateTime.parse(rawDate);
      final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      final dayName = days[dt.weekday % 7];
      final monthName = months[dt.month - 1];
      return '$dayName, ${dt.day} $monthName ${dt.year}';
    } catch (_) {
      return rawDate;
    }
  }

  String _getCurrentMonthName() {
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadProfile,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                child: Column(
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 14),

                    // Section Khusus Cleaner: Informasi Jadwal Libur
                    if (_isCleanerRole()) ...[
                      _buildJadwalLiburCard(),
                      const SizedBox(height: 14),
                    ],

                    if (!_isCleanerRole()) ...[
                      _buildMenuSection('Karyawan', [
                        _MenuItem(Icons.analytics_rounded, 'KPI & Evaluasi Kinerja', onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const KpiScreen()));
                        }),
                      ]),
                      const SizedBox(height: 12),
                      if (_userRole.toLowerCase().contains('cs') || _userRole.toLowerCase().contains('customer service')) ...[
                        _buildMenuSection('Manajemen CS', [
                          _MenuItem(Icons.fact_check_outlined, 'Stok Opname', onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const StokOpnameScreen()));
                          }),
                        ]),
                        const SizedBox(height: 12),
                      ],
                      if (_userRole.toLowerCase().contains('operasional') || _userRole.toLowerCase().contains('admin')) ...[
                        _buildMenuSection('Manajemen Operasional', [
                          _MenuItem(Icons.inventory_2_outlined, 'Master Barang & Aset', onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const MasterBarangScreen()));
                          }),
                        ]),
                        const SizedBox(height: 12),
                      ],
                    ],

                    _buildMenuSection('Akun', [
                      _MenuItem(Icons.lock_outline_rounded, 'Ganti PIN', onTap: () => _changePIN(context)),
                      _MenuItem(Icons.notifications_outlined, 'Notifikasi', onTap: () {}),
                      _MenuItem(Icons.language_outlined, 'Bahasa', trailing: 'Indonesia', onTap: () {}),
                    ]),
                    const SizedBox(height: 12),
                    _buildMenuSection('Tentang', [
                      _MenuItem(Icons.info_outline_rounded, 'Versi Aplikasi', trailing: '1.0.0'),
                      _MenuItem(Icons.help_outline_rounded, 'Bantuan', onTap: () {}),
                      _MenuItem(Icons.privacy_tip_outlined, 'Kebijakan Privasi', onTap: () {}),
                    ]),
                    const SizedBox(height: 16),
                    _buildLogout(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: HeaderIconButton(
              icon: Icons.edit_outlined,
              onTap: () async {
                final updated = await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const EditProfileScreen()
                ));
                if (updated == true) _loadProfile();
              },
            ),
          ),
          Column(
            children: [
              _buildAvatar(),
              const SizedBox(height: 12),
              Text(
                _userName,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      _userRole,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (_userBranch != '-' && _userBranch.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 12, color: Colors.white),
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
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (_userPhoto == null || _userPhoto!.isEmpty) {
      return InitialsAvatar(
        name: _userName,
        size: 76,
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        textColor: Colors.white,
        borderColor: Colors.white.withValues(alpha: 0.35),
      );
    }

    if (_userPhoto!.startsWith('data:image')) {
      try {
        final base64Str = _userPhoto!.split(',').last;
        return ClipOval(child: Image.memory(base64Decode(base64Str), width: 76, height: 76, fit: BoxFit.cover));
      } catch (_) {
        return InitialsAvatar(name: _userName, size: 76, backgroundColor: Colors.white.withValues(alpha: 0.2), textColor: Colors.white, borderColor: Colors.white.withValues(alpha: 0.35));
      }
    }

    if (_userPhoto!.startsWith('http')) {
      return ClipOval(
        child: Image.network(
          _userPhoto!,
          width: 76,
          height: 76,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => InitialsAvatar(name: _userName, size: 76, backgroundColor: Colors.white.withValues(alpha: 0.2), textColor: Colors.white, borderColor: Colors.white.withValues(alpha: 0.35)),
        ),
      );
    }

    if (_userPhoto!.startsWith('/')) {
      return ClipOval(
        child: Image.file(
          File(_userPhoto!),
          width: 76,
          height: 76,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => InitialsAvatar(name: _userName, size: 76, backgroundColor: Colors.white.withValues(alpha: 0.2), textColor: Colors.white, borderColor: Colors.white.withValues(alpha: 0.35)),
        ),
      );
    }

    final baseDomain = ApiClient.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    final url = '$baseDomain/storage/$_userPhoto';
    return ClipOval(
      child: Image.network(
        url,
        width: 76,
        height: 76,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => InitialsAvatar(name: _userName, size: 76, backgroundColor: Colors.white.withValues(alpha: 0.2), textColor: Colors.white, borderColor: Colors.white.withValues(alpha: 0.35)),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _infoRow('ID Karyawan', _userId, isHighlight: true),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _infoRow('Email', _userEmail),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _infoRow('Status', 'Aktif', badgeColor: const Color(0xFF16A34A), badgeBg: const Color(0xFFDCFCE7)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isHighlight = false, Color? badgeColor, Color? badgeBg}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        if (badgeColor != null && badgeBg != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: badgeColor),
            ),
          )
        else
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
      ],
    );
  }

  // --- DEDICATED JADWAL LIBUR CARD UNTUK CLEANER ---
  Widget _buildJadwalLiburCard() {
    final currentMonth = _getCurrentMonthName();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event_available_rounded, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jadwal Libur Saya',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        currentMonth,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const TukarLiburScreen()));
                  _loadJadwalLibur();
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Tukar Libur',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // List Hari Libur
          if (_isLoadingLibur)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            )
          else if (_jadwalLiburs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Belum ada jadwal libur bulan ini.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _jadwalLiburs.asMap().entries.map((entry) {
                final idx = entry.key;
                final libur = entry.value;
                final tanggalStr = libur['tanggal']?.toString() ?? '';
                final isSwapped = libur['is_swapped'] == true || libur['is_swapped'] == 1;
                final formattedDate = _formatIndoDate(tanggalStr);

                return Container(
                  margin: EdgeInsets.only(bottom: idx == _jadwalLiburs.length - 1 ? 0 : 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          formattedDate,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSwapped ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isSwapped ? 'Hasil Tukar' : 'Libur Rutin',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSwapped ? const Color(0xFFB45309) : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(String title, List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final item = e.value;
          final isLast = e.key == items.length - 1;
          return Column(
            children: [
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon, size: 16, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                        ),
                      ),
                      if (item.trailing != null)
                        Text(
                          item.trailing!,
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      if (item.onTap != null)
                        const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
              if (!isLast) const Divider(height: 0, indent: 56, color: Color(0xFFF1F5F9)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLogout(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _confirmLogout(context),
        icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
        label: Text(
          'Keluar',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.error),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  void _changePIN(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const ChangePINScreen(),
    ));
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Konfirmasi Keluar', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text('Apakah kamu yakin ingin keluar dari akun ini?', style: GoogleFonts.inter(color: const Color(0xFF475569))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );

              await AuthService.logout();

              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Keluar', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.icon, this.label, {this.onTap, this.trailing});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? trailing;
}
