import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/application/today_actions.dart';
import '../../dashboard/application/today_providers.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _drainPending());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _drainPending();
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
