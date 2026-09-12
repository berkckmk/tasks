// Web OAuth client from the "Web SDK configuration" panel of the Google
// sign-in provider (Firebase Console > Authentication > Sign-in method),
// tasks-1903 project. [serverClientId] reuses the same client for now
// (sign-in doesn't need a dedicated one); if the Calendar/Sheets/Drive/Docs
// server-side token exchange (functions/src/google/oauth.ts) ever needs a
// separate client, split them here and set functions/.env's
// GOOGLE_OAUTH_CLIENT_ID to match whichever one is used server-side — its
// client secret must only ever live in Cloud Functions config/Secret
// Manager, never in this app.
//
// Android's OAuth client is auto-linked via android/app/google-services.json
// (from `flutterfire configure`) using the app's debug/release SHA-1 —
// still pending, see the note where GoogleAuthConfig is used.
class GoogleAuthConfig {
  GoogleAuthConfig._();

  static const webClientId =
      '1012303591315-95nekgj63ffhc26sbrjrt3sm3i48pm0r.apps.googleusercontent.com';

  static const serverClientId =
      '1012303591315-95nekgj63ffhc26sbrjrt3sm3i48pm0r.apps.googleusercontent.com';
}
