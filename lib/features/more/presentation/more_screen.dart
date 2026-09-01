import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_type.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/layout/scroll_insets.dart';
import '../../../core/widgets/nocturne.dart';
import '../../pricing/domain/plan_module.dart';
import '../../subscription/application/subscription_providers.dart';

/// **More** — everything that used to have a bottom-tab slot and no longer
/// does, plus everything that never had one.
///
/// Six tabs became four, so Habits and Profile moved here. They lead the
/// screen, above Analytics and the Complete-plan modules: they are core
/// features that lost a tab, not extras, and burying them under the paid
/// modules would read as a demotion rather than as a reorganisation.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColorsScheme.of(context);
    final enforcement = ref.watch(planEnforcementProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: scrollInsets(context),
          children: [
            Text('More', style: AppType.h2.copyWith(color: c.text)),
            const SizedBox(height: AppSpacing.xl),

            const _SectionLabel('Your app'),
            _Row(
              icon: AppIcons.plant,
              title: 'Habits',
              subtitle: 'Build and track your daily routines',
              onTap: () => context.push('/habits'),
            ),
            _Row(
              icon: AppIcons.userCircle,
              title: 'Profile',
              subtitle: 'Account, notifications and plan',
              onTap: () => context.push('/profile'),
              last: true,
            ),

            const SizedBox(height: AppSpacing.xl),
            const _SectionLabel('Analytics'),
            _Row(
              icon: AppIcons.chartLine,
              title: 'Analytics',
              subtitle: 'Weekly trends, streaks, and a productivity score',
              unlocked: enforcement.canAccessModule(
                PlanModule.advancedAnalytics,
              ),
              requiredPlanName: 'Growth',
              onTap: () => context.push('/analytics'),
              last: true,
            ),

            const SizedBox(height: AppSpacing.xl),
            const _SectionLabel('Complete plan modules'),
            _Row(
              icon: AppIcons.wallet,
              title: 'Finance tracker',
              subtitle: 'Income, expenses, and savings goals',
              unlocked: enforcement.canAccessModule(PlanModule.financeTracker),
              onTap: () => context.push('/finance'),
            ),
            _Row(
              icon: AppIcons.barbell,
              title: 'Workout tracker',
              subtitle: 'Log workouts and exercises',
              unlocked: enforcement.canAccessModule(PlanModule.workoutTracker),
              onTap: () => context.push('/workout'),
            ),
            _Row(
              icon: AppIcons.bookOpen,
              title: 'Learning tracker',
              subtitle: 'Books, courses, and podcasts',
              unlocked: enforcement.canAccessModule(PlanModule.learningTracker),
              onTap: () => context.push('/learning'),
            ),
            _Row(
              icon: AppIcons.notePencil,
              title: 'Content planner',
              subtitle: 'Plan content ideas across platforms',
              unlocked: enforcement.canAccessModule(PlanModule.contentPlanner),
              onTap: () => context.push('/content'),
              last: true,
            ),

            const SizedBox(height: AppSpacing.xl),
            const _SectionLabel('Google'),
            _Row(
              icon: AppIcons.googleLogo,
              title: 'Google Integrations',
              subtitle:
                  'Calendar sync, Sheets export, Drive backup, Docs reports',
              unlocked: enforcement.canAccessGoogleIntegrations,
              onTap: () => context.push('/google-integrations'),
            ),
            _Row(
              icon: AppIcons.fileText,
              title: 'Reports',
              subtitle: 'Generated Google Docs progress reports',
              unlocked: enforcement.canAccessGoogleIntegrations,
              onTap: () => context.push('/reports'),
              last: true,
            ),

            if (kDebugMode) ...[
              const SizedBox(height: AppSpacing.xl),
              const _SectionLabel('Debug'),
              _Row(
                icon: AppIcons.bug,
                title: 'Seed dev data',
                subtitle: 'For ekmekarasitutun@gmail.com',
                onTap: () => context.push('/dev-seed'),
                last: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Kicker(label, color: c.muted),
    );
  }
}

/// One row.
///
/// Flush on a fading rule, not a card — a screen of eleven cards is eleven
/// boxes, and the sections already group them. The old tinted icon chip is
/// gone with the rest of the coloured chips.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.unlocked = true,
    this.requiredPlanName = 'Complete',
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool unlocked;
  final String requiredPlanName;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            // A locked row routes to /pricing instead of opening the module
            // and showing its lock screen — the row already displays the
            // lock, so the tap should go where the lock is resolved.
            onTap: unlocked ? onTap : () => context.push('/pricing'),
            splashColor: c.accentTint(0.10),
            highlightColor: c.accentTint(0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: unlocked ? c.inkAccent : c.muted,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppType.title.copyWith(
                            color: unlocked ? c.text : c.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppType.note.copyWith(color: c.note),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (unlocked)
                    Icon(AppIcons.caretRight, size: 14, color: c.chevron)
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.lockSimple,
                          size: 12,
                          color: c.inkAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          requiredPlanName,
                          style: AppType.metaSmall.copyWith(
                            color: c.inkAccent,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        if (!last) const FadingRule(),
      ],
    );
  }
}
