import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class SteadyProgressApp extends ConsumerWidget {
  const SteadyProgressApp({super.key, this.firebaseInitError});

  final Object? firebaseInitError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (firebaseInitError != null) {
      return MaterialApp(
        title: 'Steady Progress',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: _FirebaseInitErrorScreen(error: firebaseInitError!),
      );
    }

    return MaterialApp.router(
      title: 'Steady Progress',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

/// Shown instead of the app when Firebase fails to initialize — most likely
/// because `lib/firebase_options.dart` still has placeholder values. Run
/// `flutterfire configure` to fix this (see the project setup notes).
class _FirebaseInitErrorScreen extends StatelessWidget {
  const _FirebaseInitErrorScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              const Text(
                "Couldn't connect to Firebase",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.charcoal),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'This usually means lib/firebase_options.dart still has placeholder '
                'values. Run `flutterfire configure` from the project root, then '
                'restart the app.',
                style: TextStyle(color: AppColors.subtleText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                error.toString(),
                style: const TextStyle(fontSize: 11, color: AppColors.subtleText),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
