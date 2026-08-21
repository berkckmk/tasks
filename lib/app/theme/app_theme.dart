import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.deepGreen,
      brightness: Brightness.light,
      primary: AppColors.deepGreen,
      onPrimary: Colors.white,
      secondary: AppColors.mutedBlue,
      onSecondary: Colors.white,
      tertiary: AppColors.amber,
      onTertiary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.charcoal,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // Transparent, not cream: AppBackdrop is painted once by
      // ResponsiveScaffold and every feature Scaffold stacks on top of it.
      // An opaque colour here would cover it and there would be nothing left
      // for the glass to refract.
      scaffoldBackgroundColor: Colors.transparent,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        // See scaffoldBackgroundColor. Screens still using a Material AppBar
        // render as a transparent band over the backdrop rather than an
        // opaque cream one; they move to GlassAppBar screen by screen.
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.charcoal,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.charcoal,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.charcoal,
        ),
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.charcoal,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.charcoal,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.charcoal,
        ),
        titleSmall: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.charcoal,
        ),
        bodyLarge: TextStyle(color: AppColors.charcoal),
        bodyMedium: TextStyle(color: AppColors.charcoal),
        bodySmall: TextStyle(color: AppColors.subtleText),
        labelLarge: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.charcoal,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.glassDivider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.deepGreen, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.subtleText),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.deepGreen,
      ),
      // Styled here rather than migrated to GlassToast, deliberately.
      //
      // Of the ~35 snackbar call sites, roughly half capture the messenger
      // *before* an await (`final messenger = ScaffoldMessenger.of(context)`)
      // precisely so they can still report an error once the async gap has
      // closed and the widget may be gone. GlassToast.show() needs a live
      // BuildContext to reach an Overlay, so moving those would trade a
      // working error message for a possible crash on a dead context.
      // ScaffoldMessenger already solves that problem; this only changes how
      // its result looks.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.charcoal.withValues(alpha: 0.86),
        contentTextStyle: const TextStyle(color: Colors.white),
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
    );
  }
}
