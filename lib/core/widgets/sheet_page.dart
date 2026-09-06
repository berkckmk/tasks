import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../constants/app_spacing.dart';

/// Presents a *route* as a sheet over the dimmed screen behind it.
///
/// `2b` composes New task as a sheet over the rail rather than as a pushed
/// full-screen form, but `/tasks/new` and `/tasks/:id/edit` are real routes —
/// they are deep-linkable and the app already navigates to them from four
/// places. Turning them into `showModalBottomSheet` calls would mean deleting
/// the routes and rewriting every caller.
///
/// So the route stays a route and only its *presentation* changes: a
/// non-opaque page whose barrier is the app's own scrim and whose child is
/// bottom-anchored. Back, deep links and `context.pop()` all behave exactly as
/// they did.
Page<T> sheetPage<T>(GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    // The whole point: the rail behind stays on screen and stays dimmed.
    opaque: false,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      );
    },
  );
}

/// The panel a [sheetPage] route draws itself in.
///
/// Bottom-anchored, `surface`, `radius-lg` on the top corners only, one
/// hairline edge and `shadow-lg`. Tapping outside it pops the route, which is
/// what makes the non-opaque page behave like a sheet rather than like a
/// transparent screen.
class SheetPanel extends StatelessWidget {
  const SheetPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // The IME is the platform's; this only makes room for it.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.maybePop(context),
            ),
          ),
          SafeArea(
            bottom: false,
            minimum: const EdgeInsets.only(top: AppSpacing.sm),
            child: Padding(
              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
              child: LayoutBuilder(
                builder: (context, constraints) => Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight,
                      maxWidth: 560,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppSpacing.radiusLg),
                        ),
                        border: Border.all(color: c.edgeLg),
                        boxShadow: c.shadowLg,
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppSpacing.radiusLg),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: MediaQuery.removeViewInsets(
                            context: context,
                            removeBottom: true,
                            child: SafeArea(top: false, child: child),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
