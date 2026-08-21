import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../habits/application/habit_providers.dart';
import '../../tasks/application/task_providers.dart';
import 'home_widget_service.dart';

final homeWidgetServiceProvider = Provider<HomeWidgetService>(
  (ref) => const HomeWidgetService(),
);

/// How many rows of each section travel to the widget.
///
/// The widget shows a handful and summarises the rest as "+N more", so
/// sending the whole collection would just bloat a SharedPreferences string
/// nothing reads.
const int _kWidgetItemLimit = 12;

/// One row on a widget card.
@immutable
class HomeWidgetItem {
  const HomeWidgetItem({
    required this.label,
    this.done = false,
    this.progress = -1,
  });

  final String label;
  final bool done;

  /// 0..1 for goals; negative means "no progress bar".
  final double progress;

  Map<String, Object?> toJson() => {
    'label': label,
    if (done) 'done': true,
    if (progress >= 0) 'progress': progress,
  };

  @override
  bool operator ==(Object other) =>
      other is HomeWidgetItem &&
      other.label == label &&
      other.done == done &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(label, done, progress);
}

/// Exactly what the home-screen widget renders.
///
/// Value equality is the point of this class: the underlying streams re-emit
/// on any document change, but the widget only needs redrawing when something
/// it actually displays moves. Comparing snapshots means editing a habit's
/// colour doesn't trigger a bitmap render and a launcher IPC round trip.
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
/// data would briefly render "0 of 0 done" on the home screen before the real
/// numbers land.
///
/// Reminders are intentionally optional at this stage: the app is centered on
/// Tasks, Reminders, and Habits, but reminder data is not yet part of the
/// shared widget feed. The widget still renders the core tasks/habits view and
/// keeps the active domain selection separate from the snapshot payload.
final homeWidgetSnapshotProvider = Provider<HomeWidgetSnapshot?>((ref) {
  final habits = ref.watch(habitsProvider).valueOrNull;
  final tasks = ref.watch(tasksProvider).valueOrNull;
  if (habits == null || tasks == null) return null;

  // Unfinished first, so the widget's limited rows are spent on what still
  // needs doing rather than on a list of ticks.
  final sortedHabits = [...habits]
    ..sort((a, b) {
      if (a.isCompletedToday == b.isCompletedToday) return 0;
      return a.isCompletedToday ? 1 : -1;
    });
  final sortedTasks = [...tasks]
    ..sort((a, b) {
      if (a.isDone == b.isDone) return 0;
      return a.isDone ? 1 : -1;
    });

  return HomeWidgetSnapshot(
    habitsDone: habits.where((habit) => habit.isCompletedToday).length,
    habitsTotal: habits.length,
    tasksDone: tasks.where((task) => task.isDone).length,
    tasksTotal: tasks.length,
    bestStreak: habits.fold(
      0,
      (best, habit) => habit.streak > best ? habit.streak : best,
    ),
    habits: sortedHabits
        .take(_kWidgetItemLimit)
        .map(
          (habit) =>
              HomeWidgetItem(label: habit.name, done: habit.isCompletedToday),
        )
        .toList(),
    tasks: sortedTasks
        .take(_kWidgetItemLimit)
        .map((task) => HomeWidgetItem(label: task.title, done: task.isDone))
        .toList(),
    reminders: const [],
  );
});
