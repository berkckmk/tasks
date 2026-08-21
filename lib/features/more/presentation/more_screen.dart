import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';

import 'package:flutter/foundation.dart' show kDebugMode;

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../pricing/domain/plan_module.dart';
import '../../subscription/application/subscription_providers.dart';
import '../../../core/widgets/app_glass_app_bar.dart';
import '../../../core/layout/scroll_insets.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enforcement = ref.watch(planEnforcementProvider);

    return Scaffold(
      appBar: AppGlassAppBar(title: const Text('More')),
      body: ListView(
        padding: scrollInsets(context),
        children: [
          Text('Analytics', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          _ModuleRow(
            icon: Icons.insights_outlined,
            title: 'Analytics',
            subtitle: 'Weekly trends, streaks, and a productivity score',
            unlocked: enforcement.canAccessModule(PlanModule.advancedAnalytics),
            requiredPlanName: 'Growth',
            onTap: () => context.push('/analytics'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Complete plan modules',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ModuleRow(
            icon: Icons.savings_outlined,
            title: 'Finance tracker',
            subtitle: 'Income, expenses, and savings goals',
            unlocked: enforcement.canAccessModule(PlanModule.financeTracker),
            requiredPlanName: 'Complete',
            onTap: () => context.push('/finance'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ModuleRow(
            icon: Icons.fitness_center_outlined,
            title: 'Workout tracker',
            subtitle: 'Log workouts and exercises',
            unlocked: enforcement.canAccessModule(PlanModule.workoutTracker),
            requiredPlanName: 'Complete',
            onTap: () => context.push('/workout'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ModuleRow(
            icon: Icons.menu_book_outlined,
            title: 'Learning tracker',
            subtitle: 'Books, courses, and podcasts',
            unlocked: enforcement.canAccessModule(PlanModule.learningTracker),
            requiredPlanName: 'Complete',
            onTap: () => context.push('/learning'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ModuleRow(
            icon: Icons.edit_calendar_outlined,
            title: 'Content planner',
            subtitle: 'Plan content ideas across platforms',
            unlocked: enforcement.canAccessModule(PlanModule.contentPlanner),
            requiredPlanName: 'Complete',
            onTap: () => context.push('/content'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Google', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          _ModuleRow(
            icon: Icons.hub_outlined,
            title: 'Google Integrations',
            subtitle:
                'Calendar sync, Sheets export, Drive backup, Docs reports',
            unlocked: enforcement.canAccessGoogleIntegrations,
            requiredPlanName: 'Complete',
            onTap: () => context.push('/google-integrations'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ModuleRow(
            icon: Icons.summarize_outlined,
            title: 'Reports',
            subtitle: 'Generated Google Docs progress reports',
            unlocked: enforcement.canAccessGoogleIntegrations,
            requiredPlanName: 'Complete',
            onTap: () => context.push('/reports'),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (kDebugMode) ...[
            const Text('Debug', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Seed dev data for ekmekarasitutun@gmail.com'),
              onTap: () => context.push('/dev-seed'),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.unlocked,
    required this.requiredPlanName,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool unlocked;
  final String requiredPlanName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      // A locked row routes to /pricing instead of opening the module and
      // showing its lock screen — the row already displays a lock icon, so
      // the tap should go where the lock is resolved.
      onTap: unlocked ? onTap : () => context.push('/pricing'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: (unlocked ? AppColors.deepGreen : AppColors.subtleText)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              icon,
              color: unlocked ? AppColors.deepGreen : AppColors.subtleText,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.subtleText,
                  ),
                ),
              ],
            ),
          ),
          if (unlocked)
            const Icon(Icons.chevron_right, color: AppColors.subtleText)
          else
            Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: AppColors.amber,
                ),
                const SizedBox(width: 4),
                Text(
                  requiredPlanName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.amber,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
