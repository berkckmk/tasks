import 'habit.dart';
import 'habit_log.dart';

String formatLogDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Midnight on the calendar day [days] after [date] (negative to go back).
///
/// Use this instead of `date.add(Duration(days: n))` for anything that walks
/// calendar days. `Duration` is an exact span of hours, but local days are
/// not all 24 hours long: on a spring-forward day the local day is 23 hours,
/// so subtracting a 24-hour Duration from midnight lands on 23:00 of the day
/// *before* the one intended — skipping a day entirely. That silently reset
/// habit streaks once a year, in whichever timezone had just changed.
///
/// `DateTime`'s constructor normalises out-of-range values (day 0 is the
/// last day of the previous month, day 32 rolls into the next), so this is
/// calendar-correct without any special-casing.
DateTime addCalendarDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

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
  var cursor = DateTime(today.year, today.month, today.day);

  // If today isn't completed yet, the streak still reflects consecutive
  // completed days ending yesterday (don't zero it out just because the
  // user hasn't checked in yet today).
  if (!completedDates.contains(formatLogDate(cursor))) {
    cursor = addCalendarDays(cursor, -1);
  }

  while (completedDates.contains(formatLogDate(cursor))) {
    streak++;
    cursor = addCalendarDays(cursor, -1);
  }

  return streak;
}
