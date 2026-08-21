import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Asks the user to confirm something irreversible.
///
/// Returns true only on an explicit confirm — dismissing the dialog any other
/// way returns false, so a caller can't read "no answer" as consent.
///
/// Extracted because the four add/edit screens each carried a byte-identical
/// `showDialog` + `AlertDialog` + two `TextButton`s block, differing only in
/// the noun. [GlassDialog] marks the destructive action itself
/// (`isDestructive`), which the Material version had no way to express — both
/// buttons were plain TextButtons and Delete looked exactly like Cancel.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  String cancelLabel = 'Cancel',
}) async {
  final result = await GlassDialog.show<bool>(
    context: context,
    title: title,
    message: message,
    barrierDismissible: true,
    actions: [
      GlassDialogAction(
        label: cancelLabel,
        onPressed: () => Navigator.pop(context, false),
      ),
      GlassDialogAction(
        label: confirmLabel,
        isDestructive: true,
        onPressed: () => Navigator.pop(context, true),
      ),
    ],
  );
  return result ?? false;
}
