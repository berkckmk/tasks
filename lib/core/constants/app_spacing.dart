/// Nocturne's spacing and radius scale.
///
/// The step values are the old 4/8/16/24/32/48 scale at **density 0.70×**. The
/// old scale was tuned for a card-and-shadow layout with a lot of air; this
/// system carries hierarchy in type size and rules instead, and at the old
/// density the rules end up further from the text they belong to than from the
/// text they separate it from.
///
/// The names are unchanged so the ~200 existing `AppSpacing.md` references
/// re-tune rather than get rewritten.
class AppSpacing {
  AppSpacing._();

  static const double xs = 2.8;
  static const double sm = 5.6;
  static const double md = 11.2;
  static const double lg = 16.8;
  static const double xl = 22.4;
  static const double xxl = 33.6;

  /// Screen horizontal padding in every mock is the `lg` step.
  static const double screenH = lg;

  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 14;

  /// Deliberate exceptions to the radius scale, all in the home-screen widget
  /// and its setup screen. Named rather than inlined so they read as choices
  /// rather than as drift.
  static const double radiusWidgetPanel = 22;
  static const double radiusWidgetPicker = 16;
  static const double radiusScopeChip = 10;

  /// A pill. Used by `2c`'s buttons and by the widget's "Remind me" outline.
  static const double radiusPill = 999;
}
