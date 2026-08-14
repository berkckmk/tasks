import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/firestore_workout_repository.dart';
import '../domain/exercise_log.dart';
import '../domain/workout.dart';
import '../domain/workout_repository.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return FirestoreWorkoutRepository(ref.watch(firestoreProvider), uid);
});

final workoutsProvider = StreamProvider<List<Workout>>((ref) {
  final repository = ref.watch(workoutRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchWorkouts();
});

final exerciseLogsProvider = StreamProvider<List<ExerciseLog>>((ref) {
  final repository = ref.watch(workoutRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchExerciseLogs();
});

class WorkoutActions {
  WorkoutActions(this._ref);

  final Ref _ref;

  Future<void> logWorkout({
    required String name,
    required DateTime date,
    required List<ExerciseDraft> exercises,
  }) async {
    final repository = _ref.read(workoutRepositoryProvider);
    if (repository == null) return;
    await repository.logWorkout(name: name, date: date, exercises: exercises);
  }

  Future<void> deleteWorkout(String workoutId) async {
    final repository = _ref.read(workoutRepositoryProvider);
    if (repository == null) return;
    await repository.deleteWorkout(workoutId);
  }
}

final workoutActionsProvider = Provider<WorkoutActions>((ref) => WorkoutActions(ref));
