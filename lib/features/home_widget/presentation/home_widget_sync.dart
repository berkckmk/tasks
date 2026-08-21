import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/home_widget_providers.dart';

/// Keeps the Android home-screen widget in step with the app.
///
/// Wraps the signed-in app shell rather than living on the Dashboard screen:
/// completing a habit from the Habits tab has to update the widget too, and
/// the shell is the one place mounted for the whole signed-in session.
///
/// Renders [child] untouched — it contributes no UI of its own.
class HomeWidgetSync extends ConsumerStatefulWidget {
  const HomeWidgetSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<HomeWidgetSync> createState() => _HomeWidgetSyncState();
}

class _HomeWidgetSyncState extends ConsumerState<HomeWidgetSync> {
  HomeWidgetSnapshot? _lastPushed;

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
