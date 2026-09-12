import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../habits/application/habit_providers.dart';
import '../../habits/domain/habit.dart';
import '../../habits/domain/habit_schedule.dart';
import '../../reminders/application/reminder_providers.dart';
import '../../reminders/domain/reminder.dart';
import '../../tasks/application/task_providers.dart';

/// Which of the three pillars an entry came from.
///
/// Carried on the entry rather than inferred from the id, because the rail
/// shows it as a kind label and the toggle has to route back to the right
/// repository.
enum TodayKind { reminder, task, habit }

extension TodayKindLabel on TodayKind {
  String get label => switch (this) {
    TodayKind.reminder => 'Reminder',
    TodayKind.task => 'Task',
    TodayKind.habit => 'Habit',
  };
}

/// One entry on the Today rail.
///
/// A flat projection of a reminder, a task or a habit — deliberately *not* a
/// new domain model. Nothing here is stored; every field is read from the
/// existing providers, and the redesign adds no state.
///
/// [note] is the whole reason this class carries more than a title: it is a
/// reminder's `message` or a task's `description`, the two fields the app
/// already had and never showed.
@immutable
class TodayEntry {
  const TodayEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.note,
    required this.time,
    required this.done,
  });

  final String id;
  final TodayKind kind;
  final String title;

  /// The reminder's `message` or the task's `description`. Empty for habits,
  /// which have no free-text field.
  final String note;

  /// When it is due today. Null for anything with no time — those sort to the
  /// end of the rail under "Anytime".
  final DateTime? time;

  final bool done;

  bool get hasTime => time != null;

  @override
  bool operator ==(Object other) =>
      other is TodayEntry &&
      other.id == id &&
      other.kind == kind &&
      other.title == title &&
      other.note == note &&
      other.time == time &&
      other.done == done;

  @override
  int get hashCode => Object.hash(id, kind, title, note, time, done);
}

/// Everything scheduled for today, across all three pillars, in rail order.
///
/// Ordering is the design's rule, applied once here so the rail, the
/// reminders groups and the widget cannot disagree:
///
///  1. Incomplete before complete — **a checked row sorts to the bottom and
///     stays there until midnight**.
///  2. Then by time, earliest first.
///  3. Untimed entries after timed ones.
///
/// A `Provider` over the three existing stream providers, not a new
/// repository: each underlying stream keeps exactly one listener no matter how
/// many screens read this.
final todayEntriesProvider = Provider<List<TodayEntry>>((ref) {
  final now = DateTime.now();
  final reminders = ref.watch(remindersProvider).valueOrNull ?? const [];
  final tasks = ref.watch(tasksProvider).valueOrNull ?? const [];
  final habits = ref.watch(habitsProvider).valueOrNull ?? const [];

  final entries = <TodayEntry>[
    for (final r in reminders)
      if (r.dueAt != null && isSameDay(r.dueAt!, now))
        TodayEntry(
          id: r.id,
          kind: TodayKind.reminder,
          title: r.title,
          note: r.message,
          time: r.dueAt,
          done: r.status == ReminderStatus.completed,
        ),
    for (final t in tasks)
      if (t.dueDate != null && isSameDay(t.dueDate!, now))
        TodayEntry(
          id: t.id,
          kind: TodayKind.task,
          title: t.title,
          note: t.description,
          // A task's dueDate is a *date* — the picker has no time field — so
          // it carries midnight, which would pin every task to the top of the
          // rail ahead of a 7am reminder. Treated as untimed instead.
          time: _hasClockTime(t.dueDate!) ? t.dueDate : null,
          done: t.isDone,
        ),
    for (final h in habits)
      if (h.isScheduledOn(now))
        TodayEntry(
          id: h.id,
          kind: TodayKind.habit,
          title: h.name,
          note: '',
          time: parseHabitTime(h.reminderTimeLabel, now),
          done: h.isCompletedToday,
        ),
  ];

  entries.sort(compareTodayEntries);
  return entries;
});

/// The rail's ordering rule, exposed so a screen sorting its own subset uses
/// the same one.
int compareTodayEntries(TodayEntry a, TodayEntry b) {
  if (a.done != b.done) return a.done ? 1 : -1;
  if (a.time == null && b.time == null) return a.title.compareTo(b.title);
  if (a.time == null) return 1;
  if (b.time == null) return -1;
  return a.time!.compareTo(b.time!);
}

/// The earliest incomplete item across reminders, tasks and habits with a time
/// today.
///
/// `2b` puts the now-line beside this entry and raises it out of the rail as
/// a card carrying Done and Snooze; `2c` makes it the whole screen. Null when
/// nothing timed is left today, which both directions render as their own
/// "nothing scheduled" state rather than as an empty card.
final nextUpProvider = Provider<TodayEntry?>((ref) {
  final entries = ref.watch(todayEntriesProvider);
  for (final entry in entries) {
    if (!entry.done && entry.hasTime) return entry;
  }
  return null;
});

/// Today's habits, filtered to the ones actually scheduled for today.
///
/// The dashboard counted every habit regardless of schedule, which made the
/// denominator wrong on any day a Weekdays habit didn't fall.
final habitsScheduledTodayProvider = Provider<List<Habit>>((ref) {
  final habits = ref.watch(habitsProvider).valueOrNull ?? const <Habit>[];
  final now = DateTime.now();
  return habits.where((h) => h.isScheduledOn(now)).toList();
});

/// Habits that exist but are not scheduled today — the "2 more habits are
/// scheduled on other days" footer.
final habitsScheduledOtherDaysProvider = Provider<List<Habit>>((ref) {
  final habits = ref.watch(habitsProvider).valueOrNull ?? const <Habit>[];
  final now = DateTime.now();
  return habits.where((h) => !h.isScheduledOn(now)).toList();
});

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _hasClockTime(DateTime value) =>
    value.hour != 0 || value.minute != 0 || value.second != 0;

/// Turns a habit's `reminderTimeLabel` into a time on [day].
///
/// The label is whatever `TimeOfDay.format(context)` produced on the device
/// that saved it, so it can be "7:00 AM", "07:00", or a localised variant with
/// a non-breaking space before the meridiem. It is a display string that was
/// never meant to be parsed — but it is the only time a habit has, and the
/// rail needs to place the row somewhere.
///
/// Anything that doesn't parse returns null, which puts the habit under
/// "Anytime" rather than at midnight. Guessing would silently sort a habit to
/// the top of the day.
@visibleForTesting
DateTime? parseHabitTime(String? label, DateTime day) {
  if (label == null) return null;
  final text = label.trim();
  if (text.isEmpty) return null;

  final match = RegExp(
    r'^(\d{1,2})[:.](\d{2})\s*([AaPp][Mm])?$',
    // \s matches the ordinary space; the non-breaking space some locales
    // insert before the meridiem is normalised out first, below.
  ).firstMatch(text.replaceAll(' ', ' ').replaceAll(' ', ' '));
  if (match == null) return null;

  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final meridiem = match.group(3)?.toLowerCase();

  if (meridiem == 'pm' && hour != 12) hour += 12;
  if (meridiem == 'am' && hour == 12) hour = 0;
  if (hour > 23 || minute > 59) return null;

  return DateTime(day.year, day.month, day.day, hour, minute);
}
