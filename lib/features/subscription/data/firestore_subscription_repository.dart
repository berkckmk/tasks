import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/subscription_repository.dart';
import '../domain/subscription_status.dart';

class FirestoreSubscriptionRepository implements SubscriptionRepository {
  FirestoreSubscriptionRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('users').doc(uid).collection('subscription').doc('status');

  @override
  Stream<SubscriptionStatus?> watchStatus(String uid) {
    return _doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return SubscriptionStatus.fromFirestore(data);
    });
  }

  @override
  Future<void> createInitialStatus(String uid) async {
    await _doc(uid).set(
      SubscriptionStatus(
        planId: 'starter',
        status: SubscriptionState.active,
        startedAt: DateTime.now(),
        billingProvider: 'none',
        isTrialActive: false,
      ).toFirestore(),
    );
  }

  @override
  Future<void> setPlan({
    required String uid,
    required String planId,
    required String billingProvider,
  }) async {
    await _doc(uid).set({
      'planId': planId,
      'status': SubscriptionState.active.name,
      'startedAt': Timestamp.now(),
      'billingProvider': billingProvider,
      'isTrialActive': false,
      'expiresAt': null,
      'trialEndsAt': null,
    }, SetOptions(merge: true));
  }
}
