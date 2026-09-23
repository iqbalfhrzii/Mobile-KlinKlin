import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ceo_privacy_controller.dart';

/// An elegant eye toggle button designed for CEO screens (similar to m-banking privacy buttons).
/// Tapping it toggles the masking of all financial nominals across the app.
class CeoPrivacyEyeButton extends StatelessWidget {
  final double iconSize;
  final EdgeInsetsGeometry? padding;
  final bool isWhiteTheme;
  final bool showLabel;
  final String? labelText;
  final Color? customColor;
  final VoidCallback? onToggled;
  final String? itemKey;

  const CeoPrivacyEyeButton({
    super.key,
    this.iconSize = 18,
    this.padding,
    this.isWhiteTheme = true,
    this.showLabel = false,
    this.labelText,
    this.customColor,
    this.onToggled,
    this.itemKey,
  });

  /// Factory for a mini circular eye button inside cards (e.g. Omzet Periode Ini, Total Omzet Gabungan)
  factory CeoPrivacyEyeButton.mini({
    Key? key,
    String? itemKey,
    bool isWhiteTheme = true,
    VoidCallback? onToggled,
  }) {
    return CeoPrivacyEyeButton(
      key: key,
      itemKey: itemKey,
      iconSize: 13,
      padding: const EdgeInsets.all(4),
      isWhiteTheme: isWhiteTheme,
      onToggled: onToggled,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CeoPrivacyController.instance,
      builder: (context, _) {
        final isMasked = itemKey != null
            ? CeoPrivacyController.instance.isItemMasked(itemKey!)
            : !CeoPrivacyController.instance.isAnyVisible;
        final tooltip = isMasked ? 'Tampilkan nominal' : 'Sembunyikan nominal';

        final Color foregroundColor = customColor ??
            (isWhiteTheme
                ? (isMasked ? const Color(0xFFFDE68A) : Colors.white)
                : (isMasked ? const Color(0xFFD97706) : const Color(0xFF475569)));

        final Color backgroundColor = isWhiteTheme
            ? (isMasked
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.16))
            : (isMasked
                ? const Color(0xFFFEF3C7)
                : const Color(0xFFF1F5F9));

        final Color borderColor = isWhiteTheme
            ? (isMasked
                ? const Color(0xFFFDE68A).withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.28))
            : (isMasked
                ? const Color(0xFFFBBF24).withValues(alpha: 0.4)
                : const Color(0xFFE2E8F0));

        return Tooltip(
          message: tooltip,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (itemKey != null) {
                  CeoPrivacyController.instance.toggleItem(itemKey!);
                } else {
                  CeoPrivacyController.instance.toggle();
                }
                onToggled?.call();
              },
              borderRadius: BorderRadius.circular(20),
              splashColor: isWhiteTheme
                  ? Colors.white.withValues(alpha: 0.2)
                  : const Color(0xFFE2E8F0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: padding ??
                    (showLabel
                        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
                        : const EdgeInsets.all(7)),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        isMasked
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        key: ValueKey<bool>(isMasked),
                        size: iconSize,
                        color: foregroundColor,
                      ),
                    ),
                    if (showLabel) ...[
                      const SizedBox(width: 5),
                      Text(
                        labelText ?? (isMasked ? 'Sembunyi' : 'Terlihat'),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: foregroundColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
