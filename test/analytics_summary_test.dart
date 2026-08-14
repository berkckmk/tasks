import 'package:flutter_test/flutter_test.dart';

import 'package:steady_progress/features/analytics/domain/analytics_summary.dart';
import 'package:steady_progress/features/habits/domain/habit.dart';
import 'package:steady_progress/features/habits/domain/habit_log.dart';
import 'package:steady_progress/features/tasks/domain/task_item.dart';

Habit _habit(String id) => Habit(
      id: id,
      name: id,
      category: HabitCategory.morning,
      frequencyLabel: 'Daily',
      streak: 0,
      isCompletedToday: false,
      colorValue: 0xFF2E5E4E,
    );

HabitLog _log(String habitId, String date) =>
    HabitLog(id: '${habitId}_$date', habitId: habitId, date: date, completed: true);

TaskItem _task({required DateTime dueDate, required bool done}) => TaskItem(
      id: 'task-${dueDate.toIso8601String()}-$done',
      title: 'task',
      dueDate: dueDate,
      priority: TaskPriority.medium,
      status: done ? TaskStatus.done : TaskStatus.todo,
    );

void main() {
  group('weekly habit completion rate', () {
    test('divides by elapsed days, not the whole week', () {
      // Wednesday 2026-08-12. Monday/Tuesday/Wednesday completed = perfect
      // so far. The denominator used to be a full 7 days regardless, which
      // reported 43% for a flawless record — and productivityScore is derived
      // from this week, so the headline score was wrong six days in seven.
      final summary = buildAnalyticsSummary(
        habits: [_habit('h1')],
        logs: [_log('h1', '2026-08-10'), _log('h1', '2026-08-11'), _log('h1', '2026-08-12')],
        tasks: const [],
        goals: const [],
        now: DateTime(2026, 8, 12),
      );
      expect(summary.weeklyBreakdown.last.habitCompletionRate, 1.0);
    });

    test('a half-kept week reads as half', () {
      final summary = buildAnalyticsSummary(
        habits: [_habit('h1')],
        logs: [_log('h1', '2026-08-10'), _log('h1', '2026-08-12')],
        tasks: const [],
        goals: const [],
        now: DateTime(2026, 8, 13), // Mon-Thu elapsed = 4 days, 2 completed
      );
      expect(summary.weeklyBreakdown.last.habitCompletionRate, closeTo(0.5, 0.0001));
    });

    test('no habits yields a zero rate rather than a division error', () {
      final summary = buildAnalyticsSummary(
        habits: const [],
        logs: const [],
        tasks: const [],
        goals: const [],
        now: DateTime(2026, 8, 12),
      );
      expect(summary.weeklyBreakdown.last.habitCompletionRate, 0.0);
      expect(summary.productivityScore, 0);
    });
  });

  group('weekly task bucketing', () {
    test('a task due late on the final Sunday still counts that week', () {
      // The week of Mon 2026-08-10 ends Sun 2026-08-16. A task due at 18:00
      // that Sunday used to fall outside both this week (end was midnight
      // Sunday) and the next — counted in no week at all.
      final summary = buildAnalyticsSummary(
        habits: const [],
        logs: const [],
        tasks: [_task(dueDate: DateTime(2026, 8, 16, 18), done: true)],
        goals: const [],
        now: DateTime(2026, 8, 16, 20),
      );
      expect(summary.weeklyBreakdown.last.taskCompletionRate, 1.0);
    });

    test('a week with no tasks due reports null, not zero', () {
      final summary = buildAnalyticsSummary(
        habits: const [],
        logs: const [],
        tasks: const [],
        goals: const [],
        now: DateTime(2026, 8, 12),
      );
      expect(summary.weeklyBreakdown.last.taskCompletionRate, isNull);
    });
  });

  test('most consistent habit is the most-completed one, not the longest streak', () {
    final summary = buildAnalyticsSummary(
      habits: [_habit('steady'), _habit('streaky')],
      logs: [
        // `steady` was kept far more often overall...
        for (var d = 1; d <= 10; d++) _log('steady', '2026-08-${d.toString().padLeft(2, '0')}'),
        // ...while `streaky` only has the last three days in a row.
        _log('streaky', '2026-08-10'),
        _log('streaky', '2026-08-11'),
        _log('streaky', '2026-08-12'),
      ],
      tasks: const [],
      goals: const [],
      now: DateTime(2026, 8, 12),
    );
    expect(summary.mostConsistentHabitName, 'steady');
  });

  test('always reports four weeks, oldest first', () {
    final summary = buildAnalyticsSummary(
      habits: const [],
      logs: const [],
      tasks: const [],
      goals: const [],
      now: DateTime(2026, 8, 12),
    );
    expect(summary.weeklyBreakdown, hasLength(4));
  });
}
