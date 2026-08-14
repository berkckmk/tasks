import 'package:flutter/material.dart';

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
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
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
        displaySmall: TextStyle(fontWeight: FontWeight.w700, color: AppColors.charcoal),
        headlineSmall: TextStyle(fontWeight: FontWeight.w700, color: AppColors.charcoal),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: AppColors.charcoal),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: AppColors.charcoal),
        titleSmall: TextStyle(fontWeight: FontWeight.w600, color: AppColors.charcoal),
        bodyLarge: TextStyle(color: AppColors.charcoal),
        bodyMedium: TextStyle(color: AppColors.charcoal),
        bodySmall: TextStyle(color: AppColors.subtleText),
        labelLarge: TextStyle(fontWeight: FontWeight.w600, color: AppColors.charcoal),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.deepGreen.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.deepGreen : AppColors.subtleText,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.deepGreen : AppColors.subtleText,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        selectedIconTheme: const IconThemeData(color: AppColors.deepGreen),
        unselectedIconTheme: const IconThemeData(color: AppColors.subtleText),
        selectedLabelTextStyle: const TextStyle(
          color: AppColors.deepGreen,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: const TextStyle(color: AppColors.subtleText),
        indicatorColor: AppColors.deepGreen.withValues(alpha: 0.12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    );
  }
}
