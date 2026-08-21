import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/subscription_providers.dart';
import 'widgets/plan_limit_dialog.dart';

/// The single place that decides whether "create a habit / task / goal" is
/// allowed, and what to show when it isn't.
///
/// These used to live inline on the Habits, Tasks and Goals screens, which
/// meant every *other* entry point was ungated: the Dashboard's "Add habit",
/// "Add task" and "Add goal" quick actions pushed the create routes directly,
/// so a Starter user could sail past both the habit/task count limits and
/// the Growth-only goal planner just by starting from the dashboard.
///
/// Routing every entry point through these functions is what keeps that from
/// silently coming back the next time a shortcut is added.
class GuardedCreate {
  const GuardedCreate._();

  static Future<void> habit(BuildContext context, WidgetRef ref) async {
    final enforcement = ref.read(planEnforcementProvider);
    if (!enforcement.canCreateHabit) {
      await showPlanLimitDialog(
        context,
        message:
            'The ${enforcement.plan.name} plan allows up to '
            '${enforcement.plan.limits.maxActiveHabits} active habits. '
            'Upgrade to Growth for unlimited habits.',
        requiredPlanName: 'Growth',
      );
      return;
    }
    if (context.mounted) context.push('/habits/new');
  }

  static Future<void> task(BuildContext context, WidgetRef ref) async {
    final enforcement = ref.read(planEnforcementProvider);
    if (!enforcement.canCreateTask) {
      await showPlanLimitDialog(
        context,
        message:
            'The ${enforcement.plan.name} plan allows up to '
            '${enforcement.plan.limits.maxActiveTasks} active tasks. '
            'Upgrade to Growth for unlimited tasks.',
        requiredPlanName: 'Growth',
      );
      return;
    }
    if (context.mounted) context.push('/tasks/new');
  }

  static Future<void> reminder(BuildContext context, WidgetRef ref) async {
    // Reminders are currently available on all plans; no enforcement check.
    if (context.mounted) context.push('/reminders/new');
  }

  /// Goals are gated by module access rather than a count, so this shows the
  /// upgrade prompt for the Goal planner instead of a limit dialog.
  static Future<void> goal(BuildContext context, WidgetRef ref) async {
    final enforcement = ref.read(planEnforcementProvider);
    if (!enforcement.canAccessGoalPlanner) {
      await showPlanLimitDialog(
        context,
        message:
            'The goal planner is part of the Growth plan. '
            'Break big goals into milestones and connect them to your daily habits and tasks.',
        requiredPlanName: 'Growth',
      );
      return;
    }
    if (context.mounted) context.push('/goals/new');
  }
}
