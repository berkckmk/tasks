import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_type.dart';
import '../constants/app_icons.dart';
import '../constants/app_spacing.dart';

/// Reused wherever an `AsyncValue.when(error: ...)` branch needs to show
/// something friendlier than a raw exception string — used across
/// habits/tasks/goals/profile/pricing.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error});

  final Object error;

  String get _message {
    if (error is FirebaseException) {
      final code = (error as FirebaseException).code;
      if (code == 'unavailable' || code == 'network-request-failed') {
        return "You're offline. Showing the latest saved data — changes will sync once you're back online.";
      }
      if (code == 'permission-denied') {
        return "You don't have permission to view this. Try signing out and back in.";
      }
    }
    if (error is FirebaseAuthException) {
      return (error as FirebaseAuthException).message ?? 'Something went wrong. Please try again.';
    }
    return 'Something went wrong loading this screen. Please try again in a moment.';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.warningCircle, size: 32, color: c.muted),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _message,
              textAlign: TextAlign.center,
              style: AppType.caption.copyWith(color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}
