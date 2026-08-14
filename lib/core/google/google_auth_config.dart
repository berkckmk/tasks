// PLACEHOLDER — replace with the real OAuth client IDs from the Google
// Cloud Console project behind your Firebase project (APIs & Services >
// Credentials), after:
//   1. Running `flutterfire configure` (see firebase_options.dart).
//   2. Enabling the Google sign-in provider in Firebase Console > Authentication.
//   3. Creating an OAuth 2.0 Client ID of type "Web application" for
//      [webClientId] (Google Cloud Console > Credentials > Create
//      Credentials > OAuth client ID). Add your web app's origin
//      (e.g. https://steadyprogress.app) under "Authorized JavaScript origins".
//   4. Android's OAuth client is normally auto-linked via
//      android/app/google-services.json (from flutterfire configure) using
//      your release/debug SHA-1 — no separate constant needed for it.
//   5. [serverClientId] is the "Web application" client ID used for the
//      *server-side* token exchange in Cloud Functions (see
//      functions/src/google/oauth.ts). It can be the same client ID as
//      [webClientId], or a dedicated one — either way, its **client secret**
//      must only ever live in Cloud Functions config/Secret Manager, never
//      in this app.
class GoogleAuthConfig {
  GoogleAuthConfig._();

  static const webClientId = 'REPLACE_WITH_WEB_OAUTH_CLIENT_ID.apps.googleusercontent.com';

  static const serverClientId = 'REPLACE_WITH_SERVER_OAUTH_CLIENT_ID.apps.googleusercontent.com';
}
