import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';
import 'dart:io';
import '../../auth/screens/login_screen.dart';
import '../../auth/screens/change_pin_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Memuat...';
  String _userRole = 'Customer Service';
  String _userBranch = '-';
  String _userEmail = 'memuat...';
  String _userId = 'KLK-CS-0...';
  String? _userPhoto;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'CS';
      _userRole = prefs.getString('user_role') ?? 'Customer Service';
      _userBranch = prefs.getString('user_branch') ?? '-';
      _userEmail = prefs.getString('user_email') ?? '';
      _userId = prefs.getString('user_id') ?? '-';
      _userPhoto = prefs.getString('user_photo');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  _buildLogout(context),
                ],
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
              if (_userPhoto != null && _userPhoto!.isNotEmpty)
                ClipOval(
                  child: Image.file(
                    File(_userPhoto!),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                )
              else
                InitialsAvatar(
                  name: _userName,
                  size: 72,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  textColor: Colors.white,
                  borderColor: Colors.white.withOpacity(0.35),
                ),
              const SizedBox(height: 12),
          Text(_userName, style: GoogleFonts.inter(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
          )),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_userRole, style: GoogleFonts.inter(
                  fontSize: 11, color: Colors.white.withOpacity(0.85),
                )),
              ),
              if (_userBranch != '-') ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('📍 $_userBranch', style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.white.withOpacity(0.85),
                  )),
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

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        children: [
          _infoRow('ID Karyawan', _userId),
          const Divider(height: 16, color: AppColors.border),
          _infoRow('Email', _userEmail),
          const Divider(height: 16, color: AppColors.border),
          _infoRow('Status', 'Aktif'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label, style: GoogleFonts.inter(
          fontSize: 12, color: AppColors.textMuted,
        ))),
        Text(value, style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark,
        )),
      ],
    );
  }

  Widget _buildMenuSection(String title, List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final item = e.value;
          final isLast = e.key == items.length - 1;
          return Column(
            children: [
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon, size: 16, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(item.label, style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textDark,
                      ))),
                      if (item.trailing != null)
                        Text(item.trailing!, style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textMuted,
                        )),
                      if (item.onTap != null)
                        const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              if (!isLast) const Divider(height: 0, indent: 54, color: AppColors.border),
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
        label: Text('Keluar', style: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error,
        )),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Konfirmasi Keluar', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Apakah kamu yakin ingin keluar?', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Keluar', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
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
