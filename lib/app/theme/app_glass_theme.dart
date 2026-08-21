import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app_colors.dart';

/// App-wide defaults for the Liquid Glass material, applied once in
/// `main.dart` via `LiquidGlassWidgets.wrap(theme: AppGlassTheme.data)`.
///
/// Values here are deliberately *partial* — [GlassThemeSettings] leaves every
/// omitted property at the widget's own default, so this only states what the
/// app actually wants to differ from the library's iOS 26 baseline.
///
/// These numbers are the Flutter half of a pair: the Android home-screen
/// widget draws the same material from Kotlin
/// (`android/.../widget/LiquidGlass.kt`), and the two are tuned to match. If
/// you change the thickness or blur here, compare the result against a placed
/// widget before settling on it.
class AppGlassTheme {
  AppGlassTheme._();

  /// The app's glass tint.
  ///
  /// **The alpha is the whole point.** `glassColor` is the colour the material
  /// itself is made of, not an accent applied on top of it — the library's own
  /// defaults sit around 12% (`rgba(210, 220, 240, 0.12)`). Passing an opaque
  /// colour does not tint the glass, it replaces it with a painted slab: the
  /// first version of this file passed [AppColors.deepGreen] neat, and every
  /// primary button rendered as a solid green rectangle with its label
  /// invisible on top of it.
  static final _tint = AppColors.deepGreen.withValues(alpha: 0.10);

  static final GlassThemeData data = GlassThemeData(
    light: GlassThemeVariant(
      settings: GlassThemeSettings(
        // The backdrop is a soft, low-contrast gradient rather than a photo,
        // so it needs less blur than the library default to stay legible as
        // a backdrop at all — blur it hard and every surface looks the same.
        blur: 7,
        // Near the library's own light default (12). The README example uses
        // 30, but that is written for a photographic wallpaper; over this
        // palette it reads as opaque.
        thickness: 14,
        glassColor: _tint,
        // Medium is the iOS 26 default. The app's surfaces are large and
        // mostly text, and a sharp highlight across a paragraph is a
        // readability problem, not a finish.
        specularSharpness: GlassSpecularSharpness.medium,
      ),
      quality: GlassQuality.standard,
    ),
    dark: GlassThemeVariant(
      settings: GlassThemeSettings(
        // Dark glass needs more of both to separate from the backdrop: the
        // luminance range behind it is narrower, so the material has to
        // supply more of the contrast itself.
        blur: 8,
        thickness: 16,
        glassColor: _tint,
        specularSharpness: GlassSpecularSharpness.medium,
      ),
      quality: GlassQuality.standard,
    ),
  );
}
