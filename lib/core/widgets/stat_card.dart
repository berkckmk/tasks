import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_type.dart';
import '../constants/app_spacing.dart';
import 'app_card.dart';

/// One of the three stat tiles.
///
/// **No coloured icon chips.** The green/blue/amber tinted squares this used
/// to draw are gone: Nocturne is a mono-accent palette, and three hues in a
/// row of three tiles was the clearest signal that the old screen had no
/// system behind it. The icon is now an 18px Phosphor glyph in `inkAccent`,
/// then the value at 20/500, then an 11px label.
///
/// [accentColor] is kept because ~6 call sites pass one, but it is only ever
/// honoured as the icon's colour — it can no longer paint a chip.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accentColor ?? c.inkAccent),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppType.h5.copyWith(
              fontSize: 20,
              color: c.text,
              fontFeatures: AppType.tabular,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppType.metaSmall.copyWith(color: c.caption),
          ),
        ],
      ),
    );
  }
}
