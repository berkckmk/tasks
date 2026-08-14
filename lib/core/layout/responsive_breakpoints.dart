class ResponsiveBreakpoints {
  ResponsiveBreakpoints._();

  /// Below this width the app shows a bottom navigation bar (mobile/Android).
  /// At or above it, the app shows a side navigation rail (web/tablet/desktop).
  static const double sidebarBreakpoint = 840;

  static bool isWide(double width) => width >= sidebarBreakpoint;
}
