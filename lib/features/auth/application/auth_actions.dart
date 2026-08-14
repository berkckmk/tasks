import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../profile/application/profile_providers.dart';
import '../../subscription/application/subscription_providers.dart';
import 'auth_providers.dart';

/// Composes auth + the one-time profile/subscription-document bootstrap so
/// UI code never touches FirebaseAuth/Firestore directly.
class AuthActions {
  AuthActions(this._ref);

  final Ref _ref;

  Future<void> signUp({required String email, required String password}) async {
    final user = await _ref
        .read(authRepositoryProvider)
        .signUpWithEmail(email: email, password: password);

    await _ref.read(userProfileRepositoryProvider).createInitialProfile(
          uid: user.uid,
          email: user.email ?? email,
          displayName: user.displayName ?? email.split('@').first,
          timezone: DateTime.now().timeZoneName,
        );

    // Every new user starts on Starter until they upgrade.
    await _ref.read(subscriptionRepositoryProvider).createInitialStatus(user.uid);

    final analytics = _ref.read(analyticsServiceProvider);
    await analytics.setUserId(user.uid);
    await analytics.logSignUp('password');
  }

  Future<void> signIn({required String email, required String password}) async {
    final user =
        await _ref.read(authRepositoryProvider).signInWithEmail(email: email, password: password);
    final analytics = _ref.read(analyticsServiceProvider);
    await analytics.setUserId(user.uid);
    await analytics.logLogin('password');
  }

  /// Google sign-in from the Auth screen. Bootstraps a profile/subscription
  /// doc if this is the first time this Google account has signed in
  /// (mirrors [signUp]); otherwise just re-syncs the linked-providers list.
  Future<void> signInWithGoogle() async {
    final authRepository = _ref.read(authRepositoryProvider);
    final user = await authRepository.signInWithGoogle();
    final profileRepository = _ref.read(userProfileRepositoryProvider);
    final analytics = _ref.read(analyticsServiceProvider);

    final existingProfile = await profileRepository.fetchProfile(user.uid);
    if (existingProfile == null) {
      await profileRepository.createInitialProfile(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? (user.email?.split('@').first ?? 'there'),
        timezone: DateTime.now().timeZoneName,
      );
      await _ref.read(subscriptionRepositoryProvider).createInitialStatus(user.uid);
      await analytics.logSignUp('google.com');
    } else {
      await analytics.logLogin('google.com');
    }

    await analytics.setUserId(user.uid);
    await profileRepository.updateLinkedProviders(user.uid, authRepository.linkedProviderIds);
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

  Future<void> signOut() {
    return _ref.read(authRepositoryProvider).signOut();
  }
}

final authActionsProvider = Provider<AuthActions>((ref) => AuthActions(ref));
