import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
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
    await _ref.read(userProfileRepositoryProvider).updateSelectedPlan(uid, planId);
  }

  Future<void> updateNotificationsEnabled(bool enabled) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    final current = _ref.read(profileProvider).valueOrNull;
    final preferences = Map<String, dynamic>.from(current?.appPreferences ?? {});
    preferences['notificationsEnabled'] = enabled;
    await _ref.read(userProfileRepositoryProvider).updateAppPreferences(uid, preferences);
  }

  Future<void> markOnboardingCompleted() async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return;
    await _ref.read(userProfileRepositoryProvider).markOnboardingCompleted(uid);
  }
}

final profileActionsProvider = Provider<ProfileActions>((ref) => ProfileActions(ref));
