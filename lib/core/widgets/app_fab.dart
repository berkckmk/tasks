import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../constants/app_icons.dart';
import '../constants/app_spacing.dart';

/// The "add" button in the corner of a list screen.
///
/// Outlined, like every primary control in Nocturne — an accent hairline on
/// the surface, never a filled accent disc. Goes in
/// `Scaffold.floatingActionButton` exactly where the Material
/// [FloatingActionButton] it replaces did, and registers no Hero, so the
/// `heroTag`s that once kept eight Material FABs from colliding stay gone.
///
/// `2b` pins a quick-capture bar above the tab bar on Today and Reminders
/// instead of showing this; the other list screens still use it.
class AppFab extends StatelessWidget {
  const AppFab({super.key, required this.onPressed, this.tooltip = 'Add'});

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final radius = BorderRadius.circular(AppSpacing.radiusLg);

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: radius,
            border: Border.all(color: c.accent),
            boxShadow: c.shadowMd,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: radius,
              splashColor: c.accentTint(0.14),
              highlightColor: c.accentTint(0.08),
              child: SizedBox(
                width: 52,
                height: 52,
                child: Icon(AppIcons.plus, size: 22, color: c.accent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
