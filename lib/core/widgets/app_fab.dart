import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app/theme/app_colors.dart';

/// The "add" button in the corner of every list screen.
///
/// Goes in `Scaffold.floatingActionButton` exactly where the Material
/// [FloatingActionButton] it replaces did. The old `heroTag`s are gone with
/// it: they existed only to keep the eight Material FABs from colliding in
/// the Hero tag namespace, and a [GlassButton] registers no Hero at all.
///
/// [GlassButton]'s defaults — 56x56, [LiquidOval] — are already the FAB
/// geometry, so this only supplies the icon and the brand glow.
class AppFab extends StatelessWidget {
  const AppFab({super.key, required this.onPressed, this.tooltip = 'Add'});

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GlassButton(
        onTap: onPressed,
        // Semantic only — GlassButton renders `icon`, not `label`.
        label: tooltip,
        style: GlassButtonStyle.prominent,
        glowColor: AppColors.deepGreen,
        icon: const Icon(Icons.add, size: 26, color: AppColors.deepGreen),
      ),
    );
  }
}
