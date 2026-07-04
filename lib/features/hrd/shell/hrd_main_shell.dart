import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/screens/change_pin_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../screens/hrd_data_master_screen.dart';

import '../screens/hrd_dashboard_screen.dart';

class HrdMainShell extends StatefulWidget {
  const HrdMainShell({
    super.key,
    this.initialIndex = 0,
    this.requirePinChange = false,
    this.currentPin,
  });

  final int initialIndex;
  final bool requirePinChange;
  final String? currentPin;

  @override
  State<HrdMainShell> createState() => _HrdMainShellState();
}

class _HrdMainShellState extends State<HrdMainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  }

  final _screens = const [
    HrdDashboardScreen(),
    HrdDataMasterScreen(),
    ProfileScreen(),
  ];

  static const _navItems = [
    _NavItem(Icons.grid_view_rounded, Icons.grid_view_rounded, 'Dashboard'),
    _NavItem(Icons.storage_rounded, Icons.storage_rounded, 'Data Master'),
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
                            fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ini adalah login pertama Anda.\nDemi keamanan, silakan ganti PIN Anda.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13, color: AppColors.textMuted, height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChangePINScreen(
                                    isMandatory: true,
                                    currentPin: widget.currentPin ?? '',
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Ubah PIN Sekarang', style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white,
                            )),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              _navItems.length,
              (i) => _buildNavItem(i, _navItems[i]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, _NavItem item) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.primary : AppColors.textMuted;
    
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                key: ValueKey(isSelected),
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
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
