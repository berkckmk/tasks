import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import 'app_colors.dart';
import 'app_type.dart';

/// The Nocturne theme, built once per brightness.
///
/// **Dark is the primary theme.** The app shipped light-only, and
/// `HANDOFF-CONTEXT.md` §5.3 flagged that turning dark mode on needed an audit
/// of the static `AppColors.*` references first. That audit is discharged
/// structurally rather than by hand: [AppColors]'s static members are now the
/// *dark* values, and everything written for the redesign resolves through
/// [AppColorsScheme.of], so a screen is correct in both brightnesses by
/// construction rather than by inspection.
///
/// Two rules from the design system are enforced here rather than left to call
/// sites, because they are the two that were being broken everywhere:
///
///  - **Primary buttons are outlined.** 1px accent border on transparent,
///    accent text. Never a solid accent fill. This inverts what the old
///    `FilledButton`/`AppButton(primary)` did.
///  - **Interactive states are themed, never platform defaults.** Hover and
///    pressed come from the accent ramp; focus is a 2px accent ring at 2px
///    offset; disabled drops to 45% opacity.
class AppTheme {
  AppTheme._();

  static ThemeData dark() => _build(AppColorsScheme.dark);

  static ThemeData light() => _build(AppColorsScheme.light);

  static ThemeData _build(AppColorsScheme c) {
    final isDark = c.isDark;

    final colorScheme = ColorScheme(
      brightness: c.brightness,
      primary: c.accent,
      onPrimary: isDark ? AppColors.neutral900 : AppColors.neutral100,
      secondary: c.inkAccent,
      onSecondary: isDark ? AppColors.neutral900 : AppColors.neutral100,
      tertiary: c.section,
      onTertiary: AppColors.neutral100,
      surface: c.surface,
      onSurface: c.text,
      surfaceContainerHighest: c.surface,
      onSurfaceVariant: c.note,
      outline: c.divider,
      outlineVariant: c.divider,
      error: AppColors.error,
      onError: AppColors.neutral900,
    );

    final textTheme = _textTheme(c);

    // Themed, never platform defaults. `accent-400` is the hover/pressed step
    // on the dark ground; a tint of the accent is the equivalent for the
    // outlined and ghost variants, which have no fill to lighten.
    final interactive = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return c.accentTint(0.18);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return c.accentTint(0.10);
      }
      return null;
    });

    final focusRing = BorderSide(color: c.accent, width: 2);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: colorScheme,
      fontFamily: AppType.family,
      // Opaque, not transparent. The Liquid Glass build left this transparent
      // so AppBackdrop could show through every Scaffold; Nocturne has no
      // backdrop to refract and an opaque ground is what makes the hairlines
      // read as edges rather than as ink floating on a pane.
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      dividerColor: c.divider,
      // InkSparkle is a Material 3 flourish that fights a flat system. The
      // ripple is kept (it is the only touch feedback a list row has) but
      // reduced to the plain one, tinted from the accent ramp.
      splashFactory: InkRipple.splashFactory,
      splashColor: c.accentTint(0.10),
      highlightColor: c.accentTint(0.06),
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.h5.copyWith(color: c.text),
        iconTheme: IconThemeData(color: c.text, size: 22),
      ),

      iconTheme: IconThemeData(color: c.text, size: 22),

      dividerTheme: DividerThemeData(
        color: c.divider,
        thickness: 1,
        space: 1,
      ),

      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: BorderSide(color: c.divider),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: inputBorder(c.divider),
        enabledBorder: inputBorder(c.divider),
        focusedBorder: inputBorder(c.accent, 2),
        errorBorder: inputBorder(AppColors.error),
        focusedErrorBorder: inputBorder(AppColors.error, 2),
        disabledBorder: inputBorder(c.divider.withValues(alpha: 0.45)),
        labelStyle: AppType.caption.copyWith(color: c.muted),
        floatingLabelStyle: AppType.metaSmall.copyWith(color: c.inkAccent),
        hintStyle: AppType.body.copyWith(color: c.inactive),
      ),

      // Outlined, never filled — the system's strongest rule.
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? c.accent.withValues(alpha: 0.45)
                : c.accent,
          ),
          overlayColor: interactive,
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? focusRing
                : BorderSide(
                    color: states.contains(WidgetState.disabled)
                        ? c.accent.withValues(alpha: 0.45)
                        : c.accent,
                  ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          ),
          textStyle: WidgetStatePropertyAll(AppType.title),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
          ),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? c.text.withValues(alpha: 0.45)
                : c.text,
          ),
          overlayColor: interactive,
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? focusRing
                : BorderSide(color: c.divider),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          ),
          textStyle: WidgetStatePropertyAll(AppType.title),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? c.inkAccent.withValues(alpha: 0.45)
                : c.inkAccent,
          ),
          overlayColor: interactive,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
          ),
          textStyle: WidgetStatePropertyAll(AppType.title),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.accent
              : c.text.withValues(alpha: 0.45),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.accentTint(0.24)
              : Colors.transparent,
        ),
        trackOutlineColor: WidgetStatePropertyAll(c.divider),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.accent
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(c.bg),
        side: BorderSide(color: c.unchecked),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.accent
              : c.unchecked,
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.divider,
        circularTrackColor: c.divider,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: c.muted,
        textColor: c.text,
        titleTextStyle: AppType.title.copyWith(color: c.text),
        subtitleTextStyle: AppType.note.copyWith(color: c.note),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: c.accentTint(),
        side: BorderSide(color: c.divider),
        labelStyle: AppType.meta.copyWith(color: c.text),
        secondaryLabelStyle: AppType.meta.copyWith(color: c.inkAccent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        showCheckmark: false,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: 0.62),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: c.edgeMd),
        ),
        titleTextStyle: AppType.h5.copyWith(color: c.text),
        contentTextStyle: AppType.body.copyWith(color: c.note),
      ),

      // Kept as a ScaffoldMessenger snackbar rather than moved to an overlay
      // toast, for the reason the old theme gave and which still holds: about
      // half of the ~35 call sites capture the messenger *before* an await so
      // they can still report an error once the widget may be gone.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surface,
        contentTextStyle: AppType.bodySmall.copyWith(color: c.text),
        actionTextColor: c.inkAccent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: BorderSide(color: c.edgeMd),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.surface,
        foregroundColor: c.accent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: c.accent),
        ),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        inactiveTrackColor: c.divider,
        thumbColor: c.accent,
        overlayColor: c.accentTint(0.14),
        trackHeight: 2,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: c.edgeMd),
        ),
        textStyle: AppType.metaSmall.copyWith(color: c.text),
      ),
    );
  }

  /// Maps Nocturne's ramp onto Material's slots.
  ///
  /// The mapping matters because a lot of the app still asks for
  /// `textTheme.titleSmall` and friends; wiring the ramp in here re-tokenises
  /// those call sites without touching them.
  static TextTheme _textTheme(AppColorsScheme c) {
    return TextTheme(
      displayLarge: AppType.display.copyWith(color: c.text),
      displayMedium: AppType.displaySmall.copyWith(color: c.text),
      displaySmall: AppType.h2.copyWith(color: c.text),
      headlineLarge: AppType.h2.copyWith(color: c.text),
      headlineMedium: AppType.h3.copyWith(color: c.text),
      headlineSmall: AppType.h3.copyWith(color: c.text),
      titleLarge: AppType.h5.copyWith(color: c.text),
      titleMedium: AppType.title.copyWith(color: c.text),
      // The section label above a group. Uppercased at the call site, not
      // here — Flutter has no text-transform.
      titleSmall: AppType.kicker.copyWith(color: c.inkAccent),
      bodyLarge: AppType.body.copyWith(color: c.text),
      bodyMedium: AppType.bodySmall.copyWith(color: c.text),
      bodySmall: AppType.note.copyWith(color: c.note),
      labelLarge: AppType.title.copyWith(color: c.text),
      labelMedium: AppType.meta.copyWith(color: c.muted),
      labelSmall: AppType.kickerSmall.copyWith(color: c.caption),
    );
  }
}
