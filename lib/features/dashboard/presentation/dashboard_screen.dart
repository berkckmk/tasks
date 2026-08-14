import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/stat_card.dart';
import '../../goals/application/goal_providers.dart';
import '../../habits/application/habit_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../tasks/application/task_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);
    final tasksAsync = ref.watch(tasksProvider);
    final goalsAsync = ref.watch(goalsProvider);
    final profileAsync = ref.watch(profileProvider);

    final habits = habitsAsync.maybeWhen(data: (d) => d, orElse: () => const []);
    final tasks = tasksAsync.maybeWhen(data: (d) => d, orElse: () => const []);
    final goals = goalsAsync.maybeWhen(data: (d) => d, orElse: () => const []);
    final name = profileAsync.maybeWhen(
      data: (p) => p?.displayName.split(' ').first ?? '',
      orElse: () => '',
    );

    final completedHabits = habits.where((h) => h.isCompletedToday).length;
    final completedTasks = tasks.where((t) => t.isDone).length;
    final activeGoalCount = goals.where((g) => g.progress < 1.0).length;
    final totalToday = habits.length + tasks.length;
    final doneToday = completedHabits + completedTasks;
    final todayProgress = totalToday == 0 ? 0.0 : doneToday / totalToday;

    final isLoading = (habitsAsync.isLoading && !habitsAsync.hasValue) ||
        (tasksAsync.isLoading && !tasksAsync.hasValue) ||
        (goalsAsync.isLoading && !goalsAsync.hasValue);

    final firstError = [habitsAsync, tasksAsync, goalsAsync]
        .map((a) => a.hasError && !a.hasValue ? a.error : null)
        .firstWhere((e) => e != null, orElse: () => null);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : firstError != null
              ? ErrorState(error: firstError)
              : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              children: [
                Text(
                  name.isEmpty ? 'Welcome back' : 'Welcome back, $name',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Here\'s how today is going.',
                  style: TextStyle(color: AppColors.subtleText),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Row(
                    children: [
                      ProgressRing(progress: todayProgress),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Today\'s progress',
                              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.charcoal),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$doneToday of $totalToday items completed',
                              style: const TextStyle(fontSize: 13, color: AppColors.subtleText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.spa_outlined,
                        label: 'Habits done today',
                        value: '$completedHabits / ${habits.length}',
                        accentColor: AppColors.deepGreen,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatCard(
                        icon: Icons.checklist_outlined,
                        label: 'Tasks completed',
                        value: '$completedTasks / ${tasks.length}',
                        accentColor: AppColors.mutedBlue,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatCard(
                        icon: Icons.flag_outlined,
                        label: 'Active goals',
                        value: '$activeGoalCount',
                        accentColor: AppColors.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.amber),
                          SizedBox(width: AppSpacing.sm),
                          Text('This week\'s focus', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.charcoal)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        goals.isEmpty
                            ? 'Set a goal to see your weekly focus here.'
                            : goals.first.title,
                        style: const TextStyle(color: AppColors.charcoal),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Progress this week', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.charcoal)),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.deepGreen.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Progress chart coming soon',
                          style: TextStyle(color: AppColors.subtleText, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text('Quick actions', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.charcoal)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    AppButton(
                      label: 'Add habit',
                      variant: AppButtonVariant.secondary,
                      icon: Icons.add,
                      onPressed: () => context.push('/habits/new'),
                    ),
                    AppButton(
                      label: 'Add task',
                      variant: AppButtonVariant.secondary,
                      icon: Icons.add,
                      onPressed: () => context.push('/tasks/new'),
                    ),
                    AppButton(
                      label: 'Add goal',
                      variant: AppButtonVariant.secondary,
                      icon: Icons.add,
                      onPressed: () => context.push('/goals/new'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
