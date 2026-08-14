import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firestore_batch.dart';
import '../../../core/firebase/query_limits.dart';
import '../domain/exercise_log.dart';
import '../domain/workout.dart';
import '../domain/workout_repository.dart';

class FirestoreWorkoutRepository implements WorkoutRepository {
  FirestoreWorkoutRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _workoutsRef =>
      _firestore.collection('users').doc(_uid).collection('workouts');

  CollectionReference<Map<String, dynamic>> get _exerciseLogsRef =>
      _firestore.collection('users').doc(_uid).collection('exercise_logs');

  @override
  Stream<List<Workout>> watchWorkouts() {
    return _workoutsRef.orderBy('date', descending: true).limit(kListPageLimit).snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => Workout.fromFirestore(doc.id, doc.data())).toList(),
        );
  }

  @override
  Stream<List<ExerciseLog>> watchExerciseLogs() {
    // Deliberately unordered and unlimited, unlike every other list stream
    // here. Exercise logs are joined to workouts by workoutId in the UI, so
    // an arbitrary subset would silently blank out exercises for otherwise
    // visible workouts — and ordering by `date` is not yet possible because
    // logs written before the field was added below don't have one, and
    // Firestore excludes documents missing the field it orders by.
    //
    // To bound this: backfill `date` onto existing exercise_logs, then order
    // by it and apply kListPageLimit.
    return _exerciseLogsRef.snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => ExerciseLog.fromFirestore(doc.id, doc.data())).toList(),
        );
  }

  @override
  Future<void> logWorkout({
    required String name,
    required DateTime date,
    required List<ExerciseDraft> exercises,
  }) async {
    final workoutRef = _workoutsRef.doc();
    final batch = _firestore.batch();
    batch.set(workoutRef, {
      ...Workout(id: workoutRef.id, name: name, date: date).toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    for (final exercise in exercises) {
      final logRef = _exerciseLogsRef.doc();
      batch.set(
        logRef,
        {
          ...ExerciseLog(
            id: logRef.id,
            workoutId: workoutRef.id,
            name: exercise.name,
            sets: exercise.sets,
            reps: exercise.reps,
            weight: exercise.weight,
          ).toFirestore(),
          // Copied from the parent workout so this collection can eventually
          // be ordered and paged on its own — see watchExerciseLogs above.
          'date': Timestamp.fromDate(date),
        },
      );
    }
    await batch.commit();
  }

  @override
  Future<void> deleteWorkout(String workoutId) async {
    // Logs first, workout last — see FirestoreHabitRepository.deleteHabit for
    // why the order matters and why this chunks the deletes.
    final orphanedLogs = await _exerciseLogsRef.where('workoutId', isEqualTo: workoutId).get();
    await deleteAllInBatches(_firestore, orphanedLogs.docs.map((doc) => doc.reference));

    await _workoutsRef.doc(workoutId).delete();
  }
}
