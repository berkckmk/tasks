import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../constants/app_spacing.dart';

/// A calm, low-elevation card used throughout the app instead of the
/// default Material [Card], to keep a consistent "premium" surface style.
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

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
        border: Border.all(color: AppColors.divider),
      ),
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
