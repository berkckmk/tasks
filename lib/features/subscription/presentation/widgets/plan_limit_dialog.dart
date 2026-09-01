import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_type.dart';
import '../../../../core/constants/app_spacing.dart';

/// Shown instead of navigating to an add-habit/add-task screen once the
/// current plan's limit is reached.
///
/// The upgrade action reads as primary through the accent, not through a
/// fill — an accent-coloured label beside a muted one. `AlertDialog` lays its
/// own actions out in a row, and a full-width outlined button dropped into
/// that row fights the dialog's geometry, which is the same reason the glass
/// version used its own action type rather than an `AppButton`.
Future<void> showPlanLimitDialog(
  BuildContext context, {
  required String message,
  required String requiredPlanName,
}) {
  final c = AppColorsScheme.of(context);

  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (context) => AlertDialog(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: BorderSide(color: c.edgeMd),
      ),
      title: Text(
        "You've hit your plan limit",
        style: AppType.h5.copyWith(color: c.text),
      ),
      content: Text(message, style: AppType.bodySmall.copyWith(color: c.note)),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Not now', style: AppType.title.copyWith(color: c.muted)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            context.push('/pricing');
          },
          child: Text(
            'Upgrade to $requiredPlanName',
            style: AppType.title.copyWith(color: c.accent),
          ),
        ),
      ],
    ),
  );
}
