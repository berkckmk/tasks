import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/module_lock_view.dart';
import '../../../core/widgets/stat_card.dart';
import '../../subscription/application/subscription_providers.dart';
import '../application/workout_providers.dart';
import '../domain/exercise_log.dart';
import '../domain/workout.dart';
import 'widgets/log_workout_sheet.dart';

class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAccess = ref.watch(planEnforcementProvider).canAccessWorkoutTracker;

    if (!canAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout tracker')),
        body: const ModuleLockView(
          featureName: 'Workout tracker',
          benefit: 'Log workouts and exercises, and keep an eye on your weekly training '
              'consistency.',
          requiredPlanName: 'Complete',
          icon: Icons.fitness_center_outlined,
        ),
      );
    }

    final workoutsAsync = ref.watch(workoutsProvider);
    final exerciseLogsAsync = ref.watch(exerciseLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Workout tracker')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'workoutFab',
        onPressed: () => showLogWorkoutSheet(context, ref),
        backgroundColor: AppColors.deepGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: workoutsAsync.when(
        data: (workouts) {
          final now = DateTime.now();
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final weekStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
          final thisWeekCount =
              workouts.where((w) => !w.date.isBefore(weekStart)).length;

          final logsByWorkout = <String, List<ExerciseLog>>{};
          for (final log in exerciseLogsAsync.valueOrNull ?? const <ExerciseLog>[]) {
            logsByWorkout.putIfAbsent(log.workoutId, () => []).add(log);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: [
              StatCard(
                icon: Icons.fitness_center,
                label: 'Workouts this week',
                value: '$thisWeekCount',
                accentColor: AppColors.deepGreen,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('History', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              if (workouts.isEmpty)
                const EmptyState(
                  icon: Icons.fitness_center_outlined,
                  title: 'No workouts logged yet',
                  message: 'Log your first workout to start tracking consistency.',
                )
              else
                ...workouts.map(
                  (workout) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _WorkoutTile(
                      workout: workout,
                      exercises: logsByWorkout[workout.id] ?? const [],
                    ),
                  ),
                ),
            ],
          );
        },
        error: (error, stackTrace) => ErrorState(error: error),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _WorkoutTile extends ConsumerWidget {
  const _WorkoutTile({required this.workout, required this.exercises});

  final Workout workout;
  final List<ExerciseLog> exercises;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.charcoal),
                    ),
                    Text(
                      DateFormat.yMMMd().format(workout.date),
                      style: const TextStyle(fontSize: 12, color: AppColors.subtleText),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.subtleText),
                onPressed: () => ref.read(workoutActionsProvider).deleteWorkout(workout.id),
              ),
            ],
          ),
          if (exercises.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...exercises.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${e.name} — ${e.sets}×${e.reps} @ ${e.weight.toStringAsFixed(0)}kg',
                        style: const TextStyle(fontSize: 13, color: AppColors.charcoal),
                      ),
                    ),
                    if (e.isPersonalRecord)
                      const Icon(Icons.emoji_events_outlined, size: 14, color: AppColors.amber),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
