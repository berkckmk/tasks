import 'package:flutter/widgets.dart';

import '../constants/app_spacing.dart';

/// Content padding for a screen's main scrollable.
///
/// The bottom value is the part that matters. `GlassScaffold` paints the tab
/// bar *over* the body and extends the body behind it — that overlap is the
/// point, it's what makes content show through the glass — but it means a
/// scrollable has to reserve the bar's height itself or its last item can
/// never be scrolled clear of it. That shipped: the third quick action on the
/// dashboard sat under the bar, unreachable, because a flat `AppSpacing.xxl`
/// (48) is smaller than the bar plus the gesture inset (~118).
///
/// [ResponsiveScaffold] publishes that reserve through `MediaQuery.padding`,
/// so reading it here keeps one source of truth: screens outside the shell
/// get only the real system inset, screens inside it get the bar as well,
/// and neither has to know which it is.
EdgeInsets scrollInsets(
  BuildContext context, {
  double horizontal = AppSpacing.md,
  double top = AppSpacing.md,
  double bottom = AppSpacing.xxl,
}) {
  return EdgeInsets.fromLTRB(
    horizontal,
    top,
    horizontal,
    bottom + MediaQuery.paddingOf(context).bottom,
  );
}
