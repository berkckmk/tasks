import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../constants/app_spacing.dart';

/// Elevation levels, as Nocturne defines them.
///
/// On a dark ground elevation is **an edge plus ambient darkness**, never a
/// stack of shadows. `sm` is an edge and nothing else; the shadow only starts
/// at `md`, where the surface genuinely sits above the plane.
enum AppElevation { sm, md, lg }

/// A flat, opaque Nocturne panel.
///
/// Replaces the Liquid Glass card. Same constructor — this is used in 29
/// places and none of them needed to know — plus an [elevation] for the one
/// case `2b` needs, the raised next-up card that offsets out of the rail.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.elevation = AppElevation.sm,
    this.radius = AppSpacing.radiusMd,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final AppElevation elevation;
  final double radius;

  /// Overrides the hairline — used for the accent left-border on an Overdue
  /// group, and for a selected state.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final borderRadius = BorderRadius.circular(radius);

    final (Color edge, List<BoxShadow> shadow) = switch (elevation) {
      AppElevation.sm => (c.edgeSm, const <BoxShadow>[]),
      AppElevation.md => (c.edgeMd, c.shadowMd),
      AppElevation.lg => (c.edgeLg, c.shadowLg),
    };

    final body = Padding(padding: padding, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? edge),
        boxShadow: shadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        // Interactive descendants (ListTile, Switch, InkWell, ...) need a
        // Material ancestor to paint splashes, even when the card itself
        // isn't tappable — so this wraps every card, not just onTap ones.
        child: Material(
          color: Colors.transparent,
          child: onTap == null
              ? body
              : InkWell(onTap: onTap, borderRadius: borderRadius, child: body),
        ),
      ),
    );
  }
}
