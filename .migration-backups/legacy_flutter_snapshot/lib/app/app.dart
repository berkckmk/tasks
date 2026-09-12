import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_icons.dart';
import '../core/constants/app_spacing.dart';
import '../core/widgets/app_viewport.dart';
import 'router/app_router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'theme/app_type.dart';

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
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        builder: (context, child) => AppViewport(child: child!),
        home: _FirebaseInitErrorScreen(error: firebaseInitError!),
      );
    }

    return MaterialApp.router(
      title: 'Steady Progress',
      debugShowCheckedModeBanner: false,
      // Dark-first. Nocturne is designed on the dark ground and the light
      // theme is its counterpart, not the other way round — so `themeMode` is
      // pinned to dark rather than following the OS. Both themes are supplied
      // because the light one is complete and correct (see AppColorsScheme);
      // flipping this to ThemeMode.system is a one-line change once there is
      // a setting for it.
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      builder: (context, child) => AppViewport(child: child!),
      // The glass backdrop that used to be installed here is gone. Nocturne
      // has nothing to refract: every Scaffold paints an opaque `bg` ground
      // of its own, which is what lets a 1px hairline read as an edge rather
      // than as ink on a pane.
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
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                AppIcons.warningCircle,
                size: 40,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                "Couldn't connect to Firebase",
                style: AppType.h5.copyWith(color: AppColors.charcoal),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This usually means lib/firebase_options.dart still has placeholder '
                'values. Run `flutterfire configure` from the project root, then '
                'restart the app.',
                style: AppType.bodySmall.copyWith(color: AppColors.subtleText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                error.toString(),
                style: AppType.metaSmall.copyWith(
                  color: AppColors.textCaption,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
