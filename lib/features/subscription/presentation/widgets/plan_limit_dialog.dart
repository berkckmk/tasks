import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';

/// Shown instead of navigating to an add-habit/add-task screen once the
/// current plan's limit is reached.
Future<void> showPlanLimitDialog(
  BuildContext context, {
  required String message,
  required String requiredPlanName,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.workspace_premium_outlined, color: AppColors.amber),
      title: const Text("You've hit your plan limit"),
      content: Text(message, style: const TextStyle(color: AppColors.subtleText)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now')),
        AppButton(
          label: 'Upgrade to $requiredPlanName',
          onPressed: () {
            Navigator.pop(context);
            context.push('/pricing');
          },
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
    ),
  );
}
