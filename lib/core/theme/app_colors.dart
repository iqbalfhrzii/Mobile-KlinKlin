import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette (dari web: #004F91 → #0072CE → #00A0D4)
  static const Color primary = Color(0xFF004F91);
  static const Color primaryMid = Color(0xFF0072CE);
  static const Color primaryLight = Color(0xFF00A0D4);

  // Background & surface
  static const Color background = Color(0xFFF4F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceBlue = Color(0xFFE8F0F9);

  // Text
  static const Color textDark = Color(0xFF0D1B2A);
  static const Color textMuted = Color(0xFF9BA8BB);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Status
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusPendingBg = Color(0xFFFFFBEB);
  static const Color statusAssigned = Color(0xFF3B82F6);
  static const Color statusAssignedBg = Color(0xFFEFF6FF);
  static const Color statusProgress = Color(0xFF8B5CF6);
  static const Color statusProgressBg = Color(0xFFF5F3FF);
  static const Color statusDone = Color(0xFF10B981);
  static const Color statusDoneBg = Color(0xFFECFDF5);
  static const Color statusCancel = Color(0xFFEF4444);
  static const Color statusCancelBg = Color(0xFFFEF2F2);

  // Category
  static const Color vip = Color(0xFFF59E0B);
  static const Color vipBg = Color(0xFFFFF8E1);
  static const Color premium = Color(0xFF7C3AED);
  static const Color premiumBg = Color(0xFFEDE9FE);
  static const Color reguler = Color(0xFF004F91);
  static const Color regulerBg = Color(0xFFE8F0F9);

  // Error
  static const Color error = Color(0xFFD32F2F);
  static const Color errorBg = Color(0xFFFFEBEE);

  // Success
  static const Color success = Color(0xFF2E7D32);
  static const Color successBg = Color(0xFFE8F5E9);

  // Gradient
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryMid, primaryLight],
    stops: [0.0, 0.55, 1.0],
  );

  // Border & shadow
  static const Color border = Color(0x14004F91); // rgba(0,79,145,0.08)
  static const Color borderLight = Color(0x0A004F91);
  static BoxShadow get cardShadow => const BoxShadow(
    color: Color(0x12004F91),
    blurRadius: 10,
    offset: Offset(0, 2),
  );
}
