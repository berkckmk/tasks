import 'package:flutter/material.dart';

/// Nocturne's type ramp: **30 / 26 / 19 / 16 / 15 / 13 / 12 / 11**.
///
/// The app it replaces set nearly everything at 13–15px in one grey, so
/// hierarchy had to be carried by weight alone. Here it is carried by size and
/// space, and **headings are never bolder than 500** — that is the rule that
/// makes the ramp legible rather than shouty.
///
/// Two things are load-bearing rather than cosmetic:
///
///  - **Tabular numerals** on every time, count and fraction. The time column
///    in the rail is a fixed 34–42px and misaligns without them.
///  - **`decoration: TextDecoration.none`** wherever text can end up without a
///    Material ancestor. Flutter's `DefaultTextStyle.fallback()` paints a
///    yellow double underline as a "no style ancestor" hint, and the tab bar
///    shipped with exactly that.
class AppType {
  AppType._();

  static const String family = 'Inter';

  /// Applied to every numeric run. Not optional — see the class doc.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  // -- Display -----------------------------------------------------------
  // 36–44 / 500. `2c`'s Now hero and Reminders, `2c`'s Profile name.

  static const TextStyle display = TextStyle(
    fontFamily: family,
    fontSize: 44,
    fontWeight: FontWeight.w500,
    height: 1.05,
    letterSpacing: -0.015 * 44,
    decoration: TextDecoration.none,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: family,
    fontSize: 36,
    fontWeight: FontWeight.w500,
    height: 1.1,
    letterSpacing: -0.015 * 36,
    decoration: TextDecoration.none,
  );

  // -- Headings ----------------------------------------------------------

  /// Screen title. `2b` Today, `2b` Reminders.
  static const TextStyle h2 = TextStyle(
    fontFamily: family,
    fontSize: 30,
    fontWeight: FontWeight.w500,
    height: 1.15,
    letterSpacing: -0.015 * 30,
    decoration: TextDecoration.none,
  );

  /// The group numeral on `2b` Reminders, and `2c`'s three counts.
  static const TextStyle numeral = TextStyle(
    fontFamily: family,
    fontSize: 34,
    fontWeight: FontWeight.w500,
    height: 1.0,
    letterSpacing: -0.015 * 34,
    fontFeatures: tabular,
    decoration: TextDecoration.none,
  );

  /// Section title. `2a` Today / Reminders / Profile.
  static const TextStyle h3 = TextStyle(
    fontFamily: family,
    fontSize: 25,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: -0.015 * 25,
    decoration: TextDecoration.none,
  );

  /// The progress fraction — "5 / 12".
  static const TextStyle h4 = TextStyle(
    fontFamily: family,
    fontSize: 26,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: -0.015 * 26,
    fontFeatures: tabular,
    decoration: TextDecoration.none,
  );

  /// The large list title — `2c`'s reminder rows.
  static const TextStyle h5 = TextStyle(
    fontFamily: family,
    fontSize: 19,
    fontWeight: FontWeight.w500,
    height: 1.25,
    letterSpacing: -0.015 * 19,
    decoration: TextDecoration.none,
  );

  // -- Body --------------------------------------------------------------

  /// A list row's title. 15/400–500.
  static const TextStyle title = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.3,
    decoration: TextDecoration.none,
  );

  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
    decoration: TextDecoration.none,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    decoration: TextDecoration.none,
  );

  /// The **note**: a reminder's `message`, a task's `description`. The whole
  /// redesign is framed around surfacing these two fields, so they get a
  /// named style rather than an inline `TextStyle(fontSize: 12.5)`.
  static const TextStyle note = TextStyle(
    fontFamily: family,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.5,
    decoration: TextDecoration.none,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
    decoration: TextDecoration.none,
  );

  /// Times, counts and fractions.
  static const TextStyle meta = TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.2,
    fontFeatures: tabular,
    decoration: TextDecoration.none,
  );

  static const TextStyle metaSmall = TextStyle(
    fontFamily: family,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.2,
    fontFeatures: tabular,
    decoration: TextDecoration.none,
  );

  /// Section label. 9–11 / 500, uppercase, +0.10–0.13em.
  static const TextStyle kicker = TextStyle(
    fontFamily: family,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0.10 * 11,
    decoration: TextDecoration.none,
  );

  static const TextStyle kickerSmall = TextStyle(
    fontFamily: family,
    fontSize: 9,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0.13 * 9,
    decoration: TextDecoration.none,
  );

  /// Bottom-bar label.
  static const TextStyle tabLabel = TextStyle(
    fontFamily: family,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 1.2,
    decoration: TextDecoration.none,
  );
}
