import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/module_lock_view.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/stat_card.dart';
import '../../subscription/application/subscription_providers.dart';
import '../application/analytics_providers.dart';
import '../domain/analytics_summary.dart';
import '../../../core/widgets/app_glass_app_bar.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAccess = ref
        .watch(planEnforcementProvider)
        .canAccessAdvancedAnalytics;

    if (!canAccess) {
      return Scaffold(
        appBar: AppGlassAppBar(title: const Text('Analytics')),
        body: const ModuleLockView(
          featureName: 'Progress analytics',
          benefit:
              'See weekly habit and task trends, your best streak, and a '
              'productivity score.',
          requiredPlanName: 'Growth',
          icon: Icons.insights_outlined,
        ),
      );
    }

    return Scaffold(
      appBar: AppGlassAppBar(title: const Text('Analytics')),
      body: ref
          .watch(analyticsSummaryProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ErrorState(error: error),
            data: (summary) => _SummaryBody(summary: summary),
          ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
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
              ProgressRing(
                progress: summary.productivityScore / 100,
                color: AppColors.deepGreen,
              ),
              const SizedBox(width: AppSpacing.lg),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Productivity score',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'An early, simple blend of this week\'s habit, task, and goal '
                      'progress — more signal coming later.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.subtleText,
                      ),
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
                icon: Icons.local_fire_department,
                label: 'Best streak',
                value: '${summary.bestStreak} days',
                accentColor: AppColors.amber,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(
                icon: Icons.flag_outlined,
                label: 'Goal progress avg',
                value: '${(summary.goalProgressAverage * 100).round()}%',
                accentColor: AppColors.mutedBlue,
              ),
            ),
          ],
        ),
        if (summary.mostConsistentHabitName != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.spa_outlined, color: AppColors.deepGreen),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Most consistent habit',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.subtleText,
                        ),
                      ),
                      Text(
                        summary.mostConsistentHabitName!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Weekly completion',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: summary.weeklyBreakdown
                .map((week) => _WeekRow(week: week))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.week});

  final WeekCompletion week;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Week of ${week.weekLabel}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
              ),
              Text(
                'Habits ${(week.habitCompletionRate * 100).round()}%'
                '${week.taskCompletionRate == null ? '' : ' · Tasks ${(week.taskCompletionRate! * 100).round()}%'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.subtleText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: week.habitCompletionRate,
              minHeight: 6,
              backgroundColor: AppColors.deepGreen.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.deepGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
