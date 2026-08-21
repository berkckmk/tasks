import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/time/device_timezone.dart';
import '../../auth/application/auth_providers.dart';
import '../data/user_profile_repository.dart';
import '../domain/user_profile.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(ref.watch(firestoreProvider));
});

/// Null while there's no signed-in user, or in the brief window between
/// sign-up succeeding and the `users/{uid}` document finishing its first
/// write.
final profileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(userProfileRepositoryProvider).watchProfile(uid);
});

class ProfileActions {
  ProfileActions(this._ref);

  final Ref _ref;

  Future<void> updatePlan(String planId) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    await _ref
        .read(userProfileRepositoryProvider)
        .updateSelectedPlan(uid, planId);
  }

  Future<void> updateNotificationsEnabled(bool enabled) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    final current = _ref.read(profileProvider).valueOrNull;
    final preferences = Map<String, dynamic>.from(
      current?.appPreferences ?? {},
    );
    preferences['notificationsEnabled'] = enabled;
    await _ref
        .read(userProfileRepositoryProvider)
        .updateAppPreferences(uid, preferences);
  }

  Future<void> markOnboardingCompleted() async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    await _ref.read(userProfileRepositoryProvider).markOnboardingCompleted(uid);
  }

  /// Repairs `users/{uid}.timezone` when it doesn't match the device's real
  /// IANA zone. Called on every cold start (see SplashScreen) because the
  /// value was previously written once at sign-up from
  /// `DateTime.now().timeZoneName` — which is an abbreviation, not a zone id
  /// — so existing accounts are carrying values the backend can only read as
  /// UTC. It also keeps the zone right for a user who travels or moves.
  ///
  /// Writes only on an actual mismatch, so the steady-state cost is one
  /// document read per launch and no write at all.
  Future<void> syncTimezone() async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;

    final repository = _ref.read(userProfileRepositoryProvider);
    final deviceZone = await resolveDeviceTimeZone();

    // A missing profile means the bootstrap hasn't run yet; it writes the
    // zone itself, so there's nothing to repair and nothing to create here.
    final profile = await repository.fetchProfile(uid);
    if (profile == null || profile.timezone == deviceZone) return;

    await repository.updateTimezone(uid, deviceZone);
  }
}

final profileActionsProvider = Provider<ProfileActions>(
  (ref) => ProfileActions(ref),
);
