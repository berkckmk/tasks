import 'package:flutter/material.dart';

/// Keeps every route, dialog and transition below the system status bar and
/// camera cutout. Insets are consumed here so nested SafeAreas do not add them
/// again. Bottom insets remain available to keyboards and navigation bars.
class AppViewport extends StatelessWidget {
  const AppViewport({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: ClipRect(child: child),
      ),
    );
  }
}
