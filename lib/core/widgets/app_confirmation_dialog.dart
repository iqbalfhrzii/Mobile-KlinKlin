import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ConfirmationDialogType {
  success,
  danger,
  warning,
  info,
}

class AppConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final ConfirmationDialogType type;
  final IconData? customIcon;
  final Color? customColor;
  final Widget? contentWidget;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;
  final bool isLoading;

  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.type = ConfirmationDialogType.info,
    this.customIcon,
    this.customColor,
    this.contentWidget,
    this.confirmText = 'Konfirmasi',
    this.cancelText = 'Batal',
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
    this.isLoading = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    ConfirmationDialogType type = ConfirmationDialogType.info,
    IconData? customIcon,
    Color? customColor,
    Widget? contentWidget,
    String confirmText = 'Konfirmasi',
    String cancelText = 'Batal',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AppConfirmationDialog(
        title: title,
        message: message,
        type: type,
        customIcon: customIcon,
        customColor: customColor,
        contentWidget: contentWidget,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
        onConfirm: () => Navigator.pop(ctx, true),
        onCancel: () => Navigator.pop(ctx, false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color primaryColor;
    Color bgColor;
    Color borderColor;
    IconData icon;

    switch (type) {
      case ConfirmationDialogType.success:
        primaryColor = const Color(0xFF059669);
        bgColor = const Color(0xFFDCFCE7);
        borderColor = const Color(0xFF86EFAC);
        icon = Icons.check_circle_rounded;
        break;
      case ConfirmationDialogType.danger:
        primaryColor = const Color(0xFFDC2626);
        bgColor = const Color(0xFFFEE2E2);
        borderColor = const Color(0xFFFCA5A5);
        icon = Icons.error_rounded;
        break;
      case ConfirmationDialogType.warning:
        primaryColor = const Color(0xFFD97706);
        bgColor = const Color(0xFFFEF3C7);
        borderColor = const Color(0xFFFDE68A);
        icon = Icons.warning_rounded;
        break;
      case ConfirmationDialogType.info:
        primaryColor = const Color(0xFF2563EB);
        bgColor = const Color(0xFFDBEAFE);
        borderColor = const Color(0xFF93C5FD);
        icon = Icons.info_rounded;
        break;
    }

    if (customColor != null) {
      primaryColor = customColor!;
      bgColor = customColor!.withValues(alpha: 0.15);
      borderColor = customColor!.withValues(alpha: 0.3);
    }
    if (customIcon != null) {
      icon = customIcon!;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: Colors.white,
      elevation: 10,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Icon Badge
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 2),
              ),
              child: Icon(icon, color: primaryColor, size: 30),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),

            // Message
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),

            if (contentWidget != null) ...[
              const SizedBox(height: 16),
              contentWidget!,
            ],

            const SizedBox(height: 22),

            // Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel ?? () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.white,
                    ),
                    child: Text(
                      cancelText,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : (onConfirm ?? () => Navigator.pop(context, true)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDestructive ? const Color(0xFFDC2626) : primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      shadowColor: (isDestructive ? const Color(0xFFDC2626) : primaryColor).withValues(alpha: 0.35),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            confirmText,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
