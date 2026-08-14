import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thrown for any auth failure with a message already safe to show in the UI.
class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository(this._auth);

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Provider IDs currently linked to this account, e.g.
  /// `['password', 'google.com']` — read straight from Firebase Auth (which
  /// already tracks this), no separate bookkeeping needed to know the
  /// current truth. A denormalized copy is still written to the profile doc
  /// (see AuthActions) so it's queryable from Firestore if ever needed.
  List<String> get linkedProviderIds =>
      _auth.currentUser?.providerData.map((info) => info.providerId).toList() ?? [];

  /// Sends a verification email after creating the account — the anti-abuse
  /// measure for the email/password path (Google accounts arrive
  /// pre-verified, so this only ever applies here). Best-effort: a failure
  /// to *send* the email shouldn't undo an otherwise-successful signup, so
  /// it's swallowed rather than thrown; [needsEmailVerification] still
  /// gates the app shell on `emailVerified`, so the user isn't let in
  /// without one either way — see AuthActions.resendVerificationEmail for
  /// the retry path if sending genuinely failed.
  Future<User> signUpWithEmail({required String email, required String password}) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) throw AuthException('Sign up failed. Please try again.');
      try {
        await user.sendEmailVerification();
      } catch (_) {
        // Swallowed — see doc comment above.
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  /// True once a signed-in user still needs to click the link from
  /// [signUpWithEmail]'s verification email before using the app. Google
  /// sign-in accounts are verified by Google already, so this is only ever
  /// true for the email/password path.
  bool get needsEmailVerification {
    final user = _auth.currentUser;
    return user != null && !user.emailVerified;
  }

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        throw AuthException('Please wait a bit before requesting another email.');
      }
      throw AuthException(_messageFor(e));
    }
  }

  /// Refreshes the cached [User] from the server so a just-verified email
  /// is reflected in [needsEmailVerification] — `emailVerified` doesn't
  /// update on its own just because the user clicked the link in another
  /// tab.
  ///
  /// On the transition to verified, also force-refreshes the ID token
  /// (`getIdToken(true)`). `reload()` alone only updates the cached [User]
  /// object — firestore.rules checks `request.auth.token.email_verified`,
  /// which comes from the *token's* claims and won't pick up the change
  /// until the token itself is reissued. Without this, the very next
  /// Firestore write (the deferred profile bootstrap — see
  /// AuthActions.checkEmailVerified) would still be rejected as
  /// unverified even though the user just verified.
  Future<bool> reloadAndCheckEmailVerified() async {
    await _auth.currentUser?.reload();
    final user = _auth.currentUser;
    if (user == null) return false;
    if (user.emailVerified) {
      await user.getIdToken(true);
    }
    return user.emailVerified;
  }

  Future<User> signInWithEmail({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      if (user == null) throw AuthException('Sign in failed. Please try again.');
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  /// Signs in with Google. If an account with the same email already exists
  /// using a different provider (e.g. email/password), Firebase refuses the
  /// sign-in with `account-exists-with-different-credential` — we surface a
  /// clear message rather than silently failing or auto-merging accounts.
  ///
  /// Only works on Android/iOS — `GoogleSignIn.authenticate()` isn't
  /// supported on web (see [signInWithGoogleAccount] for the web path).
  Future<User> signInWithGoogle() async {
    final account = await _googleAccount();
    return signInWithGoogleAccount(account);
  }

  /// Completes Firebase sign-in for a [GoogleSignInAccount] already obtained
  /// some other way — specifically, the web flow, where Google Identity
  /// Services requires its own rendered button
  /// (`GoogleSignIn.authenticate()` throws `UnimplementedError` on web) and
  /// the resulting account arrives via `GoogleSignIn.authenticationEvents`
  /// instead of a direct return value. See google_web_sign_in_button.dart
  /// and its use in auth_screen.dart.
  Future<User> signInWithGoogleAccount(GoogleSignInAccount account) async {
    final credential = _credentialFromAccount(account);
    try {
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) throw AuthException('Google sign-in failed. Please try again.');
      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        throw AuthException(
          'An account already exists with this email. Sign in with your password, '
          'then connect Google from Settings.',
        );
      }
      throw AuthException(_messageFor(e));
    }
  }

  /// Links a Google account to the *currently signed-in* user (called from
  /// the Google Integrations settings screen) — this is how an
  /// email/password user adds Google sign-in without creating a second
  /// account.
  Future<User> linkGoogleToCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('You need to be signed in first.');

    final account = await _googleAccount();
    final credential = _credentialFromAccount(account);
    try {
      final result = await user.linkWithCredential(credential);
      return result.user ?? user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        throw AuthException(
          'This Google account is already linked to a different Steady Progress account.',
        );
      }
      if (e.code == 'provider-already-linked') {
        throw AuthException('Your account is already connected to Google.');
      }
      throw AuthException(_messageFor(e));
    }
  }

  /// Requests a one-time server auth code for [scopes] — used to grant a
  /// single Google integration (Calendar/Sheets/Drive/Docs) incrementally,
  /// separately from sign-in. The code is exchanged for tokens by a Cloud
  /// Function, never on-device (see GoogleIntegrationsActions.connect and
  /// functions/src/google/oauth.ts) — this method never sees or returns a
  /// long-lived access/refresh token itself.
  Future<String> requestServerAuthCode(List<String> scopes) async {
    try {
      final authorization =
          await GoogleSignIn.instance.authorizationClient.authorizeServer(scopes);
      final code = authorization?.serverAuthCode;
      if (code == null) {
        throw AuthException('Google did not grant access to that permission. Please try again.');
      }
      return code;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw AuthException('Permission request was canceled.');
      }
      throw AuthException('Google authorization failed: ${e.description ?? e.code}');
    }
  }

  Future<void> unlinkGoogle() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.unlink(GoogleAuthProvider.PROVIDER_ID);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
    await GoogleSignIn.instance.signOut();
  }

  /// Only works on Android/iOS — see [signInWithGoogleAccount] for why web
  /// can't use this.
  Future<GoogleSignInAccount> _googleAccount() async {
    try {
      return await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw AuthException('Google sign-in was canceled.');
      }
      throw AuthException('Google sign-in failed: ${e.description ?? e.code}');
    }
  }

  AuthCredential _credentialFromAccount(GoogleSignInAccount account) {
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw AuthException("Google didn't return an ID token. Please try again.");
    }
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn.instance.signOut();
  }

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Please choose a stronger password (6+ characters).';
      case 'network-request-failed':
        return 'Network error — check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
