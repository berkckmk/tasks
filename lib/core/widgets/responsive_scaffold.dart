import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app/theme/app_colors.dart';
import '../constants/app_spacing.dart';
import '../layout/responsive_breakpoints.dart';

class NavDestinationItem {
  const NavDestinationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The app chrome: a glass tab bar on narrow (mobile) widths, a glass rail on
/// wide (web/tablet/desktop) widths — same destinations, same selection
/// callback either way.
///
/// [AppBackdrop] is installed once here, as the [GlassScaffold] background, so
/// every glass surface in the app has the same thing to refract. Feature
/// screens keep their own [Scaffold]s; those are transparent (see
/// `AppTheme.light()`) and paint over this rather than replacing it.
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = ResponsiveBreakpoints.isWide(constraints.maxWidth);

        return GlassScaffold(
          // No background here: AppGlassPage supplies it once for every route
          // from MaterialApp.builder, so a second copy would only paint the
          // same gradient twice and start a nested backdrop scope.
          statusBarStyle: GlassStatusBarStyle.auto,
          // Deliberately left off: content-aware brightness exists for bars
          // floating over an unknown photo. The backdrop here is a known,
          // low-contrast gradient, so the explicit brand colours below are
          // both correct and stable. Turn this on if AppBackdrop ever becomes
          // a user-supplied image.
          contentAwareBrightness: false,
          body: isWide ? _wideBody(context) : _narrowBody(context),
          bottomBar: isWide ? null : _tabBar(),
        );
      },
    );
  }

  /// Vertical space the glass tab bar occupies above the system safe area.
  ///
  /// `GlassTabBar.bottom` defaults: `barHeight` 64 plus `verticalPadding` 20.
  static const _tabBarExtent = 64.0 + 20.0;

  /// Tells the feature screens' own [Scaffold]s that the tab bar is there.
  ///
  /// GlassScaffold paints `bottomBar` *over* the body and extends the body
  /// behind it, and the inner Scaffold has no way to know that — so it placed
  /// its FloatingActionButton at its own bottom edge, which put the add button
  /// underneath the glass bar, blurred by it and half off the right end.
  ///
  /// Scaffold positions the FAB from `MediaQuery.viewPadding.bottom`, so
  /// adding the bar's extent there lifts it clear. `padding` is raised with it
  /// so any SafeArea in a screen body agrees.
  Widget _narrowBody(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(
          bottom: media.padding.bottom + _tabBarExtent,
        ),
        viewPadding: media.viewPadding.copyWith(
          bottom: media.viewPadding.bottom + _tabBarExtent,
        ),
      ),
      child: child,
    );
  }

  /// Explicit label styles, and specifically `decoration: TextDecoration.none`.
  ///
  /// Not cosmetic. GlassScaffold wraps a CupertinoPageScaffold, so unlike the
  /// Material NavigationBar this replaces, the tab labels have no Material
  /// ancestor supplying a DefaultTextStyle. Flutter falls back to
  /// `DefaultTextStyle.fallback()`, which paints text with a **yellow double
  /// underline** as a "this text has no style ancestor" hint — visible on the
  /// device under all six labels. Setting the colour alone doesn't clear it;
  /// the decoration has to be stated.
  static const _labelStyle = TextStyle(
    fontSize: 11,
    decoration: TextDecoration.none,
  );

  Widget _tabBar() {
    return GlassTabBar.bottom(
      selectedIndex: currentIndex,
      onTabSelected: onDestinationSelected,
      selectedIconColor: AppColors.deepGreen,
      unselectedIconColor: AppColors.subtleText,
      selectedLabelColor: AppColors.deepGreen,
      unselectedLabelColor: AppColors.subtleText,
      selectedLabelStyle: _labelStyle.copyWith(
        color: AppColors.deepGreen,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: _labelStyle.copyWith(color: AppColors.subtleText),
      tabs: destinations
          .map(
            (d) => GlassTab(
              icon: Icon(d.icon),
              activeIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
          )
          .toList(),
    );
  }

  /// The wide-width equivalent of the tab bar.
  ///
  /// Built by hand rather than from the package: it ships `GlassTabBar` in
  /// bottom / inline / searchable forms only, none of which is a vertical
  /// rail. A [GlassContainer] holding a column of destinations is the closest
  /// faithful equivalent, and keeps the same glass material as the tab bar it
  /// replaces.
  Widget _wideBody(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: GlassContainer(
            width: 92,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: const LiquidRoundedSuperellipse(
              borderRadius: AppSpacing.radiusLg,
            ),
            // GlassScaffold wraps a CupertinoPageScaffold, so unlike the old
            // Material Scaffold there is no Material ancestor here for the
            // rail's InkWells to paint their splashes into. Same reason
            // AppCard carries one.
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: Icon(
                      Icons.spa_outlined,
                      color: AppColors.deepGreen,
                      size: 28,
                    ),
                  ),
                  const GlassDivider(indent: 16, endIndent: 16),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (var i = 0; i < destinations.length; i++)
                            _RailDestination(
                              item: destinations[i],
                              selected: i == currentIndex,
                              onTap: () => onDestinationSelected(i),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// One entry in the wide-width rail.
///
/// Not a [GlassIconButton]: the rail is already a glass surface, and the
/// package is explicit that interactive glass controls must not be nested
/// inside a glass container — each draws its own material, and stacked they
/// read as two panes rather than one. So this is a plain tap target whose
/// selected state is carried by the icon, the weight and the colour.
class _RailDestination extends StatelessWidget {
  const _RailDestination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavDestinationItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.deepGreen : AppColors.subtleText;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: [
              Icon(selected ? item.selectedIcon : item.icon, color: color),
              const SizedBox(height: 4),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
