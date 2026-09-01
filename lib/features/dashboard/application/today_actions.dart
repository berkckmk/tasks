import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../habits/application/habit_providers.dart';
import '../../reminders/application/reminder_providers.dart';
import '../../reminders/domain/reminder.dart';
import '../../tasks/application/task_providers.dart';
import 'today_providers.dart';

/// Routes a rail row's toggle and snooze back to the right repository.
///
/// The rail mixes all three pillars into one list, so without this every
/// screen showing a [TodayEntry] would carry its own three-branch switch. No
/// new state and no new repository — this only dispatches to
/// `ReminderActions`, `TaskActions` and `HabitActions`, which already exist
/// and already handle their own analytics and streak bookkeeping.
class TodayActions {
  TodayActions(this._ref);

  final Ref _ref;

  /// Marks an entry done or undone.
  Future<void> setDone(TodayEntry entry, bool done) async {
    switch (entry.kind) {
      case TodayKind.reminder:
        final reminders = _ref.read(remindersProvider).valueOrNull;
        final reminder = _firstWhereOrNull(reminders, entry.id, (r) => r.id);
        if (reminder == null) return;
        // saveReminder is the only write path, so the other fields are
        // resent unchanged. That is also what clears `notifiedAt` and
        // re-arms the alert if the reminder is later reopened.
        await _ref
            .read(reminderActionsProvider)
            .saveReminder(
              id: reminder.id,
              title: reminder.title,
              message: reminder.message,
              dueAt: reminder.dueAt,
              status: done
                  ? ReminderStatus.completed
                  : ReminderStatus.scheduled,
            );
      case TodayKind.task:
        await _ref.read(taskActionsProvider).setDone(entry.id, done);
      case TodayKind.habit:
        // HabitActions takes the *current* state and flips it, rather than
        // the target state.
        await _ref
            .read(habitActionsProvider)
            .toggleCompletionToday(entry.id, !done);
    }
  }

  /// Pushes a reminder an hour later.
  ///
  /// Only reminders snooze — a task's due date is a date and a habit has no
  /// instant to move — so the next-up card hides the button for the other two
  /// kinds rather than offering one that does nothing.
  ///
  /// The status is set back to `scheduled` and the repository clears
  /// `notifiedAt` on every edit, so a snoozed reminder re-arms and fires at
  /// the new time. That behaviour already existed; this just uses it.
  static const Duration snoozeBy = Duration(hours: 1);

  bool canSnooze(TodayEntry entry) =>
      entry.kind == TodayKind.reminder && entry.time != null;

  Future<void> snooze(TodayEntry entry) async {
    if (!canSnooze(entry)) return;
    final reminders = _ref.read(remindersProvider).valueOrNull;
    final reminder = _firstWhereOrNull(reminders, entry.id, (r) => r.id);
    if (reminder == null || reminder.dueAt == null) return;

    await _ref
        .read(reminderActionsProvider)
        .saveReminder(
          id: reminder.id,
          title: reminder.title,
          message: reminder.message,
          dueAt: reminder.dueAt!.add(snoozeBy),
          status: ReminderStatus.scheduled,
        );
  }

  /// Quick capture: a title with no time, saved as a scheduled reminder.
  ///
  /// `2b` pins this above the tab bar on Today and Reminders. It creates a
  /// real reminder through the existing action — there is no draft state and
  /// nothing new is stored.
  Future<void> quickCapture(String title, {DateTime? dueAt}) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    await _ref
        .read(reminderActionsProvider)
        .saveReminder(
          id: null,
          title: trimmed,
          message: '',
          dueAt: dueAt,
          status: ReminderStatus.scheduled,
        );
  }
}

final todayActionsProvider = Provider<TodayActions>((ref) => TodayActions(ref));

/// `firstWhere` with an `orElse` that returns null rather than throwing.
///
/// The entry is a snapshot; by the time a tap lands the underlying document
/// may have been deleted on another device, and a `StateError` out of an
/// onTap is a crash rather than a no-op.
T? _firstWhereOrNull<T>(
  List<T>? items,
  String id,
  String Function(T) idOf,
) {
  if (items == null) return null;
  for (final item in items) {
    if (idOf(item) == id) return item;
  }
  return null;
}
