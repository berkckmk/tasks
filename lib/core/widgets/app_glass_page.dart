import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app/theme/app_backdrop.dart';

/// Gives a full-screen route its own glass backdrop.
///
/// The six shell tabs don't need this — [ResponsiveScaffold] already paints
/// [AppBackdrop] behind them. Everything pushed onto the *root* navigator
/// (add/edit screens, pricing, the module screens, auth) renders over nothing,
/// so it brings its own.
///
/// ## Why this wraps a Scaffold instead of using GlassScaffold
///
/// `GlassScaffold` is the package's headline surface, but it wraps a
/// `CupertinoPageScaffold` and therefore has no `floatingActionButton` slot,
/// no `drawer`, and no `ScaffoldMessenger`. This app has 8 FABs and ~35
/// `ScaffoldMessenger.of(context).showSnackBar` call sites. `GlassPage` is the
/// package's own answer to exactly this — it supplies the background,
/// anti-ghosting and status-bar handling, forces the child Scaffold
/// transparent, and leaves the Material scaffolding intact.
class AppGlassPage extends StatelessWidget {
  const AppGlassPage({super.key, required this.child});

  /// Normally a [Scaffold] whose `appBar` is a [GlassAppBar].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      background: const AppBackdrop(),
      statusBarStyle: GlassStatusBarStyle.auto,
      child: child,
    );
  }
}
