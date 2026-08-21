import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../constants/app_spacing.dart';

/// A calm, low-elevation card used throughout the app instead of the
/// default Material [Card], to keep a consistent "premium" surface style.
///
/// Now a glass surface. The constructor is unchanged on purpose — this is used
/// in 29 places and none of them needed to know.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusMd);
    final body = Padding(padding: padding, child: child);

    return GlassCard(
      // Minimal skips the shader entirely and uses a BackdropFilter plus a
      // saturation matrix. Cards are list content — 29 of these can be on
      // screen at once inside a ListView, and the package is explicit that
      // scrolled surfaces should not be firing shader invocations per frame.
      quality: GlassQuality.minimal,
      shape: LiquidRoundedSuperellipse(borderRadius: AppSpacing.radiusMd),
      // The card's own padding is left at zero so the InkWell splash covers
      // the full surface rather than stopping at the content inset.
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      // Interactive descendants (ListTile, Switch, InkWell, ...) need a
      // Material ancestor to paint splashes/highlights, even when the card
      // itself isn't tappable — so this wraps every card, not just onTap ones.
      child: Material(
        color: Colors.transparent,
        child: onTap == null
            ? body
            : InkWell(onTap: onTap, borderRadius: radius, child: body),
      ),
    );
  }
}
