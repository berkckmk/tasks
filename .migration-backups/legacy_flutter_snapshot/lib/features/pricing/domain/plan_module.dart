/// Gated features that require a specific plan. Checked via
/// `PlanEnforcement.canAccessModule` — see
/// `features/subscription/domain/plan_enforcement.dart`.
enum PlanModule {
  goalPlanner,
  advancedAnalytics,
  financeTracker,
  workoutTracker,
  learningTracker,
  contentPlanner,
  googleIntegrations,
}
