import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/query_limits.dart';
import '../domain/goal.dart';
import '../domain/goal_repository.dart';
import '../domain/milestone.dart';

class FirestoreGoalRepository implements GoalRepository {
  FirestoreGoalRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _goalsRef =>
      _firestore.collection('users').doc(_uid).collection('goals');

  @override
  Stream<List<Goal>> watchGoals() {
    return _goalsRef.orderBy('createdAt', descending: true).limit(kListPageLimit).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => Goal.fromFirestore(doc.id, doc.data())).toList(),
        );
  }

  @override
  Future<void> saveGoal({
    required String? id,
    required String title,
    required String description,
    required GoalCategory category,
    required DateTime? targetDate,
    required GoalProgressType progressType,
    required double manualProgress,
    required List<Milestone> milestones,
  }) async {
    final data = Goal(
      id: id ?? '',
      title: title,
      description: description,
      category: category,
      targetDate: targetDate,
      progressType: progressType,
      manualProgress: manualProgress,
      milestones: milestones,
    ).toFirestore();

    if (id == null) {
      await _goalsRef.add({...data, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await _goalsRef.doc(id).set(data, SetOptions(merge: true));
    }
  }

  @override
  Future<void> deleteGoal(String goalId) async {
    await _goalsRef.doc(goalId).delete();
  }
}
