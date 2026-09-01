import 'package:flutter/widgets.dart';

/// The app's icon set: **Phosphor**, Regular and Fill.
///
/// Material Icons are gone. The two sets have different stroke weights and
/// optical sizes, and a screen carrying both reads as two designs — which is
/// exactly what the old app looked like once Cupertino's back chevron was
/// mixed in beside Material's outlined glyphs.
///
/// The convention is one line: **Regular for inactive and normal, Fill for
/// selected and completed.** Nothing in the design uses Thin, Light, Bold or
/// Duotone, so only those two faces are bundled.
///
/// ## Why the fonts are vendored rather than the package used
///
/// The handoff offers the choice ("add the `phosphor_flutter` package **or
/// vendor the SVGs**") and the package is not currently an option:
/// `phosphor_flutter` 2.1.0 — the latest release — declares
/// `class PhosphorIconData extends IconData`, and `IconData` became a `final`
/// class in Flutter. The package does not compile against this SDK:
///
///     Error: The class 'IconData' can't be extended outside of its library
///     because it's a final class.
///
/// (Worth knowing: `flutter analyze` does **not** surface this — it only
/// appears when the package is actually compiled, i.e. `flutter test` or
/// `flutter build`.)
///
/// So `assets/fonts/Phosphor-Regular.ttf` and `Phosphor-Fill.ttf` are
/// vendored from the same upstream (Phosphor is MIT), declared as ordinary
/// font families in `pubspec.yaml`, and addressed with plain `IconData`
/// constants below. Same glyphs, same codepoints, no dependency that can
/// break on an SDK bump.
///
/// The codepoints are Phosphor's own and are **shared across weights** — only
/// the family differs between Regular and Fill. Everything the redesign names
/// is listed here rather than reached for ad hoc, so the set stays a closed
/// list: an icon that isn't in the handoff shouldn't quietly appear on a
/// screen.
class AppIcons {
  AppIcons._();

  static const String _regular = 'PhosphorRegular';
  static const String _fill = 'PhosphorFill';

  // -- Navigation --------------------------------------------------------
  static const IconData bell = IconData(0xe0ce, fontFamily: _regular);
  static const IconData bellFill = IconData(0xe0ce, fontFamily: _fill);
  static const IconData sunHorizon = IconData(0xe5b6, fontFamily: _regular);
  static const IconData sunHorizonFill = IconData(0xe5b6, fontFamily: _fill);
  static const IconData checkSquareOffset =
      IconData(0xe188, fontFamily: _regular);
  static const IconData checkSquareOffsetFill =
      IconData(0xe188, fontFamily: _fill);
  static const IconData dotsThreeCircle =
      IconData(0xe200, fontFamily: _regular);
  static const IconData dotsThreeCircleFill =
      IconData(0xe200, fontFamily: _fill);

  // -- Reminders ---------------------------------------------------------
  static const IconData bellRinging = IconData(0xe5e8, fontFamily: _regular);
  static const IconData bellSimpleSlash =
      IconData(0xe0d2, fontFamily: _regular);
  static const IconData clockClockwise = IconData(0xe19e, fontFamily: _regular);
  static const IconData warningCircle = IconData(0xe4e2, fontFamily: _regular);

  // -- The checkable row -------------------------------------------------
  // One interaction shared by the app and the home-screen widget, so the two
  // read as the same product. Unchecked is the hollow `circle`; checked is
  // `check-circle` **Fill**.
  static const IconData circle = IconData(0xe18a, fontFamily: _regular);
  static const IconData checkCircleFill = IconData(0xe184, fontFamily: _fill);
  static const IconData check = IconData(0xe182, fontFamily: _regular);

  // -- Habits ------------------------------------------------------------
  static const IconData plant = IconData(0xebae, fontFamily: _regular);
  static const IconData plantFill = IconData(0xebae, fontFamily: _fill);

  // -- Chrome ------------------------------------------------------------
  static const IconData plus = IconData(0xe3d4, fontFamily: _regular);
  static const IconData caretDown = IconData(0xe136, fontFamily: _regular);
  static const IconData caretUp = IconData(0xe13c, fontFamily: _regular);
  static const IconData caretRight = IconData(0xe13a, fontFamily: _regular);
  static const IconData arrowLeft = IconData(0xe058, fontFamily: _regular);
  static const IconData x = IconData(0xe4f6, fontFamily: _regular);
  static const IconData magnifyingGlass =
      IconData(0xe30c, fontFamily: _regular);
  static const IconData microphone = IconData(0xe326, fontFamily: _regular);
  static const IconData trash = IconData(0xe4a6, fontFamily: _regular);

  // -- Task and goal metadata --------------------------------------------
  static const IconData calendarBlank = IconData(0xe10a, fontFamily: _regular);
  static const IconData flag = IconData(0xe244, fontFamily: _regular);
  static const IconData flagFill = IconData(0xe244, fontFamily: _fill);
  static const IconData target = IconData(0xe47c, fontFamily: _regular);

  // -- Profile, integrations, modules ------------------------------------
  static const IconData googleLogo = IconData(0xe292, fontFamily: _regular);
  static const IconData fileText = IconData(0xe23a, fontFamily: _regular);
  static const IconData downloadSimple =
      IconData(0xe20c, fontFamily: _regular);
  static const IconData signOut = IconData(0xe42a, fontFamily: _regular);
  static const IconData sparkle = IconData(0xe6a2, fontFamily: _regular);
  static const IconData sparkleFill = IconData(0xe6a2, fontFamily: _fill);
  static const IconData moon = IconData(0xe330, fontFamily: _regular);
  static const IconData userCircle = IconData(0xe4c4, fontFamily: _regular);
  static const IconData pencilSimple = IconData(0xe3b4, fontFamily: _regular);
  static const IconData lockSimple = IconData(0xe308, fontFamily: _regular);
  static const IconData chartLine = IconData(0xe154, fontFamily: _regular);
  static const IconData wallet = IconData(0xe68a, fontFamily: _regular);
  static const IconData barbell = IconData(0xe0b6, fontFamily: _regular);
  static const IconData bookOpen = IconData(0xe0e6, fontFamily: _regular);
  static const IconData notePencil = IconData(0xe34c, fontFamily: _regular);
  static const IconData slidersHorizontal =
      IconData(0xe434, fontFamily: _regular);

  /// `bug_report` in the old Material set.
  static const IconData bug = IconData(0xe5f4, fontFamily: _regular);

  // -- Beyond the handoff's named list ------------------------------------
  //
  // The mocks cover Reminders, Today, Tasks and Profile, so the handoff names
  // only the glyphs those four screens use. The rest of the app — analytics,
  // goals, pricing, the Complete-plan modules, auth, onboarding — still had
  // ~70 Material Icons, and "Phosphor replaces Material Icons throughout"
  // means those too: a screen that mixes the two sets is the exact failure
  // the rule exists to prevent.
  //
  // These are the Phosphor equivalents of what those screens were reaching
  // for. Same set, same weights, same conventions.
  static const IconData star = IconData(0xe46a, fontFamily: _regular);
  static const IconData starFill = IconData(0xe46a, fontFamily: _fill);
  static const IconData arrowSquareOut = IconData(0xe5de, fontFamily: _regular);
  static const IconData eye = IconData(0xe220, fontFamily: _regular);
  static const IconData eyeSlash = IconData(0xe224, fontFamily: _regular);
  static const IconData trendUp = IconData(0xe4ae, fontFamily: _regular);
  static const IconData trendDown = IconData(0xe4ac, fontFamily: _regular);
  static const IconData table = IconData(0xe476, fontFamily: _regular);
  static const IconData clock = IconData(0xe19a, fontFamily: _regular);
  static const IconData receipt = IconData(0xe3ec, fontFamily: _regular);
  static const IconData globe = IconData(0xe288, fontFamily: _regular);
  static const IconData listPlus = IconData(0xe2f8, fontFamily: _regular);
  static const IconData percent = IconData(0xe3b6, fontFamily: _regular);
  static const IconData envelopeSimple =
      IconData(0xe218, fontFamily: _regular);
  static const IconData flame = IconData(0xe624, fontFamily: _regular);
  static const IconData folder = IconData(0xe24a, fontFamily: _regular);
  static const IconData trophy = IconData(0xe67e, fontFamily: _regular);
  static const IconData arrowUp = IconData(0xe08e, fontFamily: _regular);
  static const IconData arrowDown = IconData(0xe03e, fontFamily: _regular);
  static const IconData alarm = IconData(0xe006, fontFamily: _regular);
  static const IconData plusCircle = IconData(0xe3d6, fontFamily: _regular);
  static const IconData checkCircle = IconData(0xe184, fontFamily: _regular);
  static const IconData squaresFour = IconData(0xe464, fontFamily: _regular);
}
