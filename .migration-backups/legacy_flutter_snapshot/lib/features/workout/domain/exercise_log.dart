class ExerciseLog {
  const ExerciseLog({
    required this.id,
    required this.workoutId,
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
    this.isPersonalRecord = false,
  });

  final String id;
  final String workoutId;
  final String name;
  final int sets;
  final int reps;
  final double weight;

  /// Placeholder — real PR detection (comparing against past logs of the
  /// same exercise) is a follow-up; for now this is always false unless
  /// manually set.
  final bool isPersonalRecord;

  factory ExerciseLog.fromFirestore(String id, Map<String, dynamic> data) {
    return ExerciseLog(
      id: id,
      workoutId: data['workoutId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      sets: (data['sets'] as num?)?.toInt() ?? 0,
      reps: (data['reps'] as num?)?.toInt() ?? 0,
      weight: (data['weight'] as num?)?.toDouble() ?? 0,
      isPersonalRecord: data['isPersonalRecord'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'workoutId': workoutId,
      'name': name,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'isPersonalRecord': isPersonalRecord,
    };
  }
}

/// Input shape for logging an exercise as part of a new workout, before it
/// has an id or a workoutId assigned.
class ExerciseDraft {
  const ExerciseDraft({
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
  });

  final String name;
  final int sets;
  final int reps;
  final double weight;
}
