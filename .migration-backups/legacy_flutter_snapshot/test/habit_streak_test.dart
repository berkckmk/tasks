import 'package:flutter_test/flutter_test.dart';

import 'package:steady_progress/features/habits/domain/habit.dart';
import 'package:steady_progress/features/habits/domain/habit_log.dart';
import 'package:steady_progress/features/habits/domain/habit_status.dart';

Habit _habit(String id) => Habit(
      id: id,
      name: id,
      category: HabitCategory.morning,
      frequencyLabel: 'Daily',
      streak: 0,
      isCompletedToday: false,
      colorValue: 0xFF2E5E4E,
    );

List<HabitLog> _logsFor(String habitId, List<String> dates) => [
      for (final date in dates) HabitLog(id: '${habitId}_$date', habitId: habitId, date: date, completed: true),
    ];

void main() {
  group('addCalendarDays', () {
    test('steps whole calendar days, not 24-hour spans', () {
      expect(addCalendarDays(DateTime(2026, 3, 10), -1), DateTime(2026, 3, 9));
      expect(addCalendarDays(DateTime(2026, 1, 1), -1), DateTime(2025, 12, 31));
      expect(addCalendarDays(DateTime(2026, 2, 28), 1), DateTime(2026, 3, 1));
      // Leap year.
      expect(addCalendarDays(DateTime(2028, 2, 28), 1), DateTime(2028, 2, 29));
    });
  });

  group('mergeHabitsWithLogs', () {
    test('counts consecutive completed days ending today', () {
      final habits = mergeHabitsWithLogs(
        [_habit('h1')],
        _logsFor('h1', ['2026-08-12', '2026-08-13', '2026-08-14']),
        today: DateTime(2026, 8, 14),
      );
      expect(habits.single.streak, 3);
      expect(habits.single.isCompletedToday, isTrue);
    });

    test("keeps yesterday's streak when today isn't logged yet", () {
      final habits = mergeHabitsWithLogs(
        [_habit('h1')],
        _logsFor('h1', ['2026-08-12', '2026-08-13']),
        today: DateTime(2026, 8, 14),
      );
      expect(habits.single.streak, 2);
      expect(habits.single.isCompletedToday, isFalse);
    });

    test('stops at a gap', () {
      final habits = mergeHabitsWithLogs(
        [_habit('h1')],
        _logsFor('h1', ['2026-08-10', '2026-08-13', '2026-08-14']),
        today: DateTime(2026, 8, 14),
      );
      expect(habits.single.streak, 2);
    });

    test('survives a spring-forward DST transition', () {
      // The regression this guards: stepping back with
      // `subtract(Duration(days: 1))` from a local midnight on the day after
      // a 23-hour day lands on 23:00 of the day *before* the intended one,
      // skipping a calendar day and silently resetting the streak.
      //
      // Europe/Istanbul has no DST today, so this is expressed with a run of
      // dates spanning a transition date that IS a DST boundary in most
      // northern-hemisphere zones (late March), starting just after midnight.
      final habits = mergeHabitsWithLogs(
        [_habit('h1')],
        _logsFor('h1', ['2026-03-27', '2026-03-28', '2026-03-29', '2026-03-30']),
        today: DateTime(2026, 3, 30, 0, 30),
      );
      expect(habits.single.streak, 4);
    });

    test('ignores logs marked not completed', () {
      final habits = mergeHabitsWithLogs(
        [_habit('h1')],
        [
          HabitLog(id: 'a', habitId: 'h1', date: '2026-08-14', completed: false),
          HabitLog(id: 'b', habitId: 'h1', date: '2026-08-13', completed: true),
        ],
        today: DateTime(2026, 8, 14),
      );
      expect(habits.single.streak, 1);
      expect(habits.single.isCompletedToday, isFalse);
    });

    test('keeps each habit\'s logs separate', () {
      final habits = mergeHabitsWithLogs(
        [_habit('h1'), _habit('h2')],
        [
          ..._logsFor('h1', ['2026-08-13', '2026-08-14']),
          ..._logsFor('h2', ['2026-08-14']),
        ],
        today: DateTime(2026, 8, 14),
      );
      expect(habits.firstWhere((h) => h.id == 'h1').streak, 2);
      expect(habits.firstWhere((h) => h.id == 'h2').streak, 1);
    });
  });
}
