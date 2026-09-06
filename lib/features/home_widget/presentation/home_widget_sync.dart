import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../dashboard/application/today_actions.dart';
import '../../dashboard/application/today_providers.dart';
import '../../habits/application/habit_providers.dart';
import '../../habits/domain/habit.dart';
import '../../reminders/application/reminder_providers.dart';
import '../../reminders/domain/reminder.dart';
import '../../tasks/application/task_providers.dart';
import '../../tasks/domain/task_item.dart';
import '../application/home_widget_providers.dart';

/// Keeps the Android home-screen widget in step with the app, in both
/// directions.
///
/// Wraps the signed-in app shell rather than living on one screen:
/// completing a habit from the Habits screen has to update the widget too,
/// and the shell is the one thing mounted for the whole signed-in session.
///
/// Renders [child] untouched — it contributes no UI of its own.
///
/// ## The two directions
///
/// **Out:** a snapshot is pushed whenever [homeWidgetSnapshotProvider]
/// changes. That is the original one-way arrangement and it is unchanged.
///
/// **In:** ticks the widget made while the app wasn't running are drained
/// here and written through the real repositories. The widget queues them
/// rather than writing them itself — see `WidgetPendingToggles` on the
/// Android side for why, in short: completing an item is not a field write.
/// A habit's tick writes a `habit_logs` document the streak derivation reads
/// back; a reminder's resends the document so `notifiedAt` clears and the
/// alert re-arms. Doing that from Kotlin would mean a second implementation
/// of three repositories.
///
/// **In, again:** items composed in the widget's quick-add modal are created
/// here for the same reason. The widget cannot create any of the three — a
/// task's `create` is denied by `firestore.rules` outright and goes through
/// the `createTask` callable, which is where the plan's active-task limit is
/// enforced — so the modal queues the intent and shows an optimistic row, and
/// this is where it becomes a real document.
///
/// The drain runs once on mount and again on every resume, which is when a
/// tap on the home screen is most likely to have just happened.
class HomeWidgetSync extends ConsumerStatefulWidget {
  const HomeWidgetSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<HomeWidgetSync> createState() => _HomeWidgetSyncState();
}

class _HomeWidgetSyncState extends ConsumerState<HomeWidgetSync>
    with WidgetsBindingObserver {
  HomeWidgetSnapshot? _lastPushed;

  /// Guards against two drains overlapping — a resume landing while the
  /// previous drain is still awaiting Firestore would apply each tick twice.
  bool _draining = false;

  /// The same guard for the quick-add queue. Separate from [_draining]: the
  /// two queues are independent, and one waiting on Firestore must not hold
  /// the other back.
  bool _drainingAdds = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drainPending();
      _drainPendingAdds();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _drainPending();
      _drainPendingAdds();
    }
  }

  Future<void> _drainPending() async {
    if (_draining || !mounted) return;
    _draining = true;
    try {
      final service = ref.read(homeWidgetServiceProvider);
      final raw = await service.readPendingToggles();
      if (raw.isEmpty || raw == '[]') return;

      final List<dynamic> queue;
      try {
        queue = jsonDecode(raw) as List<dynamic>;
      } catch (error) {
        // A malformed queue is unreadable, not recoverable. Better to log it
        // than to loop on it forever at every resume.
        debugPrint('Widget pending queue was malformed, ignoring: $error');
        return;
      }

      final actions = ref.read(todayActionsProvider);
      final applied = <String>[];

      for (final raw in queue) {
        if (raw is! Map) continue;
        final id = raw['id'] as String?;
        final kindName = raw['kind'] as String?;
        final done = raw['done'] as bool? ?? false;
        if (id == null || kindName == null) continue;

        final kind = TodayKind.values
            .where((k) => k.name == kindName)
            .firstOrNull;
        if (kind == null) continue;

        try {
          await actions.setDone(
            // setDone only reads `id` and `kind` off the entry; the rest is
            // resolved from the live providers, so a stale label from the
            // queue can never overwrite a renamed item.
            TodayEntry(
              id: id,
              kind: kind,
              title: '',
              note: '',
              time: null,
              done: !done,
            ),
            done,
          );
          applied.add(id);
        } catch (error) {
          // Leave it queued. The next resume retries; dropping it would lose
          // a tick the user has already seen take effect on their home
          // screen.
          debugPrint('Widget toggle write-through failed for $id: $error');
        }
      }

      await service.clearPendingToggles(applied);
    } finally {
      _draining = false;
    }
  }

  /// Creates the items the widget's modal composed while the app was away.
  ///
  /// Each goes through its own ordinary action class, so a quick-added task is
  /// created by the same callable the Tasks screen uses and a quick-added
  /// habit gets the same defaults the form starts with. The modal collects a
  /// title and an area and nothing else — everything below that is a default,
  /// chosen to match what the app's own "new" screens open with.
  Future<void> _drainPendingAdds() async {
    if (_drainingAdds || !mounted) return;
    _drainingAdds = true;
    try {
      final service = ref.read(homeWidgetServiceProvider);
      final raw = await service.readPendingAdds();
      if (raw.isEmpty || raw == '[]') return;

      final List<dynamic> queue;
      try {
        queue = jsonDecode(raw) as List<dynamic>;
      } catch (error) {
        debugPrint('Widget quick-add queue was malformed, ignoring: $error');
        return;
      }

      final created = <String>[];
      for (final entry in queue) {
        if (entry is! Map) continue;
        final id = entry['id'] as String?;
        final kindName = entry['kind'] as String?;
        final label = (entry['label'] as String? ?? '').trim();
        if (id == null || kindName == null || label.isEmpty) continue;

        final kind = TodayKind.values
            .where((k) => k.name == kindName)
            .firstOrNull;
        if (kind == null) continue;

        // The modal writes 0 for "not set" — SharedPreferences JSON has no
        // null long — so anything non-positive is absent, not 1970.
        DateTime? at(Object? millis) {
          final value = millis is int ? millis : null;
          if (value == null || value <= 0) return null;
          return DateTime.fromMillisecondsSinceEpoch(value);
        }

        try {
          await _create(
            kind,
            label,
            startAt: at(entry['startAt']),
            endAt: at(entry['endAt']),
            allDay: entry['allDay'] as bool? ?? true,
          );
          created.add(id);
        } catch (error) {
          // Left queued, exactly as a failed tick is: the next resume retries.
          // Dropping it would lose an item the user can already see on their
          // home screen.
          debugPrint('Widget quick-add create failed for $id: $error');
        }
      }

      await service.clearPendingAdds(created);
    } finally {
      _drainingAdds = false;
    }
  }

  /// Creates one composed item through the same action class its own screen
  /// uses, so a quick-added task is created by the `createTask` callable and a
  /// quick-added habit gets the defaults the form opens with.
  ///
  /// The schedule comes from the modal and is not re-derived here: the modal
  /// enforces the app's own rules (a reminder needs a date *and* a time, a
  /// task needs a date and may span a range) and a second, looser copy of
  /// those rules on this side would be the one that let a bad item through.
  Future<void> _create(
    TodayKind kind,
    String label, {
    DateTime? startAt,
    DateTime? endAt,
    required bool allDay,
  }) async {
    switch (kind) {
      case TodayKind.reminder:
        // The modal will not queue a reminder without a moment; the fallback
        // is for an entry queued by an older build, which had no schedule at
        // all. Next whole hour rather than now, so it is still in the future
        // by the time it is written.
        final dueAt = startAt ?? _nextHour();
        await ref
            .read(reminderActionsProvider)
            .saveReminder(
              id: null,
              title: label,
              message: '',
              dueAt: dueAt,
              status: ReminderStatus.scheduled,
            );
      case TodayKind.task:
        final start = startAt ?? DateTime.now();
        await ref
            .read(taskActionsProvider)
            .saveTask(
              id: null,
              title: label,
              description: '',
              startDate: DateTime(start.year, start.month, start.day),
              dueDate: endAt ?? start,
              allDay: allDay,
              priority: TaskPriority.medium,
              status: TaskStatus.todo,
              relatedGoalId: null,
            );
      case TodayKind.habit:
        // A habit has no date, only an optional time of day — and its time is
        // stored as the display string `TimeOfDay.format` produces, which is
        // what `parseHabitTime` reads back. Everything else is the default
        // AddEditHabitScreen opens with.
        await ref
            .read(habitActionsProvider)
            .saveHabit(
              id: null,
              name: label,
              category: HabitCategory.morning,
              frequencyLabel: 'Daily',
              colorValue: AppColors.deepGreen.toARGB32(),
              reminderTimeLabel: startAt == null || allDay
                  ? null
                  : DateFormat.jm().format(startAt),
            );
    }
  }

  DateTime _nextHour() {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
    ).add(const Duration(hours: 1));
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(homeWidgetSnapshotProvider);

    if (snapshot != null && snapshot != _lastPushed) {
      _lastPushed = snapshot;
      // Deferred to after the frame: the push crosses a method channel and
      // makes the launcher re-render, neither of which belongs in a build().
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(homeWidgetServiceProvider)
            .update(
              habitsDone: snapshot.habitsDone,
              habitsTotal: snapshot.habitsTotal,
              tasksDone: snapshot.tasksDone,
              tasksTotal: snapshot.tasksTotal,
              bestStreak: snapshot.bestStreak,
              itemsJson: snapshot.itemsJson,
            );
      });
    }

    return widget.child;
  }
}
