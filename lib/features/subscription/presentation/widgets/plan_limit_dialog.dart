import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Shown instead of navigating to an add-habit/add-task screen once the
/// current plan's limit is reached.
///
/// The upgrade action is marked `isPrimary` rather than being an AppButton
/// among TextButtons: GlassDialog lays its own actions out, and mixing a
/// full-width app button into that row fought the dialog's geometry.
Future<void> showPlanLimitDialog(
  BuildContext context, {
  required String message,
  required String requiredPlanName,
}) {
  return GlassDialog.show<void>(
    context: context,
    title: "You've hit your plan limit",
    message: message,
    barrierDismissible: true,
    actions: [
      GlassDialogAction(
        label: 'Not now',
        onPressed: () => Navigator.pop(context),
      ),
      GlassDialogAction(
        label: 'Upgrade to $requiredPlanName',
        isPrimary: true,
        onPressed: () {
          Navigator.pop(context);
          context.push('/pricing');
        },
      ),
    ],
  );
}
