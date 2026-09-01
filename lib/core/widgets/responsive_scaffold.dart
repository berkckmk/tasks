import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_type.dart';
import '../constants/app_spacing.dart';
import '../layout/responsive_breakpoints.dart';

class NavDestinationItem {
  const NavDestinationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;

  /// The **Fill** weight of the same Phosphor glyph. Regular for inactive,
  /// Fill for selected — the one rule the whole icon set follows.
  final IconData selectedIcon;
  final String label;
}

/// The app chrome: an opaque bottom bar on narrow widths, a rail on wide ones.
///
/// ## What went away, and why nothing replaced it
///
/// The Liquid Glass tab bar was translucent and `GlassScaffold` painted it
/// *over* the body, extending the body behind it. That overlap is what made
/// the material worth having, but it meant the body had no idea the bar was
/// there — so this class published the bar's height through `MediaQuery`, and
/// every scrollable had to reserve it, and the FAB had to be lifted clear.
/// That machinery (`_tabBarExtent` and the MediaQuery override around the
/// body) is **gone**: an opaque bar in the Scaffold's own
/// `bottomNavigationBar` slot does not paint over the body, so there is
/// nothing to lift and nothing to reserve.
///
/// [scrollInsets] still reads `MediaQuery.padding.bottom`, which now returns
/// just the real system inset — which is correct, and is why that helper did
/// not need changing.
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.currentIndex,
    required this.destinations,
    required this.onDestinationSelected,
    required this.child,
  });

  final int currentIndex;
  final List<NavDestinationItem> destinations;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = ResponsiveBreakpoints.isWide(constraints.maxWidth);

        return Scaffold(
          backgroundColor: c.bg,
          body: isWide
              ? Row(children: [_rail(context), Expanded(child: child)])
              : child,
          bottomNavigationBar: isWide ? null : AppTabBar(
            currentIndex: currentIndex,
            destinations: destinations,
            onDestinationSelected: onDestinationSelected,
          ),
        );
      },
    );
  }

  /// The wide-width equivalent of the tab bar. Same tokens, laid out
  /// vertically, with the same hairline separating it from the body.
  Widget _rail(BuildContext context) {
    final c = AppColorsScheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(right: BorderSide(color: c.divider)),
      ),
      child: SizedBox(
        width: 84,
        child: SafeArea(
          right: false,
          child: Material(
            color: Colors.transparent,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    _NavItem(
                      item: destinations[i],
                      selected: i == currentIndex,
                      onTap: () => onDestinationSelected(i),
                      vertical: true,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bottom bar: four equal columns, an opaque `bg` ground and a single
/// hairline on top.
///
/// Public so `test/app_flow_test.dart` can scope a tap to the bar — several
/// destination labels ('Tasks', 'Reminders') are also body text on the screen
/// they open, so a bare `find.text` is ambiguous the moment a tab is
/// selected.
///
/// `grid-template-columns: repeat(4, 1fr)` in the mock, which is a [Row] of
/// [Expanded] here — not a Material `NavigationBar`, whose indicator pill,
/// 80px height and elevation tint all have to be fought off one by one and
/// still leave a surface tint behind.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    required this.currentIndex,
    required this.destinations,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final List<NavDestinationItem> destinations;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _NavItem(
                      item: destinations[i],
                      selected: i == currentIndex,
                      onTap: () => onDestinationSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One destination, in the bar or in the rail.
///
/// Icon 22, gap 4, label 10. Selected is `accent` plus the Fill glyph;
/// unselected is `text` at 45% plus the Regular glyph. No indicator pill, no
/// weight change on the label — the fill of the glyph is the state.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
    this.vertical = false,
  });

  final NavDestinationItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final color = selected ? c.accent : c.inactive;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        splashColor: c.accentTint(0.12),
        highlightColor: c.accentTint(0.06),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: vertical ? AppSpacing.md : AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 22,
                color: color,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.tabLabel.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
