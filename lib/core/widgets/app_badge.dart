import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_type.dart';
import '../constants/app_spacing.dart';

/// Nocturne's `tag`. A small pill-shaped label — plan badges, priority tags,
/// the widget setup screen's Include chips.
///
/// Two forms: `tag-accent` is an accent tint ground with [AppColors.inkAccent]
/// text; the outline form is a hairline with muted text. Which one you get
/// depends on whether [color] is the accent — everything the mocks tint is
/// tinted from the accent, and a badge in some other hue would be a second
/// accent, which this palette does not have.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.outlined = false,
  });

  final String label;

  /// Kept for the ~12 existing call sites that pass a semantic colour. It
  /// tints the ground and the label; pass null for the accent.
  final Color? color;
  final IconData? icon;

  /// The outline form: hairline edge, no tint.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final tone = color ?? c.accent;
    // The accent is not legible at 11–12px, so an accent-toned tag sets its
    // label in `inkAccent` instead. Any other tone is already a ramp step
    // chosen to read at this size.
    final label0 = identical(tone, c.accent) || tone == c.accent
        ? c.inkAccent
        : tone;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: outlined ? c.divider : tone.withValues(alpha: 0.40),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 3,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: outlined ? c.muted : label0),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppType.meta.copyWith(
                color: outlined ? c.muted : label0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
