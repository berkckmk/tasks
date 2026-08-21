import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/time/device_timezone.dart';
import '../../home_widget/application/home_widget_providers.dart';
import '../../notifications/application/push_notifications_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../subscription/application/subscription_providers.dart';
import 'auth_providers.dart';
import 'user_scoped_providers.dart';

/// Composes auth + the one-time profile/subscription-document bootstrap so
/// UI code never touches FirebaseAuth/Firestore directly.
class AuthActions {
  AuthActions(this._ref);

  final Ref _ref;

  /// Creates `users/{uid}` + `subscription/status` and logs the sign-up
  /// event, but only if this account doesn't already have a profile — safe
  /// to call on every sign-in, not just the first one. Requires a token
  /// with `email_verified: true` (firestore.rules' `isOwner()`), so this is
  /// called right after Google sign-in (verified immediately) or right
  /// after email/password verification completes (see
  /// [checkEmailVerified]) — never at signUp() time, when the token isn't
  /// verified yet.
  Future<void> _bootstrapProfileIfNeeded(
    User user, {
    required String signUpProvider,
  }) async {
    final profileRepository = _ref.read(userProfileRepositoryProvider);
    final analytics = _ref.read(analyticsServiceProvider);

    final existingProfile = await profileRepository.fetchProfile(user.uid);
    if (existingProfile == null) {
      await profileRepository.createInitialProfile(
        uid: user.uid,
        email: user.email ?? '',
        displayName:
            user.displayName ?? (user.email?.split('@').first ?? 'there'),
        // A real IANA zone id ("Europe/Istanbul"), NOT
        // `DateTime.now().timeZoneName` — that returns an abbreviation like
        // "+03"/"EDT", which the backend can't parse and silently reads as
        // UTC. See core/time/device_timezone.dart.
        timezone: await resolveDeviceTimeZone(),
      );
      // Every new user starts on Starter until they upgrade.
      await _ref
          .read(subscriptionRepositoryProvider)
          .createInitialStatus(user.uid);
      await analytics.logSignUp(signUpProvider);
    } else {
      await analytics.logLogin(signUpProvider);
    }

    await analytics.setUserId(user.uid);
    final authRepository = _ref.read(authRepositoryProvider);
    await profileRepository.updateLinkedProviders(
      user.uid,
      authRepository.linkedProviderIds,
    );
  }

  /// Only creates the Firebase Auth account and sends the verification
  /// email — the profile/subscription bootstrap is deferred to
  /// [checkEmailVerified] (see its doc comment and firestore.rules'
  /// `isOwner()` for why: the token isn't verified yet at this point, so
  /// Firestore would reject the write anyway).
  Future<void> signUp({required String email, required String password}) async {
    await _ref
        .read(authRepositoryProvider)
        .signUpWithEmail(email: email, password: password);
  }

  Future<void> signIn({required String email, required String password}) async {
    await _ref
        .read(authRepositoryProvider)
        .signInWithEmail(email: email, password: password);
    // No bootstrap call here: an existing account was already bootstrapped
    // either at Google sign-in or at its first post-verification
    // checkEmailVerified() — signing back in later never needs it again,
    // and an *unverified* password account can't reach this screen at all
    // (the router keeps it on /verify-email).
  }

  /// Google sign-in from the Auth screen. Bootstraps a profile/subscription
  /// doc if this is the first time this Google account has signed in
  /// (mirrors [signUp] + [checkEmailVerified]); otherwise just re-syncs the
  /// linked-providers list.
  ///
  /// Pass [account] on web, where sign-in happens via Google's own rendered
  /// button and arrives through `GoogleSignIn.authenticationEvents` (see
  /// GoogleWebSignInButton in auth_screen.dart) rather than a direct
  /// `authenticate()` call — leave it null on Android/iOS.
  Future<void> signInWithGoogle({GoogleSignInAccount? account}) async {
    final authRepository = _ref.read(authRepositoryProvider);
    final user = account == null
        ? await authRepository.signInWithGoogle()
        : await authRepository.signInWithGoogleAccount(account);
    await _bootstrapProfileIfNeeded(user, signUpProvider: 'google.com');
  }

  /// Links Google to the already-signed-in user (Settings > Google
  /// Integrations > Google Account > Connect).
  Future<void> linkGoogleAccount() async {
    final authRepository = _ref.read(authRepositoryProvider);
    final user = await authRepository.linkGoogleToCurrentUser();
    await _ref
        .read(userProfileRepositoryProvider)
        .updateLinkedProviders(user.uid, authRepository.linkedProviderIds);
  }

  Future<void> unlinkGoogleAccount() async {
    final authRepository = _ref.read(authRepositoryProvider);
    await authRepository.unlinkGoogle();
    final uid = authRepository.currentUser?.uid;
    if (uid != null) {
      await _ref
          .read(userProfileRepositoryProvider)
          .updateLinkedProviders(uid, authRepository.linkedProviderIds);
    }
  }

  /// Signs out, and unwinds everything that was scoped to the signed-in user.
  ///
  /// Each step matters on a shared device:
  ///  - the FCM token is unregistered first, while the user's credentials are
  ///    still valid. Left behind, `users/{previousUid}/fcmTokens/{token}`
  ///    keeps pointing at this device, so the *previous* user's habit
  ///    reminders push to whoever signs in next.
  ///  - analytics stops attributing events to the old uid.
  ///  - user-scoped providers are invalidated, because Riverpod keeps the
  ///    previous `AsyncValue` data while a stream re-subscribes. Consumers
  ///    that read `.valueOrNull` would otherwise render the previous
  ///    account's habits, tasks and goals to the new one for that window.
  Future<void> signOut() async {
    final uid = _ref.read(currentUidProvider);

    if (uid != null) {
      try {
        await _ref
            .read(pushNotificationsRepositoryProvider)
            .unregisterCurrentToken(uid);
      } catch (error) {
        // Never block sign-out on cleanup: if the token can't be removed
        // (offline, permission), signing out still has to work.
        debugPrint('Failed to unregister FCM token on sign-out: $error');
      }
    }

    // Same shared-device reasoning as the FCM token above: the home-screen
    // widget caches the last pushed numbers and would otherwise keep showing
    // the previous account's progress to whoever signs in next.
    await _ref.read(homeWidgetServiceProvider).clear();

    await _ref.read(analyticsServiceProvider).setUserId(null);
    await _ref.read(authRepositoryProvider).signOut();

    for (final provider in userScopedProviders) {
      _ref.invalidate(provider);
    }
  }

  Future<void> resendVerificationEmail() {
    return _ref.read(authRepositoryProvider).resendVerificationEmail();
  }

  /// Re-checks the server for a just-verified email. On the transition to
  /// verified, runs the profile/subscription bootstrap deferred from
  /// [signUp] (see its doc comment) — by this point
  /// `reloadAndCheckEmailVerified()` has already force-refreshed the ID
  /// token, so the write actually satisfies firestore.rules' `isOwner()`.
  /// Then refreshes [authStateChangesProvider] so the router's redirect
  /// re-evaluates immediately — `User.reload()` alone doesn't emit a new
  /// `authStateChanges()` event, so without this the router wouldn't
  /// notice until some *other* auth event happened to fire.
  Future<bool> checkEmailVerified() async {
    final authRepository = _ref.read(authRepositoryProvider);
    final verified = await authRepository.reloadAndCheckEmailVerified();
    if (!verified) return false;

    final user = authRepository.currentUser;
    if (user != null) {
      await _bootstrapProfileIfNeeded(user, signUpProvider: 'password');
    }
    _ref.invalidate(authStateChangesProvider);
    return true;
  }
}

final authActionsProvider = Provider<AuthActions>((ref) => AuthActions(ref));
