import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';

class PermissionHelper {
  /// Request essential permissions on initial app launch / login
  /// This ensures iOS registers the app in Settings > Privacy & Security
  static Future<void> requestInitialPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasRequested = prefs.getBool('has_requested_initial_permissions') ?? false;

      // Always request notification
      await Permission.notification.request();

      // On first launch or if not requested yet, prompt location & camera
      if (!hasRequested) {
        await Permission.location.request();
        // Camera can also be requested so it immediately appears in iOS Settings
        await Permission.camera.request();
        await prefs.setBool('has_requested_initial_permissions', true);
      }
    } catch (e) {
      debugPrint('Error requesting initial permissions: $e');
    }
  }

  /// Request Camera Permission with fallback to Settings dialog if denied
  static Future<bool> requestCameraPermission(BuildContext context) async {
    try {
      var status = await Permission.camera.status;

      if (status.isGranted || status.isLimited) {
        return true;
      }

      if (status.isDenied) {
        status = await Permission.camera.request();
        if (status.isGranted || status.isLimited) {
          return true;
        }
      }

      if (status.isPermanentlyDenied || status.isRestricted || status.isDenied) {
        if (context.mounted) {
          _showPermissionDialog(
            context,
            title: 'Izin Kamera Diperlukan',
            message:
                'Aplikasi membutuhkan akses kamera untuk mengambil foto absensi selfie dan bukti pekerjaan. Silakan aktifkan izin kamera di Pengaturan.',
            permission: Permission.camera,
          );
        }
        return false;
      }

      return status.isGranted;
    } catch (e) {
      debugPrint('Camera permission error: $e');
      return false;
    }
  }

  /// Request Location Permission with fallback to Settings dialog
  static Future<bool> requestLocationPermission(BuildContext context) async {
    try {
      var status = await Permission.location.status;

      if (status.isGranted || status.isLimited) {
        return true;
      }

      if (status.isDenied) {
        status = await Permission.location.request();
        if (status.isGranted || status.isLimited) {
          return true;
        }
      }

      if (status.isPermanentlyDenied || status.isRestricted || status.isDenied) {
        if (context.mounted) {
          _showPermissionDialog(
            context,
            title: 'Izin Lokasi Diperlukan',
            message:
                'Aplikasi membutuhkan akses lokasi untuk verifikasi kehadiran (absensi) dan penugasan cabang. Silakan aktifkan izin lokasi di Pengaturan.',
            permission: Permission.location,
          );
        }
        return false;
      }

      return status.isGranted;
    } catch (e) {
      debugPrint('Location permission error: $e');
      return false;
    }
  }

  /// Request Photo Library Permission
  static Future<bool> requestPhotoPermission(BuildContext context) async {
    try {
      var status = await Permission.photos.status;

      if (status.isGranted || status.isLimited) {
        return true;
      }

      if (status.isDenied) {
        status = await Permission.photos.request();
        if (status.isGranted || status.isLimited) {
          return true;
        }
      }

      if (status.isPermanentlyDenied || status.isRestricted) {
        if (context.mounted) {
          _showPermissionDialog(
            context,
            title: 'Izin Galeri Diperlukan',
            message:
                'Aplikasi membutuhkan akses galeri untuk memilih foto atau bukti transfer. Silakan aktifkan izin galeri di Pengaturan.',
            permission: Permission.photos,
          );
        }
        return false;
      }

      return status.isGranted;
    } catch (e) {
      debugPrint('Photo permission error: $e');
      return false;
    }
  }

  /// Show standard dialog redirecting user to iOS/Android App Settings
  static void _showPermissionDialog(
    BuildContext context, {
    required String title,
    required String message,
    required Permission permission,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textDark.withValues(alpha: 0.7),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
            child: Text(
              'Buka Pengaturan',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
