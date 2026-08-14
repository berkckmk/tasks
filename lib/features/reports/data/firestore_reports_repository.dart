import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/query_limits.dart';
import '../domain/report.dart';

/// Read-only — reports are only ever written by the
/// `generateGoogleDocsReport` Cloud Function.
class FirestoreReportsRepository {
  FirestoreReportsRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _reportsRef =>
      _firestore.collection('users').doc(_uid).collection('reports');

  Stream<List<Report>> watchReports() {
    return _reportsRef.orderBy('createdAt', descending: true).limit(kListPageLimit).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => Report.fromFirestore(doc.id, doc.data())).toList(),
        );
  }
}
