import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors `users/{uid}/habit_logs/{logId}`. Doc id is deterministically
/// `'${habitId}_$date'` so marking/unmarking a day is a single idempotent
/// write instead of a query-then-write.
class HabitLog {
  const HabitLog({
    required this.id,
    required this.habitId,
    required this.date,
    required this.completed,
    this.completedAt,
  });

  final String id;
  final String habitId;

  /// `yyyy-MM-dd`. Kept as a plain string (rather than a Timestamp) so
  /// range queries like "last 60 days" are simple lexicographic comparisons.
  final String date;
  final bool completed;
  final DateTime? completedAt;

  factory HabitLog.fromFirestore(String id, Map<String, dynamic> data) {
    return HabitLog(
      id: id,
      habitId: data['habitId'] as String? ?? '',
      date: data['date'] as String? ?? '',
      completed: data['completed'] as bool? ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'habitId': habitId,
      'date': date,
      'completed': completed,
      'completedAt': completed ? Timestamp.now() : null,
    };
  }
}
