import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../screens/operasional_dashboard_screen.dart';
import '../screens/operasional_order_list_screen.dart';
import '../screens/operasional_kpi_main_screen.dart';
import '../screens/operasional_menu_screen.dart';
import '../../profile/screens/profile_screen.dart';

class OperasionalMainShell extends StatefulWidget {
  const OperasionalMainShell({
    super.key,
    this.initialIndex = 0,
  });

  final int initialIndex;

  @override
  State<OperasionalMainShell> createState() => _OperasionalMainShellState();
}

class _OperasionalMainShellState extends State<OperasionalMainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  }

  List<Widget> get _screens => [
    const OperasionalDashboardScreen(),
    const OperasionalOrderListScreen(),
    const OperasionalKpiMainScreen(),
    const OperasionalMenuScreen(),
    const ProfileScreen(),
  ];

  static const _navItems = [
    _NavItem(Icons.grid_view_rounded, Icons.grid_view_rounded, 'Omzet'),
    _NavItem(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Pesanan'),
    _NavItem(Icons.analytics_outlined, Icons.analytics_rounded, 'KPI'),
    _NavItem(Icons.widgets_outlined, Icons.widgets_rounded, 'Menu'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
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
              (index) => _buildNavItem(index, _navItems[index]),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                key: ValueKey<bool>(isSelected),
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
