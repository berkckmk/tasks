import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color background = Color(0xFFF7F5F0);
  static const Color surface = Color(0xFFFBFAF7);
  static const Color charcoal = Color(0xFF2A2A28);
  static const Color subtleText = Color(0xFF6B6A63);
  static const Color divider = Color(0xFFE4E0D8);

  static const Color deepGreen = Color(0xFF2F5233);
  static const Color mutedBlue = Color(0xFF5C7A99);
  static const Color amber = Color(0xFFC98A3E);

  static const Color success = deepGreen;
  static const Color warning = amber;
  static const Color info = mutedBlue;
  static const Color error = Color(0xFFB3261E);

  // ---------------------------------------------------------------------
  // Glass surfaces
  //
  // The opaque tokens above stay exactly as they are — most of the app reads
  // them statically rather than through Theme.of(context), so changing them
  // would repaint everything at once. These are their translucent
  // counterparts, for anything painted *on* glass: a surface that lets the
  // backdrop through, and a divider that doesn't look like a drawn line on a
  // pane of glass.
  // ---------------------------------------------------------------------

  /// Fill for a panel sitting on the glass layer, where the material itself
  /// isn't doing the work (small pills, inner rows, chip backgrounds).
  static const Color glassSurface = Color(0x40FBFAF7);

  /// Hairline on glass. Much lighter than [divider]: at full opacity a rule
  /// reads as ink on the pane rather than an edge in it.
  static const Color glassDivider = Color(0x33E4E0D8);

  /// Text and icons over glass on a light backdrop.
  static const Color onGlass = charcoal;
  static const Color onGlassMuted = subtleText;
}
