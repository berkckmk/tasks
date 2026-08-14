import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Renders Google Identity Services' own Sign-In button. Required on web —
/// `GoogleSignIn.authenticate()` throws `UnimplementedError` there, so
/// there's no way to drive sign-in from our own button; the user must
/// interact with this one, and the result arrives via
/// `GoogleSignIn.authenticationEvents` (see auth_screen.dart).
Widget renderGoogleWebButton() {
  return web.renderButton(
    configuration: web.GSIButtonConfiguration(
      theme: web.GSIButtonTheme.outline,
      size: web.GSIButtonSize.large,
      shape: web.GSIButtonShape.pill,
      text: web.GSIButtonText.continueWith,
      logoAlignment: web.GSIButtonLogoAlignment.center,
      minimumWidth: 400,
    ),
  );
}
