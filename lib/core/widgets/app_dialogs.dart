import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_type.dart';
import '../constants/app_spacing.dart';

/// Asks the user to confirm something irreversible.
///
/// Returns true only on an explicit confirm — dismissing the dialog any other
/// way returns false, so a caller can't read "no answer" as consent.
///
/// Extracted because the four add/edit screens each carried a byte-identical
/// `showDialog` + `AlertDialog` + two `TextButton`s block, differing only in
/// the noun.
///
/// The destructive action is marked as such — it is the one place in the app
/// where a colour other than the accent is allowed to carry meaning, because
/// "this deletes something" genuinely has to read as different from "cancel".
/// Both buttons looked identical in the Material version this replaced.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  String cancelLabel = 'Cancel',
}) async {
  final c = AppColorsScheme.of(context);

  final result = await showDialog<bool>(
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
      title: Text(title, style: AppType.h5.copyWith(color: c.text)),
      content: Text(message, style: AppType.bodySmall.copyWith(color: c.note)),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            cancelLabel,
            style: AppType.title.copyWith(color: c.muted),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmLabel,
            style: AppType.title.copyWith(color: AppColors.error),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
