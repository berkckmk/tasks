import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/user_profile.dart';

class UserProfileRepository {
  UserProfileRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('users').doc(uid);

  Stream<UserProfile?> watchProfile(String uid) {
    return _doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return UserProfile.fromFirestore(uid, data);
    });
  }

  Future<UserProfile?> fetchProfile(String uid) async {
    final snapshot = await _doc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;
    return UserProfile.fromFirestore(uid, data);
  }

  /// Called once, right after a successful sign-up.
  Future<void> createInitialProfile({
    required String uid,
    required String email,
    required String displayName,
    required String timezone,
  }) async {
    final now = DateTime.now();
    final profile = UserProfile(
      uid: uid,
      email: email,
      displayName: displayName,
      createdAt: now,
      updatedAt: now,
      selectedPlan: 'starter',
      onboardingCompleted: false,
      timezone: timezone,
      appPreferences: const {'notificationsEnabled': true, 'theme': 'system'},
    );
    await _doc(uid).set(profile.toFirestore());
  }

  Future<void> updateSelectedPlan(String uid, String planId) async {
    await _doc(uid).update({
      'selectedPlan': planId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAppPreferences(
    String uid,
    Map<String, dynamic> appPreferences,
  ) async {
    await _doc(uid).update({
      'appPreferences': appPreferences,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markOnboardingCompleted(String uid) async {
    await _doc(uid).update({
      'onboardingCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateLinkedProviders(
    String uid,
    List<String> providerIds,
  ) async {
    await _doc(uid).update({
      'linkedProviders': providerIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Keeps the stored IANA zone matching the device. Every timezone-aware
  /// backend feature (habit reminders, the daily digest, Calendar sync) reads
  /// this field, so a stale value doesn't error — it just silently schedules
  /// everything in the wrong zone. See `core/time/device_timezone.dart`.
  Future<void> updateTimezone(String uid, String timezone) async {
    await _doc(
      uid,
    ).update({'timezone': timezone, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> updatePhotoUrl(String uid, String photoUrl) async {
    await _doc(
      uid,
    ).update({'photoUrl': photoUrl, 'updatedAt': FieldValue.serverTimestamp()});
  }
}
