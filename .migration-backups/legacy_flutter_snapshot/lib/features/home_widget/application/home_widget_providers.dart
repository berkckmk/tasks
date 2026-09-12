import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../dashboard/application/today_providers.dart';
import '../../habits/application/habit_providers.dart';
import '../../reminders/application/reminder_providers.dart';
import '../../reminders/domain/reminder.dart';
import '../../tasks/application/task_providers.dart';
import 'home_widget_service.dart';

final homeWidgetServiceProvider = Provider<HomeWidgetService>(
  (ref) => const HomeWidgetService(),
);

/// How many rows of each section travel to the widget.
///
/// The widget shows a handful and summarises the rest as "+N later this
/// week", so sending the whole collection would just bloat a
/// SharedPreferences string nothing reads.
const int _kWidgetItemLimit = 12;

/// One row on the widget.
///
/// [id] and [kind] are new. They are what let a row be *acted on* rather than
/// only read: the toggle has to name a document to write back to, and the
/// row's own tap has to open the right editor. The old shape carried a label
/// and a done flag, which is all a static bitmap needed.
@immutable
class HomeWidgetItem {
  const HomeWidgetItem({
    required this.id,
    required this.kind,
    required this.label,
    this.done = false,
    this.time = '',
  });

  final String id;

  /// 'reminder' | 'task' | 'habit'. Matches `WidgetItemKind` on the Kotlin
  /// side and [TodayKind] on this one.
  final String kind;
  final String label;
  final bool done;

  /// Formatted here rather than on the Android side, because this is where
  /// the device's locale and 12/24-hour preference are already resolved.
  /// Empty means "no time".
  final String time;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'label': label,
    if (done) 'done': true,
    if (time.isNotEmpty) 'time': time,
  };

  @override
  bool operator ==(Object other) =>
      other is HomeWidgetItem &&
      other.id == id &&
      other.kind == kind &&
      other.label == label &&
      other.done == done &&
      other.time == time;

  @override
  int get hashCode => Object.hash(id, kind, label, done, time);
}

/// Exactly what the home-screen widget renders.
///
/// Value equality is the point of this class: the underlying streams re-emit
/// on any document change, but the widget only needs redrawing when something
/// it actually displays moves. Comparing snapshots means editing a habit's
/// colour doesn't trigger a launcher IPC round trip.
@immutable
class HomeWidgetSnapshot {
  const HomeWidgetSnapshot({
    required this.habitsDone,
    required this.habitsTotal,
    required this.tasksDone,
    required this.tasksTotal,
    required this.bestStreak,
    required this.habits,
    required this.tasks,
    required this.reminders,
  });

  final int habitsDone;
  final int habitsTotal;
  final int tasksDone;
  final int tasksTotal;
  final int bestStreak;
  final List<HomeWidgetItem> habits;
  final List<HomeWidgetItem> tasks;
  final List<HomeWidgetItem> reminders;

  /// The per-section rows, as the single JSON string the Android side stores.
  String get itemsJson => jsonEncode({
    'habits': habits.map((item) => item.toJson()).toList(),
    'tasks': tasks.map((item) => item.toJson()).toList(),
    'reminders': reminders.map((item) => item.toJson()).toList(),
  });

  @override
  bool operator ==(Object other) =>
      other is HomeWidgetSnapshot &&
      other.habitsDone == habitsDone &&
      other.habitsTotal == habitsTotal &&
      other.tasksDone == tasksDone &&
      other.tasksTotal == tasksTotal &&
      other.bestStreak == bestStreak &&
      listEquals(other.habits, habits) &&
      listEquals(other.tasks, tasks) &&
      listEquals(other.reminders, reminders);

  @override
  int get hashCode => Object.hash(
    habitsDone,
    habitsTotal,
    tasksDone,
    tasksTotal,
    bestStreak,
    Object.hashAll(habits),
    Object.hashAll(tasks),
    Object.hashAll(reminders),
  );
}

/// Null until habits and tasks have both produced a value — pushing partial
/// data would briefly render "0 / 0" on the home screen before the real
/// numbers land.
///
/// **Reminders are now part of the feed.** They were deliberately left out
/// while the widget was a bitmap of counts; a reminder-first redesign whose
/// widget can't show a reminder would be the wrong way round.
final homeWidgetSnapshotProvider = Provider<HomeWidgetSnapshot?>((ref) {
  final habits = ref.watch(habitsProvider).valueOrNull;
  final tasks = ref.watch(tasksProvider).valueOrNull;
  final reminders = ref.watch(remindersProvider).valueOrNull;
  if (habits == null || tasks == null || reminders == null) return null;

  final now = DateTime.now();
  final time = DateFormat.jm();

  // The rail's ordering rule, so the widget and Today can't disagree:
  // incomplete first, then by time, untimed last.
  int byDoneThenTime(HomeWidgetItem a, HomeWidgetItem b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    if (a.time.isEmpty && b.time.isEmpty) return a.label.compareTo(b.label);
    if (a.time.isEmpty) return 1;
    if (b.time.isEmpty) return -1;
    return a.time.compareTo(b.time);
  }

  final habitItems =
      habits
          .map(
            (habit) => HomeWidgetItem(
              id: habit.id,
              kind: TodayKind.habit.name,
              label: habit.name,
              done: habit.isCompletedToday,
              time: habit.reminderTimeLabel ?? '',
            ),
          )
          .toList()
        ..sort(byDoneThenTime);

  final taskItems =
      tasks
          .map(
            (task) => HomeWidgetItem(
              id: task.id,
              kind: TodayKind.task.name,
              label: task.title,
              done: task.isDone,
              // A task now *may* carry a clock time, and only then. An
              // all-day task stays untimed rather than showing a fabricated
              // 12:00, which also sorts it below the timed rows — the same
              // rule the rail uses.
              time: task.allDay || task.dueDate == null
                  ? ''
                  : time.format(task.dueDate!),
            ),
          )
          .toList()
        ..sort(byDoneThenTime);

  // Today's reminders **and anything already overdue and not finished**.
  //
  // The rule used to be `isSameDay` alone, and it is why a reminder added in
  // the app could never appear on the widget: one added for tomorrow was not
  // today's, and the moment it came due it became yesterday's. An overdue
  // reminder is the single most actionable row this widget can carry, so
  // dropping it was the wrong half to keep. Still no forward horizon — a
  // widget listing next month's is a widget of things you cannot act on now.
  bool isOnToday(ReminderItem r) {
    final dueAt = r.dueAt;
    if (dueAt == null) return false;
    if (isSameDay(dueAt, now)) return true;
    return dueAt.isBefore(now) && r.status != ReminderStatus.completed;
  }

  final reminderItems =
      reminders
          .where(isOnToday)
          .map(
            (r) => HomeWidgetItem(
              id: r.id,
              kind: TodayKind.reminder.name,
              label: r.title,
              done: r.status == ReminderStatus.completed,
              time: time.format(r.dueAt!),
            ),
          )
          .toList()
        ..sort(byDoneThenTime);

  return HomeWidgetSnapshot(
    habitsDone: habits.where((habit) => habit.isCompletedToday).length,
    habitsTotal: habits.length,
    tasksDone: tasks.where((task) => task.isDone).length,
    tasksTotal: tasks.length,
    bestStreak: habits.fold(
      0,
      (best, habit) => habit.streak > best ? habit.streak : best,
    ),
    habits: habitItems.take(_kWidgetItemLimit).toList(),
    tasks: taskItems.take(_kWidgetItemLimit).toList(),
    reminders: reminderItems.take(_kWidgetItemLimit).toList(),
  );
});
