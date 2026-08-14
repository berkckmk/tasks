// File generated (normally) by the FlutterFire CLI, hand-written here as a
// PLACEHOLDER because this environment cannot run an interactive
// `firebase login` / `flutterfire configure` (both require a browser-based
// Google sign-in). The values below are NOT real credentials.
//
// Before running the app against a real backend:
//   1. Create a Firebase project (console.firebase.google.com), or run
//      `firebase projects:create` after `firebase login`.
//   2. From the project root, run:
//        dart pub global activate flutterfire_cli
//        flutterfire configure
//      Select the project, then the `android` and `web` platforms.
//   3. This will OVERWRITE this file with your real project's options and
//      drop `android/app/google-services.json` in place automatically.
//
// See the setup notes at the end of this phase's response for the full
// step-by-step. Do not hand-edit the generated file afterwards.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have only been configured for Android and '
          'Web in this project. Run `flutterfire configure` to add more '
          'platforms.',
        );
    }
  }

  // PLACEHOLDER — replace by running `flutterfire configure`.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'steady-progress-REPLACE',
    authDomain: 'steady-progress-REPLACE.firebaseapp.com',
    storageBucket: 'steady-progress-REPLACE.appspot.com',
  );

  // PLACEHOLDER — replace by running `flutterfire configure`.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'steady-progress-REPLACE',
    storageBucket: 'steady-progress-REPLACE.appspot.com',
  );
}
