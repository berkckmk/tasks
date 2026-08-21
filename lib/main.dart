import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app/app.dart';
import 'app/theme/app_glass_theme.dart';
import 'core/google/google_auth_config.dart';
import 'firebase_options.dart';

/// Must be a top-level function — the OS calls this in a separate isolate
/// when a push arrives while the app is backgrounded or terminated. Keep it
/// minimal: there's no UI here, and it needs its own Firebase.initializeApp()
/// since it may run in a fresh isolate.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Background FCM message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-caches the glass shader programs. Async disk I/O only — no GPU draws,
  // no rasterization — so it doesn't hold up the first frame. Awaiting it
  // before runApp is what stops the first glass surface the user sees from
  // compiling its shader mid-frame.
  await LiquidGlassWidgets.initialize();

  Object? initError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    initError = e;
  }

  if (initError == null) {
    // Crashlytics doesn't support web — only route errors to it on
    // Android/iOS. Web errors still surface in the browser console as usual.
    if (!kIsWeb) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen((message) {
      // Foreground pushes don't show a system notification on their own;
      // this is the hook for an in-app banner if/when that's built. For now
      // just make sure the message actually arrives.
      debugPrint('Foreground FCM message: ${message.notification?.title}');
    });
  }

  // Must be called exactly once, before any other GoogleSignIn method.
  // Safe to attempt even with placeholder client IDs — this only configures
  // the SDK locally; it doesn't fail until an actual sign-in is attempted.
  try {
    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? GoogleAuthConfig.webClientId : null,
      // Must be null on web: google_sign_in_web asserts
      // `serverClientId == null`, so passing it made initialize() throw in
      // any build with asserts enabled (i.e. `flutter run -d chrome`) while
      // release web builds — where asserts are stripped — worked fine. The
      // catch below then swallowed it and every later GoogleSignIn call on
      // web failed with no obvious cause.
      serverClientId: kIsWeb ? null : GoogleAuthConfig.serverClientId,
    );
  } catch (e) {
    debugPrint(
      'GoogleSignIn.initialize failed (expected until configured): $e',
    );
  }

  runApp(
    LiquidGlassWidgets.wrap(
      theme: AppGlassTheme.data,
      // Required because the app uses MaterialApp: without this the glass
      // widgets read the OS brightness directly and ignore the app's own
      // ThemeMode, so a device in dark mode would render dark glass over a
      // light app.
      brightnessResolver: Theme.maybeBrightnessOf,
      child: ProviderScope(
        child: SteadyProgressApp(firebaseInitError: initError),
      ),
    ),
  );
}
