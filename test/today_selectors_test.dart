import 'package:flutter_test/flutter_test.dart';

import 'package:steady_progress/features/dashboard/application/today_providers.dart';
import 'package:steady_progress/features/habits/domain/habit.dart';
import 'package:steady_progress/features/habits/domain/habit_schedule.dart';

/// The two derivations the redesign adds and the code did not compute — the
/// handoff calls them out by name under "State management".
///
/// Both are pure functions over data the app already has, so they are tested
/// directly rather than through a widget pump.
void main() {
  Habit habit(String frequency) => Habit(
    id: 'h',
    name: 'Read',
    category: HabitCategory.evening,
    frequencyLabel: frequency,
    streak: 0,
    isCompletedToday: false,
    colorValue: 0xFF9184D9,
  );

  // 2026-09-05 is a Saturday; 2026-09-01 is a Tuesday.
  final saturday = DateTime(2026, 9, 5);
  final tuesday = DateTime(2026, 9, 1);

  group('habit scheduling', () {
    test('Daily is scheduled every day', () {
      expect(habit('Daily').isScheduledOn(saturday), isTrue);
      expect(habit('Daily').isScheduledOn(tuesday), isTrue);
    });

    test('Weekdays is Monday to Friday only', () {
      expect(habit('Weekdays').isScheduledOn(tuesday), isTrue);
      expect(habit('Weekdays').isScheduledOn(saturday), isFalse);
      expect(habit('Weekdays').isScheduledOn(DateTime(2026, 9, 6)), isFalse);
    });

    test('matching is case- and whitespace-insensitive', () {
      expect(habit('  weekdays ').isScheduledOn(saturday), isFalse);
    });

    /// A count-per-week frequency records no days anywhere in the data model,
    /// so it cannot be filtered out of today without inventing a schedule.
    test('a count-per-week frequency is schedulable on any day', () {
      for (final label in ['Weekly', '3x / week', '5x / week']) {
        expect(
          habit(label).isScheduledOn(saturday),
          isTrue,
          reason: '$label has no day information to filter on',
        );
      }
    });

    /// Hiding a habit because its frequency string is unfamiliar is the worse
    /// failure — an older document must not silently vanish from Today.
    test('an unrecognised frequency still shows', () {
      expect(habit('Every other Thursday').isScheduledOn(saturday), isTrue);
    });

    test('only Weekdays claims to have fixed days', () {
      expect(habit('Weekdays').hasFixedDays, isTrue);
      expect(habit('Daily').hasFixedDays, isFalse);
      expect(habit('3x / week').hasFixedDays, isFalse);
    });
  });

  group('rail ordering', () {
    TodayEntry entry({
      required String id,
      DateTime? time,
      bool done = false,
      String title = 'Item',
    }) => TodayEntry(
      id: id,
      kind: TodayKind.reminder,
      title: title,
      note: '',
      time: time,
      done: done,
    );

    final at9 = DateTime(2026, 9, 1, 9);
    final at11 = DateTime(2026, 9, 1, 11);

    test('incomplete sorts before complete, whatever the time', () {
      final done9 = entry(id: 'a', time: at9, done: true);
      final open11 = entry(id: 'b', time: at11);
      final sorted = [done9, open11]..sort(compareTodayEntries);
      expect(sorted.map((e) => e.id), ['b', 'a']);
    });

    test('within the same state, earliest first', () {
      final sorted = [entry(id: 'late', time: at11), entry(id: 'early', time: at9)]
        ..sort(compareTodayEntries);
      expect(sorted.map((e) => e.id), ['early', 'late']);
    });

    test('untimed entries come after timed ones', () {
      final sorted = [entry(id: 'anytime'), entry(id: 'timed', time: at11)]
        ..sort(compareTodayEntries);
      expect(sorted.map((e) => e.id), ['timed', 'anytime']);
    });
  });

  group('habit reminder-time parsing', () {
    final day = DateTime(2026, 9, 1);

    test('reads a 24-hour label', () {
      expect(parseHabitTime('07:30', day), DateTime(2026, 9, 1, 7, 30));
    });

    test('reads a 12-hour label with a meridiem', () {
      expect(parseHabitTime('7:30 AM', day), DateTime(2026, 9, 1, 7, 30));
      expect(parseHabitTime('7:30 PM', day), DateTime(2026, 9, 1, 19, 30));
    });

    test('midnight and noon are not shifted twice', () {
      expect(parseHabitTime('12:00 AM', day), DateTime(2026, 9, 1, 0, 0));
      expect(parseHabitTime('12:00 PM', day), DateTime(2026, 9, 1, 12, 0));
    });

    /// Some locales put a non-breaking (or narrow non-breaking) space before
    /// the meridiem. The label is a display string that was never meant to be
    /// parsed, so this is a real input, not a hypothetical one.
    test('tolerates a non-breaking space before the meridiem', () {
      expect(parseHabitTime('7:30 AM', day), DateTime(2026, 9, 1, 7, 30));
      expect(parseHabitTime('7:30 PM', day), DateTime(2026, 9, 1, 19, 30));
    });

    /// Returning null puts the habit under "Anytime". Guessing would sort it
    /// to the very top of the day, ahead of a real 7am reminder.
    test('anything unparseable is null rather than midnight', () {
      for (final label in [null, '', 'morning', '25:00', '7:99', 'noon-ish']) {
        expect(
          parseHabitTime(label, day),
          isNull,
          reason: '"$label" should not resolve to a time',
        );
      }
    });
  });
}
