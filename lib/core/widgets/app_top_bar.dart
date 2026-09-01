import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_type.dart';
import '../constants/app_icons.dart';
import '../constants/app_spacing.dart';
import 'nocturne.dart';

/// The app's top bar.
///
/// Flat and opaque: `bg`, no elevation, no tint, no blur. The Liquid Glass bar
/// this replaces was translucent by definition, which is why it needed the
/// `shouldFullyObstruct` contract and a scroll-under tint — an opaque bar
/// needs neither, and content scrolling behind it simply doesn't show.
///
/// The two Material behaviours the glass bar had to rebuild by hand — a
/// synthesised back button and a title style that survives having no Material
/// ancestor — are kept, because both are still load-bearing. The back button
/// is Phosphor's `arrow-left`, not Cupertino's chevron.
///
/// A screen title in this design is usually **in the body**, at `h2` (30px)
/// or `h3` (25px), not in this bar — the bar carries the back affordance and
/// the actions. Pass `title` only where a bar title is genuinely wanted; the
/// four tab roots draw their own.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  final Widget? title;
  final List<Widget>? actions;

  /// Overrides the automatic back button.
  final Widget? leading;

  /// Whether to synthesise a back button when the route can pop and [leading]
  /// is null. Matches `AppBar.automaticallyImplyLeading`.
  final bool automaticallyImplyLeading;

  static const double _toolbarHeight = 48;

  @override
  Size get preferredSize => const Size.fromHeight(_toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final lead = leading ?? _maybeBackButton(context);

    return Material(
      color: c.bg,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: _toolbarHeight,
          child: Padding(
            padding: EdgeInsets.only(
              left: lead == null ? AppSpacing.screenH : AppSpacing.sm,
              right: AppSpacing.sm,
            ),
            child: Row(
              children: [
                ?lead,
                if (title != null)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: lead == null ? 0 : AppSpacing.xs,
                      ),
                      child: DefaultTextStyle.merge(
                        style: AppType.h5.copyWith(color: c.text),
                        overflow: TextOverflow.ellipsis,
                        child: title!,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                ...?actions,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _maybeBackButton(BuildContext context) {
    if (!automaticallyImplyLeading) return null;
    if (!(ModalRoute.of(context)?.canPop ?? false)) return null;

    // The tooltip is not decoration: it carries the same 'Back' label
    // Material's BackButton gets from MaterialLocalizations, which is what
    // screen readers announce — and what `WidgetTester.pageBack()` looks for.
    final label = MaterialLocalizations.of(context).backButtonTooltip;
    return GhostIconButton(
      icon: AppIcons.arrowLeft,
      tooltip: label,
      size: 20,
      color: AppColorsScheme.of(context).text,
      onPressed: () => Navigator.maybePop(context),
    );
  }
}
