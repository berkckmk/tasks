import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../goals/application/goal_providers.dart';
import '../../habits/application/habit_providers.dart';
import '../../tasks/application/task_providers.dart';
import '../domain/analytics_summary.dart';

/// The analytics summary, carrying the combined loading/error state of the
/// four streams it's built from.
///
/// It used to be a plain `Provider<AnalyticsSummary>` that collapsed every
/// source to `?? const []`, so while Firestore was still loading — or if any
/// stream errored — the screen confidently rendered "Productivity score 0",
/// "Best streak 0 days" as though those were real measurements.
final analyticsSummaryProvider = Provider<AsyncValue<AnalyticsSummary>>((ref) {
  final habits = ref.watch(habitsProvider);
  final logs = ref.watch(habitLogsProvider);
  final tasks = ref.watch(tasksProvider);
  final goals = ref.watch(goalsProvider);

  final sources = [habits, logs, tasks, goals];
  for (final source in sources) {
    if (source.hasError) return AsyncValue.error(source.error!, source.stackTrace!);
  }
  if (sources.any((source) => source.isLoading && !source.hasValue)) {
    return const AsyncValue.loading();
  }

  return AsyncValue.data(
    buildAnalyticsSummary(
      habits: habits.requireValue,
      logs: logs.requireValue,
      tasks: tasks.requireValue,
      goals: goals.requireValue,
    ),
  );
});
