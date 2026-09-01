import 'package:flutter/material.dart';

/// The **Nocturne** palette.
///
/// This replaces the cream/deep-green Liquid Glass palette wholesale. The
/// *field names* are deliberately unchanged — ~264 static `AppColors.charcoal`
/// style references exist across the app, and renaming them would turn a
/// re-tokenisation into a 264-site refactor. What each name now resolves to is
/// a Nocturne value, so every one of those call sites re-tokenises for free.
///
/// Three rules the system does not bend on:
///
///  1. **The accent is a line and a mark, never a flood.** [accent] draws
///     rules, rings, marks and selected states. It is never a filled
///     background behind body text — the one saturated flood in the whole
///     design is [section], used once.
///  2. **Never pure black or pure white.** Every value is a step on a ramp.
///     Shadow is the exception: ambient darkness mixed from black is a
///     shadow, not a colour.
///  3. **Accent at paragraph size is [inkAccent], not [accent].** `accent`
///     (#9184d9) does not meet contrast against [bg] at 12–15px; `inkAccent`
///     (accent-300) does. Using the wrong one is the most common way to fail
///     this palette.
///
/// Dark is the primary theme. [AppColorsScheme.of] resolves a whole set for
/// the current brightness; the static members below are the **dark** values,
/// because that is what the overwhelming majority of static references should
/// resolve to now that the app is dark-first.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------
  // Neutral ramp — surfaces, borders, disabled states.
  // ---------------------------------------------------------------------
  static const Color neutral100 = Color(0xFFF3F5FE);
  static const Color neutral200 = Color(0xFFE4E7F5);
  static const Color neutral300 = Color(0xFFCFD3E5);
  static const Color neutral400 = Color(0xFFB2B6CA);
  static const Color neutral500 = Color(0xFF9397AB);
  static const Color neutral600 = Color(0xFF75798C);
  static const Color neutral700 = Color(0xFF595D6C);
  static const Color neutral800 = Color(0xFF3F424D);
  static const Color neutral900 = Color(0xFF292B31);

  // ---------------------------------------------------------------------
  // Accent ramp.
  // ---------------------------------------------------------------------
  static const Color accent100 = Color(0xFFF5F4FF);
  static const Color accent200 = Color(0xFFE7E5FE);
  static const Color accent300 = Color(0xFFD2CEFD);
  static const Color accent400 = Color(0xFFB5ABFC);
  static const Color accent500 = Color(0xFF968AE0);
  static const Color accent600 = Color(0xFF796CBF);
  static const Color accent700 = Color(0xFF5D5294);
  static const Color accent800 = Color(0xFF423A6A);
  static const Color accent900 = Color(0xFF2B2741);

  // ---------------------------------------------------------------------
  // Dark theme — the primary theme, and what every static reference below
  // resolves to.
  // ---------------------------------------------------------------------

  /// App ground.
  static const Color background = Color(0xFF161826);

  /// Cards, panels, sheets, the widget panel.
  static const Color surface = Color(0xFF232532);

  /// Primary text. (Named `charcoal` from the old cream palette, where it was
  /// the darkest ink; on Nocturne it is the lightest. The role — "the colour
  /// body copy is set in" — is identical, which is why the name still fits.)
  static const Color charcoal = Color(0xFFE9E9ED);

  /// Supporting text. `charcoal` at 55%, the system's muted step.
  static const Color subtleText = Color(0x8CE9E9ED);

  /// Hairlines, row rules, control borders.
  static const Color divider = Color(0x29E9E9ED);

  /// The single accent — lines, marks, selected states. **Not** for
  /// paragraph-size text; see [inkAccent].
  static const Color accent = Color(0xFF9184D9);

  /// The accent at paragraph size (accent-300). Meets contrast where [accent]
  /// does not.
  static const Color inkAccent = accent300;

  /// The one saturated flood in the system, used once.
  static const Color section = Color(0xFF262A60);

  // ---------------------------------------------------------------------
  // Muted steps.
  //
  // The mocks use specific alphas of `charcoal` and naming them is what stops
  // them drifting into "roughly 50-ish percent grey" at each call site.
  // ---------------------------------------------------------------------

  /// Reminder `message` and task `description` — the "notes" the redesign is
  /// built around.
  static Color get textNote => charcoal.withValues(alpha: 0.58);
  static Color get textMuted => charcoal.withValues(alpha: 0.50);

  /// Inactive tab icons and labels.
  static Color get textInactive => charcoal.withValues(alpha: 0.45);

  /// Captions and secondary meta.
  static Color get textCaption => charcoal.withValues(alpha: 0.42);
  static Color get textFaint => charcoal.withValues(alpha: 0.40);

  /// Chevrons.
  static Color get textChevron => charcoal.withValues(alpha: 0.35);

  /// An unchecked circle toggle.
  static Color get uncheckedCircle => charcoal.withValues(alpha: 0.32);

  // ---------------------------------------------------------------------
  // Semantic roles.
  //
  // Nocturne is a mono-accent system: the old green/blue/amber trio existed to
  // colour-code stat tiles and priority chips, and the redesign explicitly
  // removes those coloured chips. These now all resolve into the one accent
  // so that any call site still reaching for them cannot reintroduce a second
  // hue. `error` is the exception — a destructive action genuinely has to
  // read as different, and it is tuned to sit on the dark ground.
  // ---------------------------------------------------------------------
  static const Color deepGreen = accent;
  static const Color mutedBlue = accent500;
  static const Color amber = accent400;

  static const Color success = accent;
  static const Color warning = accent400;
  static const Color info = accent500;
  static const Color error = Color(0xFFE1798C);

  // ---------------------------------------------------------------------
  // Legacy glass tokens.
  //
  // Liquid Glass is gone — flat opaque panels replace it — but these four
  // names are still referenced from widgets that have not been rewritten.
  // They now resolve to their flat equivalents so nothing renders as a
  // translucent pane on an opaque ground.
  // ---------------------------------------------------------------------
  static const Color glassSurface = surface;
  static const Color glassDivider = divider;
  static const Color onGlass = charcoal;
  static Color get onGlassMuted => subtleText;

  // ---------------------------------------------------------------------
  // Elevation.
  //
  // On a dark ground elevation is *an edge plus ambient darkness*, never a
  // stack of shadows. `sm` is an edge only.
  // ---------------------------------------------------------------------
  static const Color edgeSm = neutral800;
  static const Color edgeMd = neutral700;
  static const Color edgeLg = neutral500;

  static const List<BoxShadow> shadowSm = [];
  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x8C000000), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> shadowLg = [
    BoxShadow(color: Color(0xA6000000), blurRadius: 40, offset: Offset(0, 16)),
  ];
}

/// Every Nocturne colour, resolved for one brightness.
///
/// The static members on [AppColors] are the dark values and cover the ~264
/// existing references. Anything written *for* the redesign reads its colours
/// from here instead, via `AppColorsScheme.of(context)`, so that light mode is
/// a real theme rather than a set of inverted one-offs.
///
/// This is the audit `HANDOFF-CONTEXT.md` §5.3 asks for, discharged
/// structurally: a screen that resolves through this class is correct in both
/// brightnesses by construction.
@immutable
class AppColorsScheme {
  const AppColorsScheme({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.text,
    required this.divider,
    required this.accent,
    required this.inkAccent,
    required this.section,
    required this.edgeSm,
    required this.edgeMd,
    required this.edgeLg,
    required this.shadowMd,
    required this.shadowLg,
  });

  final Brightness brightness;

  final Color bg;
  final Color surface;
  final Color text;
  final Color divider;
  final Color accent;
  final Color inkAccent;
  final Color section;

  final Color edgeSm;
  final Color edgeMd;
  final Color edgeLg;
  final List<BoxShadow> shadowMd;
  final List<BoxShadow> shadowLg;

  bool get isDark => brightness == Brightness.dark;

  // The named muted steps, resolved against this scheme's own `text`.
  Color get note => text.withValues(alpha: 0.58);
  Color get muted => text.withValues(alpha: 0.50);
  Color get inactive => text.withValues(alpha: 0.45);
  Color get caption => text.withValues(alpha: 0.42);
  Color get faint => text.withValues(alpha: 0.40);
  Color get chevron => text.withValues(alpha: 0.35);
  Color get unchecked => text.withValues(alpha: 0.32);

  /// A tint of the accent, for the ground of a selected chip or an avatar
  /// well. Never strong enough to read as a flood.
  Color accentTint([double alpha = 0.14]) =>
      accent.withValues(alpha: alpha);

  static const AppColorsScheme dark = AppColorsScheme(
    brightness: Brightness.dark,
    bg: Color(0xFF161826),
    surface: Color(0xFF232532),
    text: Color(0xFFE9E9ED),
    divider: Color(0x29E9E9ED),
    accent: AppColors.accent,
    inkAccent: AppColors.accent300,
    section: Color(0xFF262A60),
    edgeSm: AppColors.neutral800,
    edgeMd: AppColors.neutral700,
    edgeLg: AppColors.neutral500,
    shadowMd: [
      BoxShadow(color: Color(0x8C000000), blurRadius: 18, offset: Offset(0, 6)),
    ],
    shadowLg: [
      BoxShadow(color: Color(0xA6000000), blurRadius: 40, offset: Offset(0, 16)),
    ],
  );

  static const AppColorsScheme light = AppColorsScheme(
    brightness: Brightness.light,
    bg: AppColors.neutral200,
    surface: AppColors.neutral100,
    text: AppColors.neutral900,
    // rgba(41,43,49,0.14)
    divider: Color(0x24292B31),
    // Unchanged across themes — the accent is the brand.
    accent: AppColors.accent,
    inkAccent: AppColors.accent700,
    section: Color(0xFF3D4285),
    edgeSm: AppColors.neutral300,
    edgeMd: AppColors.neutral300,
    edgeLg: AppColors.neutral400,
    shadowMd: [
      BoxShadow(color: Color(0x1A292B31), blurRadius: 18, offset: Offset(0, 6)),
    ],
    shadowLg: [
      BoxShadow(color: Color(0x29292B31), blurRadius: 40, offset: Offset(0, 16)),
    ],
  );

  static AppColorsScheme forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static AppColorsScheme of(BuildContext context) =>
      forBrightness(Theme.of(context).brightness);
}
