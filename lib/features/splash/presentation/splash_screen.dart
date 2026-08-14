import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../auth/application/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decideNextScreen();
  }

  /// Waits for Firebase to resolve whether a session is already persisted
  /// (so a returning signed-in user skips straight to the dashboard instead
  /// of onboarding), with a small minimum splash time so the brand doesn't
  /// just flash by.
  Future<void> _decideNextScreen() async {
    final stopwatch = Stopwatch()..start();
    final user = await ref.read(authStateChangesProvider.future);

    final remaining = 900 - stopwatch.elapsedMilliseconds;
    if (remaining > 0) {
      await Future.delayed(Duration(milliseconds: remaining));
    }
    if (!mounted) return;

    context.go(user != null ? '/dashboard' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.spa_outlined, size: 48, color: AppColors.deepGreen),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Steady Progress',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Calm, steady progress on what matters.',
              style: TextStyle(color: AppColors.subtleText),
            ),
          ],
        ),
      ),
    );
  }
}
