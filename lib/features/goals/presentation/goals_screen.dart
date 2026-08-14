import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/module_lock_view.dart';
import '../../subscription/application/subscription_providers.dart';
import '../application/goal_providers.dart';
import 'widgets/goal_card.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAccess = ref.watch(planEnforcementProvider).canAccessGoalPlanner;

    if (!canAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Goals')),
        body: const ModuleLockView(
          featureName: 'Goal planner',
          benefit: 'Break big goals into milestones and connect them to your daily '
              'habits and tasks.',
          requiredPlanName: 'Growth',
          icon: Icons.flag_outlined,
        ),
      );
    }

    final goalsAsync = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'goalsFab',
        onPressed: () => context.push('/goals/new'),
        backgroundColor: AppColors.deepGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: goalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) {
            return EmptyState(
              icon: Icons.flag_outlined,
              title: 'No goals yet',
              message: 'Set a goal to connect your daily habits and tasks to something bigger.',
              actionLabel: 'Add goal',
              onAction: () => context.push('/goals/new'),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: [
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.calendar_view_month, color: AppColors.mutedBlue),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quarterly breakdown',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Monthly/quarterly goal breakdown is coming soon.',
                            style: TextStyle(fontSize: 12, color: AppColors.subtleText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Active goals', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              ...goals.map(
                (goal) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: GoalCard(
                    goal: goal,
                    onTap: () => context.push('/goals/${goal.id}/edit'),
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
