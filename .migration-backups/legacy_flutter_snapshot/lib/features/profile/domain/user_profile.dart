import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors the `users/{uid}` document.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
    required this.selectedPlan,
    required this.onboardingCompleted,
    required this.timezone,
    required this.appPreferences,
    this.linkedProviders = const ['password'],
    this.photoUrl,
  });

  final String uid;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String selectedPlan;
  final bool onboardingCompleted;
  final String timezone;
  final Map<String, dynamic> appPreferences;

  /// Firebase Storage download URL for the user's avatar, set via
  /// `users/{uid}/avatar.jpg` — see AvatarRepository.
  final String? photoUrl;

  /// Denormalized copy of `FirebaseAuth.currentUser.providerData` provider
  /// IDs (e.g. `['password', 'google.com']`) — Firebase Auth is the source
  /// of truth; this is kept in sync so it's queryable from Firestore too.
  final List<String> linkedProviders;

  bool get notificationsEnabled => (appPreferences['notificationsEnabled'] as bool?) ?? true;

  bool get hasGoogleLinked => linkedProviders.contains('google.com');

  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      selectedPlan: data['selectedPlan'] as String? ?? 'starter',
      onboardingCompleted: data['onboardingCompleted'] as bool? ?? false,
      timezone: data['timezone'] as String? ?? '',
      appPreferences: Map<String, dynamic>.from(data['appPreferences'] as Map? ?? {}),
      linkedProviders: (data['linkedProviders'] as List<dynamic>?)?.cast<String>() ?? const ['password'],
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'selectedPlan': selectedPlan,
      'onboardingCompleted': onboardingCompleted,
      'timezone': timezone,
      'appPreferences': appPreferences,
      'linkedProviders': linkedProviders,
    };
  }
}
