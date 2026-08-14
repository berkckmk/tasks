import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../goals/application/goal_providers.dart';
import '../../habits/application/habit_providers.dart';
import '../../habits/domain/habit_log.dart';
import '../../tasks/application/task_providers.dart';
import '../domain/analytics_summary.dart';

final _analyticsLogsProvider = StreamProvider<List<HabitLog>>((ref) {
  final repository = ref.watch(habitRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchRecentLogs(days: 60);
});

final analyticsSummaryProvider = Provider<AnalyticsSummary>((ref) {
  final habits = ref.watch(habitsProvider).valueOrNull ?? const [];
  final logs = ref.watch(_analyticsLogsProvider).valueOrNull ?? const [];
  final tasks = ref.watch(tasksProvider).valueOrNull ?? const [];
  final goals = ref.watch(goalsProvider).valueOrNull ?? const [];
  return buildAnalyticsSummary(habits: habits, logs: logs, tasks: tasks, goals: goals);
});
