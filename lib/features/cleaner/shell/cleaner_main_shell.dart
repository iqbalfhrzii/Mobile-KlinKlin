import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/screens/change_pin_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../dashboard/cleaner_dashboard_screen.dart';
import '../jobs/cleaner_job_list_screen.dart';

class CleanerMainShell extends StatefulWidget {
  const CleanerMainShell({
    super.key,
    this.initialIndex = 0,
    this.requirePinChange = false,
    this.currentPin,
  });

  final int initialIndex;
  final bool requirePinChange;
  final String? currentPin;

  @override
  State<CleanerMainShell> createState() => _CleanerMainShellState();
}

class _CleanerMainShellState extends State<CleanerMainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  }

  final _screens = const [
    CleanerDashboardScreen(),
    CleanerJobListScreen(),
    ProfileScreen(),
  ];

  static const _navItems = [
    _NavItem(Icons.grid_view_rounded, Icons.grid_view_rounded, 'Dashboard'),
    _NavItem(Icons.work_outline_rounded, Icons.work_rounded, 'Tugas'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: _buildNavBar(),
        ),
        if (widget.requirePinChange)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.85),
              child: SafeArea(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3CD),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.3), width: 4),
                          ),
                          child: const Icon(Icons.lock_reset_rounded, size: 40, color: Color(0xFFE6A300)),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Wajib Ganti PIN',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Untuk keamanan akun, kamu diwajibkan untuk mengganti PIN bawaan sistem sebelum mulai menggunakan aplikasi.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChangePINScreen(
                                    isMandatory: true,
                                    currentPin: widget.currentPin,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Ganti PIN Sekarang',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_navItems.length, (i) {
              final item = _navItems[i];
              final selected = _currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (widget.requirePinChange) return;
                    setState(() => _currentIndex = i);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.surfaceBlue : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          selected ? item.activeIcon : item.icon,
                          size: 22,
                          color: selected ? AppColors.primary : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          color: selected ? AppColors.primary : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem(this.icon, this.activeIcon, this.label);
}
