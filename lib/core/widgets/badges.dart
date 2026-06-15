import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final String status; // 'pending' | 'assigned' | 'in_progress' | 'completed' | 'paid'

  static const _config = {
    'pending':     _BadgeConfig('Menunggu',   AppColors.statusPending,  AppColors.statusPendingBg),
    'assigned':    _BadgeConfig('Ditugaskan', AppColors.statusAssigned, AppColors.statusAssignedBg),
    'in_progress': _BadgeConfig('Dikerjakan', AppColors.statusProgress, AppColors.statusProgressBg),
    'completed':   _BadgeConfig('Selesai',    AppColors.statusDone,     AppColors.statusDoneBg),
    'paid':        _BadgeConfig('Lunas',      AppColors.statusDone,     AppColors.statusDoneBg),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _config[status] ?? _config['pending']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        cfg.label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: cfg.color,
        ),
      ),
    );
  }
}

class _BadgeConfig {
  const _BadgeConfig(this.label, this.color, this.bg);
  final String label;
  final Color color;
  final Color bg;
}

/// Avatar inisial (tanpa foto)
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.backgroundColor = AppColors.surfaceBlue,
    this.textColor = AppColors.primary,
    this.borderColor,
  });

  final String name;
  final double size;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 2)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: GoogleFonts.inter(
          fontSize: size * 0.32,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}

/// Category chip (VIP / Premium / Reguler)
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.category});
  final String category;

  static const _colors = {
    'VIP':     _BadgeConfig('VIP',     AppColors.vip,     AppColors.vipBg),
    'Premium': _BadgeConfig('Premium', AppColors.premium, AppColors.premiumBg),
    'Reguler': _BadgeConfig('Reguler', AppColors.reguler, AppColors.regulerBg),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _colors[category] ?? _colors['Reguler']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cfg.color.withOpacity(0.3)),
      ),
      child: Text(
        cfg.label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: cfg.color,
        ),
      ),
    );
  }
}
