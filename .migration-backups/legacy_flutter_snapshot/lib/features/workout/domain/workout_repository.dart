import 'exercise_log.dart';
import 'workout.dart';

abstract class WorkoutRepository {
  Stream<List<Workout>> watchWorkouts();

  Stream<List<ExerciseLog>> watchExerciseLogs();

  Future<void> logWorkout({
    required String name,
    required DateTime date,
    required List<ExerciseDraft> exercises,
  });

  Future<void> deleteWorkout(String workoutId);
}
