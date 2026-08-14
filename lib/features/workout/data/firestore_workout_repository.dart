import 'package:cloud_firestore/cloud_firestore.dart';

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
    return _workoutsRef.orderBy('date', descending: true).snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => Workout.fromFirestore(doc.id, doc.data())).toList(),
        );
  }

  @override
  Stream<List<ExerciseLog>> watchExerciseLogs() {
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
      'createdAt': Timestamp.now(),
    });
    for (final exercise in exercises) {
      final logRef = _exerciseLogsRef.doc();
      batch.set(
        logRef,
        ExerciseLog(
          id: logRef.id,
          workoutId: workoutRef.id,
          name: exercise.name,
          sets: exercise.sets,
          reps: exercise.reps,
          weight: exercise.weight,
        ).toFirestore(),
      );
    }
    await batch.commit();
  }

  @override
  Future<void> deleteWorkout(String workoutId) async {
    await _workoutsRef.doc(workoutId).delete();

    final orphanedLogs = await _exerciseLogsRef.where('workoutId', isEqualTo: workoutId).get();
    final batch = _firestore.batch();
    for (final doc in orphanedLogs.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
