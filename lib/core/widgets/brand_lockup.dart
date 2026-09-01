import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_type.dart';
import '../constants/app_spacing.dart';
import 'progress_ring.dart';

/// The app mark: the progress ring on an ink tile.
///
/// Deliberately the *same widget* the dashboard draws its progress with, at a
/// fixed 72% — the icon, the widget's ring and the app's own ring are one arc
/// at three sizes, and building the lockup out of a separate hand-drawn SVG
/// is how those three quietly drift apart.
///
/// No letter, no gradient, no glyph. It has to stay legible at 32px, and the
/// stroke is the only thing on it.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 28});

  final double size;

  /// 154 / 213.6 — the icon's `stroke-dasharray: 154 214` on a circle of
  /// circumference 213.6.
  static const double arcFraction = 0.72;

  /// The tile's own ground. Darker than `bg` so the mark reads as a tile on
  /// the app rather than as a hole in it, and constant across themes because
  /// a launcher icon has no theme to follow.
  static const Color tile = Color(0xFF1B1D2B);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tile,
          // 22.5% of the tile, as the icon spec states.
          borderRadius: BorderRadius.circular(size * 0.225),
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.16),
          child: ProgressRing(
            progress: arcFraction,
            size: size * 0.68,
            // The icon's stroke is 13 on a 100 canvas against r=34; scaled to
            // the ring painter's own 27/64 radius this is the equivalent.
            strokeWidth: size * 0.135,
            color: AppColors.accent,
            trackColor: AppColors.accent.withValues(alpha: 0.22),
          ),
        ),
      ),
    );
  }
}

/// The mark beside the product name — the header lockup, placed at the very
/// top of the Profile screen.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.subtitle});

  /// e.g. "Complete plan · beta". Optional.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandMark(size: 27),
        const SizedBox(width: AppSpacing.sm + 1),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Steady Progress',
              style: AppType.title.copyWith(
                fontSize: 13.5,
                letterSpacing: -0.01 * 13.5,
                color: c.text,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 1),
              Text(
                subtitle!,
                style: AppType.metaSmall.copyWith(
                  fontSize: 10.5,
                  color: c.caption,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
