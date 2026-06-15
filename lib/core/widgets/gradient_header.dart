import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Header bergradient dengan rounded bottom corners — dipakai di semua halaman.
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -32,
              right: -32,
              child: Container(
                width: 128,
                height: 128,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x1AFFFFFF),
                ),
              ),
            ),
            Positioned(
              bottom: -24,
              right: 48,
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x0DFFFFFF),
                ),
              ),
            ),
            // Content
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// Back button bulat untuk header
class HeaderBackButton extends StatelessWidget {
  const HeaderBackButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
      ),
    );
  }
}

/// Icon button bulat untuk header (misal edit, notif)
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          if (badge)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.red[400],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact date-range filter chip — sama tinggi dengan chip filter lain.
/// Tap chip → buka date picker.  Tap ✕ (32px) → hapus filter.
class DateChip extends StatelessWidget {
  const DateChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: active ? AppColors.surfaceBlue : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? AppColors.primary : AppColors.border,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tap area to open picker
          GestureDetector(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 7, active ? 4 : 10, 7),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  Icons.date_range_rounded,
                  size: 13,
                  color: active ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: active ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ]),
            ),
          ),
          // Clear button — only visible when active, large 32×32 tap target
          if (active && onClear != null)
            GestureDetector(
              onTap: onClear,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
