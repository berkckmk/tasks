import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_type.dart';
import '../constants/app_spacing.dart';

enum AppButtonVariant { primary, secondary, text }

/// The app's button. Constructor unchanged — 36 call sites depend on it.
///
/// **Primary is outlined, not filled.** 1px accent border on transparent,
/// accent text. This is the system's strongest rule and it inverts what this
/// widget did before, where `primary` was the package's `prominent` glass and
/// before that a solid `FilledButton`. A solid accent rectangle is a flood,
/// and the accent is a line and a mark.
///
/// `secondary` is the same geometry with the neutral hairline instead of the
/// accent edge; `text` has no edge at all.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.expand = false,
    this.pill = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool expand;

  /// A 999 radius. `2c` uses these; everything else takes the `md` step.
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final enabled = onPressed != null;

    final (Color foreground, Color? border) = switch (variant) {
      AppButtonVariant.primary => (c.accent, c.accent),
      AppButtonVariant.secondary => (c.text, c.divider),
      AppButtonVariant.text => (c.inkAccent, null),
    };

    final radius = BorderRadius.circular(
      pill ? AppSpacing.radiusPill : AppSpacing.radiusMd,
    );

    final content = Padding(
      padding: variant == AppButtonVariant.text
          ? const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            )
          : const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(label, style: AppType.title.copyWith(color: foreground)),
        ],
      ),
    );

    // Disabled drops the whole control to 45%, rather than swapping in a
    // separate disabled colour per part — one rule, and the edge and the
    // label can't drift out of step.
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: border == null ? null : Border.all(color: border),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            // Themed from the accent ramp, not the platform default.
            splashColor: c.accentTint(0.14),
            highlightColor: c.accentTint(0.08),
            hoverColor: c.accentTint(0.08),
            focusColor: c.accentTint(0.12),
            child: SizedBox(
              width: expand ? double.infinity : null,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
