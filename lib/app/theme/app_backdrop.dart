import 'package:flutter/material.dart';

import 'app_colors.dart';

/// What sits behind the glass.
///
/// Glass is defined by what it refracts, and the app's original background was
/// a single flat cream ([AppColors.background]) — blurring that produces the
/// same flat cream, so every glass surface read as a plain translucent panel.
/// This paints a low-contrast field with enough spatial variation for the
/// material to actually have something to bend.
///
/// Passed to `GlassScaffold(background:)`, so it sits under the whole app.
///
/// **Deliberately not animated.** `test/app_flow_test.dart` calls
/// `pumpAndSettle()` after every navigation; a continuously repeating
/// animation anywhere in the tree never settles and hangs the test rather
/// than failing it, which is a much worse thing to debug.
///
/// To swap in a photo later, replace the [DecoratedBox] stack below with an
/// `Image.asset(..., fit: BoxFit.cover)` — nothing else needs to change.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.charcoal : AppColors.background;

    return DecoratedBox(
      decoration: BoxDecoration(color: base),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Three offset radial pools, one per brand hue. Kept far below the
          // opacity where they'd read as "a colourful background" — the point
          // is gradient *structure* for the glass to refract, not decoration.
          _pool(
            alignment: const Alignment(-0.8, -0.9),
            color: AppColors.deepGreen,
            opacity: isDark ? 0.30 : 0.20,
            radius: 1.1,
          ),
          _pool(
            alignment: const Alignment(1.0, -0.2),
            color: AppColors.mutedBlue,
            opacity: isDark ? 0.28 : 0.18,
            radius: 1.0,
          ),
          _pool(
            alignment: const Alignment(-0.3, 1.0),
            color: AppColors.amber,
            opacity: isDark ? 0.24 : 0.15,
            radius: 1.2,
          ),
        ],
      ),
    );
  }

  Widget _pool({
    required Alignment alignment,
    required Color color,
    required double opacity,
    required double radius,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: alignment,
          radius: radius,
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
