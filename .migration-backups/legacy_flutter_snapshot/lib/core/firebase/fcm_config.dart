// PLACEHOLDER — from Firebase Console > Project Settings > Cloud Messaging >
// Web configuration > "Web Push certificates" (generate a key pair). Only
// needed on web; Android reads its config from google-services.json
// (via `flutterfire configure`) automatically.
class FcmConfig {
  FcmConfig._();

  static const webVapidKey = 'REPLACE_WITH_WEB_PUSH_VAPID_KEY';
}
