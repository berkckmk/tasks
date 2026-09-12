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

  /// Pinned to `starter`: firestore.rules only allows the client to *create*
  /// this document, and only with that plan. Anything paid arrives later
  /// from a billing webhook via the Admin SDK.
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

}
