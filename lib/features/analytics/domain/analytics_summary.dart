import '../../goals/domain/goal.dart';
import '../../habits/domain/habit.dart';
import '../../habits/domain/habit_log.dart';
import '../../habits/domain/habit_status.dart' show formatLogDate;
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

  final weeks = <WeekCompletion>[];
  for (var i = 3; i >= 0; i--) {
    final weekStart = _mostRecentMonday(today).subtract(Duration(days: 7 * i));
    final weekEnd = weekStart.add(const Duration(days: 6));

    var completedHabitDays = 0;
    for (var d = 0; d < 7; d++) {
      final day = weekStart.add(Duration(days: d));
      if (day.isAfter(today)) break;
      final dayLabel = formatLogDate(day);
      for (final habit in habits) {
        if (completedDatesByHabit[habit.id]?.contains(dayLabel) ?? false) {
          completedHabitDays++;
        }
      }
    }
    final possibleHabitDays = habits.length * 7;
    final habitRate = possibleHabitDays == 0 ? 0.0 : completedHabitDays / possibleHabitDays;

    final tasksDueThisWeek = tasks.where(
      (t) =>
          t.dueDate != null &&
          !t.dueDate!.isBefore(weekStart) &&
          !t.dueDate!.isAfter(weekEnd),
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
  final mostConsistent = habits.isEmpty
      ? null
      : habits.reduce((a, b) => a.streak >= b.streak ? a : b).name;

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
  return d.subtract(Duration(days: d.weekday - 1));
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _shortMonthDay(DateTime date) => '${_monthNames[date.month - 1]} ${date.day}';
