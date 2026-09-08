import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_confirmation_dialog.dart';
import '../../../core/services/auth_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/screens/change_pin_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../operasional/screens/operasional_permintaan_design_screen.dart';
import '../../operasional/screens/operasional_pengumuman_screen.dart';

class MarketingMenuScreen extends StatefulWidget {
  final Function(int index)? onSelectTab;

  const MarketingMenuScreen({super.key, this.onSelectTab});

  @override
  State<MarketingMenuScreen> createState() => _MarketingMenuScreenState();
}

class _MarketingMenuScreenState extends State<MarketingMenuScreen> {
  String _userName = 'Pengguna Marketing';
  String _userRole = 'Marketing';
  String _userBranch = '-';
  String _userEmail = '';
  String? _userPhoto;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedCustomName = prefs.getString('user_custom_name');
    final defaultName = prefs.getString('user_name') ?? 'Pengguna Marketing';

    if (mounted) {
      setState(() {
        _userName = cachedCustomName ?? defaultName;
        _userRole = prefs.getString('user_role') ?? 'Marketing';
        _userBranch = prefs.getString('user_branch') ?? '-';
        _userEmail = prefs.getString('user_email') ?? '';
        _userPhoto = prefs.getString('user_photo');
      });
    }

    try {
      final meResponse = await AuthService.getMe();
      final me = meResponse['data'] ?? meResponse;
      if (mounted && me is Map) {
        setState(() {
          if (me['name'] != null) _userName = me['name'].toString();
          if (me['email'] != null) _userEmail = me['email'].toString();
          if (me['foto'] != null) _userPhoto = me['foto'].toString();
          if (me['cabang'] != null && me['cabang']['nama_cabang'] != null) {
            _userBranch = me['cabang']['nama_cabang'].toString();
          }
        });
      }
    } catch (_) {}
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AppConfirmationDialog(
        title: 'Konfirmasi Keluar',
        message: 'Apakah Anda yakin ingin keluar dari akun ini?',
        type: ConfirmationDialogType.danger,
        customIcon: Icons.logout_rounded,
        confirmText: 'Keluar',
        cancelText: 'Batal',
        isDestructive: true,
        onConfirm: () async {
          Navigator.pop(context);
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );

          await AuthService.logout();

          if (mounted) {
            Navigator.pop(context);
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          GradientHeader(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Menu & Pengaturan',
                        style: GoogleFonts.inter(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pusat akses modul & pengaturan akun marketing',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // Profile Banner Card
                _buildProfileBanner(),
                const SizedBox(height: 18),

                // Group 1: Marketing & Promosi
                _buildSectionHeader('Marketing & Promosi', Icons.insights_rounded),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _MenuItem(
                    icon: Icons.paid_rounded,
                    iconColor: const Color(0xFF059669),
                    title: 'Spend Ads',
                    subtitle: 'Lacak pengeluaran iklan & perolehan leads',
                    onTap: () => widget.onSelectTab?.call(0),
                  ),
                  _MenuItem(
                    icon: Icons.trending_up_rounded,
                    iconColor: const Color(0xFF2563EB),
                    title: 'Progress Marketing',
                    subtitle: 'Monitoring target, closing, & performa leads',
                    onTap: () => widget.onSelectTab?.call(1),
                  ),
                  _MenuItem(
                    icon: Icons.perm_media_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    title: 'Konten Marketing',
                    subtitle: 'Materi promosi Story, Promo, & Follow Up',
                    onTap: () => widget.onSelectTab?.call(2),
                  ),
                ]),
                const SizedBox(height: 18),

                // Group 2: Notulensi Rapat
                _buildSectionHeader('Notulensi Rapat', Icons.event_note_rounded),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _MenuItem(
                    icon: Icons.calendar_month_rounded,
                    iconColor: const Color(0xFF4F46E5),
                    title: 'Rapat Bulanan',
                    subtitle: 'Evaluasi kinerja cabang, kendala & action plan',
                    onTap: () => widget.onSelectTab?.call(3),
                  ),
                  _MenuItem(
                    icon: Icons.today_rounded,
                    iconColor: const Color(0xFF0891B2),
                    title: 'Rapat Harian',
                    subtitle: 'Strategi harian, target program & operasional',
                    onTap: () => widget.onSelectTab?.call(3),
                  ),
                ]),
                const SizedBox(height: 18),

                // Group 3: Pengaturan & Desain
                _buildSectionHeader('Pengaturan & Desain', Icons.tune_rounded),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _MenuItem(
                    icon: Icons.palette_rounded,
                    iconColor: const Color(0xFFD97706),
                    title: 'Permintaan Design',
                    subtitle: 'Buat & pantau request materi visual ke designer',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OperasionalPermintaanDesignScreen(department: 'marketing'),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    icon: Icons.campaign_rounded,
                    iconColor: const Color(0xFFEA580C),
                    title: 'Pengumuman',
                    subtitle: 'Informasi dan instruksi resmi manajemen',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OperasionalPengumumanScreen(),
                        ),
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 18),

                // Group 4: Pengaturan Akun
                _buildSectionHeader('Pengaturan Akun', Icons.manage_accounts_rounded),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _MenuItem(
                    icon: Icons.person_rounded,
                    iconColor: const Color(0xFF475569),
                    title: 'Profil Saya',
                    subtitle: 'Informasi akun, kontak & foto profil',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    },
                  ),
                  _MenuItem(
                    icon: Icons.lock_reset_rounded,
                    iconColor: const Color(0xFF0D9488),
                    title: 'Ganti PIN',
                    subtitle: 'Ubah kode keamanan akun Anda',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChangePINScreen()),
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 24),

                // Logout Button
                OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                  label: Text(
                    'Keluar dari Akun',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    backgroundColor: const Color(0xFFFEF2F2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          AppAvatar(
            photoUrl: _userPhoto,
            name: _userName,
            size: 56,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: GoogleFonts.inter(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMid.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _userRole.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryMid,
                        ),
                      ),
                    ),
                    if (_userBranch != '-' && _userBranch.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _userBranch,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (_userEmail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _userEmail,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF475569),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildCardGroup(List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final isLast = idx == items.length - 1;

          return Column(
            children: [
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.vertical(
                  top: idx == 0 ? const Radius.circular(14) : Radius.zero,
                  bottom: isLast ? const Radius.circular(14) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: item.iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon, size: 20, color: item.iconColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: Color(0xFFCBD5E1),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast) const Divider(height: 1, indent: 54, color: Color(0xFFF1F5F9)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
