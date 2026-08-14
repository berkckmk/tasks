import 'habit.dart';
import 'habit_log.dart';

String formatLogDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Combines raw habit documents with their recent completion logs into the
/// UI-facing [Habit] shape (streak + isCompletedToday filled in). Pure and
/// therefore easy to reason about/test independent of Firestore.
List<Habit> mergeHabitsWithLogs(List<Habit> habits, List<HabitLog> logs, {DateTime? today}) {
  final effectiveToday = today ?? DateTime.now();
  final logsByHabit = <String, List<HabitLog>>{};
  for (final log in logs) {
    if (!log.completed) continue;
    logsByHabit.putIfAbsent(log.habitId, () => []).add(log);
  }

  return habits.map((habit) {
    final completedDates = (logsByHabit[habit.id] ?? const <HabitLog>[]).map((l) => l.date).toSet();
    final isCompletedToday = completedDates.contains(formatLogDate(effectiveToday));
    final streak = _calculateStreak(completedDates, effectiveToday);
    return habit.copyWith(streak: streak, isCompletedToday: isCompletedToday);
  }).toList();
}

int _calculateStreak(Set<String> completedDates, DateTime today) {
  var streak = 0;
  var cursor = today;

  // If today isn't completed yet, the streak still reflects consecutive
  // completed days ending yesterday (don't zero it out just because the
  // user hasn't checked in yet today).
  if (!completedDates.contains(formatLogDate(cursor))) {
    cursor = cursor.subtract(const Duration(days: 1));
  }

  while (completedDates.contains(formatLogDate(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return streak;
}
