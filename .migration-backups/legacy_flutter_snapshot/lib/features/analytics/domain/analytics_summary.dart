import '../../goals/domain/goal.dart';
import '../../habits/domain/habit.dart';
import '../../habits/domain/habit_log.dart';
import '../../habits/domain/habit_status.dart' show addCalendarDays, formatLogDate;
import '../../tasks/domain/task_item.dart';

class WeekCompletion {
  const WeekCompletion({
    required this.weekLabel,
    required this.habitCompletionRate,
    required this.taskCompletionRate,
  });

  final String weekLabel;

  /// 0.0 - 1.0
  final double habitCompletionRate;

  /// 0.0 - 1.0. `null` when no tasks were due that week.
  final double? taskCompletionRate;
}

class AnalyticsSummary {
  const AnalyticsSummary({
    required this.weeklyBreakdown,
    required this.goalProgressAverage,
    required this.bestStreak,
    required this.mostConsistentHabitName,
    required this.productivityScore,
  });

  /// Oldest first, most recent last.
  final List<WeekCompletion> weeklyBreakdown;
  final double goalProgressAverage;
  final int bestStreak;
  final String? mostConsistentHabitName;

  /// 0-100. An early, simple blend of habit/task/goal progress — a starting
  /// point, not a validated formula.
  final int productivityScore;
}

/// Pure and synchronous so it's easy to test independent of Firestore. Weeks
/// run Monday-Sunday, based on `now`.
AnalyticsSummary buildAnalyticsSummary({
  required List<Habit> habits,
  required List<HabitLog> logs,
  required List<TaskItem> tasks,
  required List<Goal> goals,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final completedDatesByHabit = <String, Set<String>>{};
  for (final log in logs) {
    if (!log.completed) continue;
    completedDatesByHabit.putIfAbsent(log.habitId, () => {}).add(log.date);
  }

  final todayLabel = formatLogDate(today);

  final weeks = <WeekCompletion>[];
  for (var i = 3; i >= 0; i--) {
    final weekStart = addCalendarDays(_mostRecentMonday(today), -7 * i);
    // Exclusive: the instant the next week starts. Comparing against
    // midnight on Sunday excluded every task due later that same Sunday from
    // *both* this week and the next — they were counted in no week at all.
    final weekEndExclusive = addCalendarDays(weekStart, 7);

    var completedHabitDays = 0;
    // Only days that have actually happened count toward the denominator.
    // Dividing by a full 7 while the numerator stopped at today made the
    // current week structurally understate: a user with a perfect record
    // showed 14% on Monday and 43% on Wednesday, and since productivityScore
    // is computed from the latest week, the headline number on the Analytics
    // screen was wrong six days out of seven.
    var elapsedDays = 0;
    for (var d = 0; d < 7; d++) {
      final day = addCalendarDays(weekStart, d);
      final dayLabel = formatLogDate(day);
      if (dayLabel.compareTo(todayLabel) > 0) break;
      elapsedDays++;
      for (final habit in habits) {
        if (completedDatesByHabit[habit.id]?.contains(dayLabel) ?? false) {
          completedHabitDays++;
        }
      }
    }
    final possibleHabitDays = habits.length * elapsedDays;
    final habitRate = possibleHabitDays == 0 ? 0.0 : completedHabitDays / possibleHabitDays;

    final tasksDueThisWeek = tasks.where(
      (t) =>
          t.dueDate != null &&
          !t.dueDate!.isBefore(weekStart) &&
          t.dueDate!.isBefore(weekEndExclusive),
    );
    final dueCount = tasksDueThisWeek.length;
    final doneCount = tasksDueThisWeek.where((t) => t.isDone).length;
    final taskRate = dueCount == 0 ? null : doneCount / dueCount;

    weeks.add(
      WeekCompletion(
        weekLabel: _shortMonthDay(weekStart),
        habitCompletionRate: habitRate.clamp(0.0, 1.0),
        taskCompletionRate: taskRate,
      ),
    );
  }

  final bestStreak = habits.isEmpty ? 0 : habits.map((h) => h.streak).reduce((a, b) => a > b ? a : b);
  // Consistency is how often the habit was completed across the whole log
  // window, not the current streak — a habit completed 50 of the last 60
  // days is more consistent than one with a 5-day streak and nothing before
  // it, and the label says "most consistent", not "longest streak" (which
  // bestStreak above already reports).
  final mostConsistent = habits.isEmpty
      ? null
      : habits
          .reduce(
            (a, b) => (completedDatesByHabit[a.id]?.length ?? 0) >=
                    (completedDatesByHabit[b.id]?.length ?? 0)
                ? a
                : b,
          )
          .name;

  final goalProgressAverage =
      goals.isEmpty ? 0.0 : goals.map((g) => g.progress).reduce((a, b) => a + b) / goals.length;

  final latestWeek = weeks.last;
  final latestTaskRate = latestWeek.taskCompletionRate ?? 0.0;
  final productivityScore = ((latestWeek.habitCompletionRate * 0.4) +
          (latestTaskRate * 0.4) +
          (goalProgressAverage * 0.2)) *
      100;

  return AnalyticsSummary(
    weeklyBreakdown: weeks,
    goalProgressAverage: goalProgressAverage,
    bestStreak: bestStreak,
    mostConsistentHabitName: mostConsistent,
    productivityScore: productivityScore.round().clamp(0, 100),
  );
}

DateTime _mostRecentMonday(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return addCalendarDays(d, -(d.weekday - 1));
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _shortMonthDay(DateTime date) => '${_monthNames[date.month - 1]} ${date.day}';
