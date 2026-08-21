import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app/theme/app_colors.dart';

/// The app's app bar.
///
/// Wraps [GlassAppBar], which drops straight into `Scaffold.appBar` because it
/// implements `ObstructingPreferredSizeWidget` — this wrapper forwards that
/// contract unchanged.
///
/// Two Material behaviours have to be rebuilt here, because [GlassAppBar]
/// deliberately has neither:
///
///  1. **The back button.** Material's `AppBar` synthesises a leading back
///     button whenever the route can pop (`automaticallyImplyLeading`).
///     GlassAppBar's `leading` is null unless you pass one — every example in
///     the package supplies its own. Without [_maybeBackButton] below, all ~20
///     pushed screens lose their only way back.
///  2. **The title style.** GlassAppBar's title is an ordinary child widget
///     and does not read Material's `AppBarTheme`, so the style is applied
///     here rather than restated on all 30 screens.
class AppGlassAppBar extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  const AppGlassAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  final Widget title;
  final List<Widget>? actions;

  /// Overrides the automatic back button.
  final Widget? leading;

  /// Whether to synthesise a back button when the route can pop and [leading]
  /// is null. Matches `AppBar.automaticallyImplyLeading`.
  final bool automaticallyImplyLeading;

  static const double _toolbarHeight = 44;

  @override
  Size get preferredSize => const Size.fromHeight(_toolbarHeight);

  /// Glass is translucent by definition — content scrolling underneath is
  /// meant to show through, so the bar never fully obstructs it.
  @override
  bool shouldFullyObstruct(BuildContext context) => false;

  @override
  Widget build(BuildContext context) {
    return GlassAppBar(
      // The Material AppBarTheme this replaces was left-aligned; GlassAppBar
      // centres by default, which would silently re-lay-out all 30 screens.
      centerTitle: false,
      toolbarHeight: _toolbarHeight,
      leading: leading ?? _maybeBackButton(context),
      actions: actions,
      title: DefaultTextStyle.merge(
        style: const TextStyle(
          color: AppColors.charcoal,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          // Stated rather than inherited: this bar can end up without a
          // Material ancestor, and Flutter's fallback text style paints a
          // yellow double underline when that happens. The tab bar hit
          // exactly that — see ResponsiveScaffold._labelStyle.
          decoration: TextDecoration.none,
        ),
        child: title,
      ),
    );
  }

  Widget? _maybeBackButton(BuildContext context) {
    if (!automaticallyImplyLeading) return null;
    if (!(ModalRoute.of(context)?.canPop ?? false)) return null;

    // The Tooltip is not decoration: it carries the same 'Back' label
    // Material's BackButton gets from MaterialLocalizations, which is what
    // screen readers announce — and what `WidgetTester.pageBack()` looks for.
    return Tooltip(
      message: MaterialLocalizations.of(context).backButtonTooltip,
      child: GlassButton(
        icon: const Icon(CupertinoIcons.back, size: 22),
        iconColor: AppColors.charcoal,
        onTap: () => Navigator.maybePop(context),
        width: 40,
        height: 40,
        label: MaterialLocalizations.of(context).backButtonTooltip,
      ),
    );
  }
}
