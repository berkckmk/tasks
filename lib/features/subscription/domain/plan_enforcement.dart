import '../../pricing/domain/plan.dart';
import '../../pricing/domain/plan_module.dart';

/// Answers every "can the user do X?" question the app needs, computed from
/// the user's current [plan] plus how many habits/tasks they already have.
/// Pure and synchronous — see `planEnforcementProvider` for how it's kept
/// live against Firestore.
class PlanEnforcement {
  const PlanEnforcement({
    required this.plan,
    required this.activeHabitCount,
    required this.activeTaskCount,
  });

  final Plan plan;

  /// `null` while the habit/task stream hasn't produced a value yet (or has
  /// errored). Treated as "unknown", not as zero — see [_withinLimit].
  final int? activeHabitCount;
  final int? activeTaskCount;

  bool get canCreateHabit => _withinLimit(plan.limits.maxActiveHabits, activeHabitCount);

  bool get canCreateTask => _withinLimit(plan.limits.maxActiveTasks, activeTaskCount);

  bool get canAccessGoalPlanner => canAccessModule(PlanModule.goalPlanner);

  bool get canAccessAdvancedAnalytics => canAccessModule(PlanModule.advancedAnalytics);

  bool get canAccessFinanceTracker => canAccessModule(PlanModule.financeTracker);

  bool get canAccessWorkoutTracker => canAccessModule(PlanModule.workoutTracker);

  bool get canAccessLearningTracker => canAccessModule(PlanModule.learningTracker);

  bool get canAccessContentPlanner => canAccessModule(PlanModule.contentPlanner);

  bool get canAccessGoogleIntegrations => canAccessModule(PlanModule.googleIntegrations);

  bool canAccessModule(PlanModule module) => plan.hasModule(module);

  /// Unlimited plans (`limit == null`) always pass. Otherwise an unknown
  /// count fails closed: offering "add habit" on a still-loading list would
  /// just produce a `resource-exhausted` error from the createHabit Cloud
  /// Function instead of the upgrade dialog the user should see.
  static bool _withinLimit(int? limit, int? count) {
    if (limit == null) return true;
    if (count == null) return false;
    return count < limit;
  }
}
