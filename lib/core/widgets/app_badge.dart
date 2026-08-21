import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../constants/app_spacing.dart';

/// A small pill-shaped label, used for priority tags, plan badges, etc.
///
/// Built on [GlassChip], not [GlassBadge] — despite the name, GlassBadge is a
/// notification counter that decorates a child (a dot or a number in the
/// corner of something else). GlassChip is the package's pill.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GlassChip(
      label: label,
      icon: icon == null ? null : Icon(icon),
      iconSize: 12,
      iconColor: color,
      // `selected` is what tints the chip's material; without it the colour
      // that distinguishes one priority tag from another is carried by the
      // text alone, which is not enough to read at this size.
      selected: true,
      selectedColor: color.withValues(alpha: 0.14),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      spacing: 4,
      labelStyle: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
