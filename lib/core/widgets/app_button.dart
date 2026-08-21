import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app/theme/app_colors.dart';
import '../constants/app_spacing.dart';

enum AppButtonVariant { primary, secondary, text }

/// The app's button. Constructor unchanged — 36 call sites depend on it.
///
/// Two things about [GlassButton] are easy to get wrong and are worth stating
/// here, because its parameter names do not mean what they look like:
///
///  - `icon` is the button's *content slot*, and takes any widget. The text
///    row below goes there.
///  - `label` is the **semantic** label read by screen readers. It renders
///    nothing. The visible text has to be in `icon`.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    // Glass carries the brand colour in the text and glow rather than in a
    // solid fill — a filled green rectangle would defeat the material.
    final foreground = enabled ? AppColors.deepGreen : AppColors.subtleText;

    final content = Padding(
      padding: variant == AppButtonVariant.text
          ? const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12)
          : const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            label,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    return GlassButton(
      onTap: onPressed ?? () {},
      enabled: enabled,
      // Semantic only — see the class doc.
      label: label,
      icon: content,
      style: switch (variant) {
        // Prominent is the thicker, less transparent glass iOS 26 uses for a
        // primary call to action; it's what replaces the old solid FilledButton.
        AppButtonVariant.primary => GlassButtonStyle.prominent,
        AppButtonVariant.secondary => GlassButtonStyle.filled,
        // No surface at all, matching the old TextButton.
        AppButtonVariant.text => GlassButtonStyle.transparent,
      },
      shape: LiquidRoundedSuperellipse(borderRadius: AppSpacing.radiusMd),
      glowColor: AppColors.deepGreen,
      // Both null so the button sizes to `content` — the defaults are 56x56,
      // which is the circular icon-button geometry, not a text button.
      width: expand ? double.infinity : null,
      height: null,
    );
  }
}
