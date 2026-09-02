import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/screens/change_pin_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../screens/ceo_dashboard_screen.dart';
import '../screens/ceo_grafik_screen.dart';
import '../screens/ceo_data_chat_screen.dart';
import '../screens/ceo_menu_screen.dart';

class CeoMainShell extends StatefulWidget {
  const CeoMainShell({
    super.key,
    this.initialIndex = 0,
    this.requirePinChange = false,
    this.currentPin,
  });

  final int initialIndex;
  final bool requirePinChange;
  final String? currentPin;

  @override
  State<CeoMainShell> createState() => _CeoMainShellState();
}

class _CeoMainShellState extends State<CeoMainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  }

  static const _navItems = [
    _NavItem(Icons.analytics_outlined, Icons.analytics_rounded, 'Capaian'),
    _NavItem(Icons.insert_chart_outlined_rounded, Icons.insert_chart_rounded, 'Grafik'),
    _NavItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Data Chat'),
    _NavItem(Icons.widgets_outlined, Icons.widgets_rounded, 'Menu'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final screens = const [
      CeoDashboardScreen(),
      CeoGrafikScreen(),
      CeoDataChatScreen(),
      CeoMenuScreen(),
      ProfileScreen(),
    ];

    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: _buildNavBar(),
        ),
        if (widget.requirePinChange)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.85),
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
                          color: Colors.black.withValues(alpha: 0.2),
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
                            border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.3), width: 4),
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
                              foregroundColor: Colors.white,
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
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 6,
        right: 6,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 4
            : 10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_navItems.length, (i) {
          final item = _navItems[i];
          final isSelected = _currentIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _currentIndex = i);
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isSelected ? item.activeIcon : item.icon,
                        size: 22,
                        color: isSelected ? AppColors.primary : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppColors.primary : AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
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
