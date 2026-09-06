import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../constants/app_spacing.dart';

/// The app's modal bottom sheet.
///
/// `2b` composes New task as a sheet over the dimmed rail rather than as a
/// pushed screen, and the five Complete-plan module sheets already worked this
/// way — so all six now come through here instead of each restating the same
/// options.
///
/// A flat `surface` panel with a `radius-lg` top, one hairline edge, and a
/// grab handle. The scrim is deliberately heavy (62%): the rail behind it is
/// full of thin accent lines and small text, and at a lighter scrim they read
/// *through* the sheet rather than behind it.
///
/// `isScrollControlled` and the viewInsets padding are what let a sheet
/// containing a `TextField` rise above the platform IME. The app draws no
/// keyboard of its own — the system keyboard is the IME and follows the
/// device theme.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,

  /// Fraction of the screen the sheet opens at. The module sheets want most
  /// of the screen; the task composer sizes to its content.
  double? initialSize,
  bool isDismissible = true,
}) {
  assert(initialSize == null || (initialSize > 0 && initialSize <= 1));
  final c = AppColorsScheme.of(context);

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    backgroundColor: c.surface,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    elevation: 0,
    useSafeArea: true,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusLg),
      ),
      side: BorderSide(color: c.edgeMd),
    ),
    builder: (context) {
      return Padding(
        // Own keyboard avoidance here, before computing the sheet height.
        // Descendants receive consumed insets and must not reserve it again.
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) => ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight: constraints.maxHeight * (initialSize ?? 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _GrabHandle(),
                    Flexible(child: builder(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// A 32×3 rule at the top of the sheet.
///
/// Not decoration — the sheet has no other edge cue that it is draggable, and
/// an opaque panel with a hairline reads as a pushed screen without it.
class _GrabHandle extends StatelessWidget {
  const _GrabHandle();

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Container(
        width: 32,
        height: 3,
        decoration: BoxDecoration(
          color: c.text.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
