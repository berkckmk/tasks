import 'package:flutter/widgets.dart';

import '../constants/app_spacing.dart';

/// Content padding for a screen's main scrollable.
///
/// This used to carry a large bottom reserve, because the Liquid Glass tab bar
/// was painted *over* the body and a scrollable had to make room for it or its
/// last item could never be scrolled clear — the dashboard's third quick
/// action shipped stuck underneath it.
///
/// The Nocturne bar is opaque and lives in the Scaffold's own
/// `bottomNavigationBar` slot, so the Scaffold lays the body out above it and
/// removes the consumed inset from the body's `MediaQuery`. Reading
/// `padding.bottom` here therefore now returns only whatever system inset is
/// genuinely left, which is exactly right — and is why this helper needed no
/// structural change, only smaller numbers and an honest comment.
///
/// The horizontal default is the `lg` step: **screen horizontal padding in
/// every mock is 16.8**.
EdgeInsets scrollInsets(
  BuildContext context, {
  double horizontal = AppSpacing.screenH,
  double top = AppSpacing.md,
  double bottom = AppSpacing.xl,
}) {
  return EdgeInsets.fromLTRB(
    horizontal,
    top,
    horizontal,
    bottom + MediaQuery.paddingOf(context).bottom,
  );
}
