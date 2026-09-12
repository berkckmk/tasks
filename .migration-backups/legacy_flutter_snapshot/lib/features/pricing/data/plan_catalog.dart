import '../domain/plan.dart';
import '../domain/plan_limits.dart';
import '../domain/plan_module.dart';

// TODO(remote-config): This is intentionally a static list for now ("Admin/
// config readiness" — plan definitions should be easy to update remotely
// later). To make plans editable without a release, replace the body of
// `planCatalogProvider` (see application/plan_providers.dart) with a
// FutureProvider/StreamProvider reading a `plan_configs` Firestore
// collection or a Firebase Remote Config value shaped like this list — no
// other code needs to change, since everything reads plans through that
// provider.
const List<Plan> planCatalog = [
  Plan(
    id: 'starter',
    name: 'Starter',
    priceMonthly: 0,
    priceYearly: 0,
    isPopular: false,
    limits: PlanLimits(maxActiveHabits: 3, maxActiveTasks: 20),
    moduleAccess: {},
    features: [
      'Max 3 active habits',
      'Max 20 active tasks',
      'Basic dashboard',
      'Basic weekly planner',
    ],
  ),
  Plan(
    id: 'growth',
    name: 'Growth',
    priceMonthly: 6,
    priceYearly: 60,
    isPopular: true,
    limits: PlanLimits(),
    moduleAccess: {PlanModule.goalPlanner, PlanModule.advancedAnalytics},
    features: [
      'Everything in Starter',
      'Unlimited habits',
      'Unlimited tasks',
      'Goal planner',
      'Progress analytics',
      'Reminders (coming soon)',
      'Monthly review',
    ],
  ),
  Plan(
    id: 'complete',
    name: 'Complete',
    priceMonthly: 12,
    priceYearly: 120,
    isPopular: false,
    limits: PlanLimits(),
    moduleAccess: {
      PlanModule.goalPlanner,
      PlanModule.advancedAnalytics,
      PlanModule.financeTracker,
      PlanModule.workoutTracker,
      PlanModule.learningTracker,
      PlanModule.contentPlanner,
      PlanModule.googleIntegrations,
    },
    features: [
      'Everything in Growth',
      'Finance tracker',
      'Workout tracker',
      'Learning tracker',
      'Content planner',
      'Side hustle planner (coming soon)',
      'Future Google integrations',
      'Advanced reports',
    ],
  ),
];

Plan planById(String id) => planCatalog.firstWhere(
      (p) => p.id == id,
      orElse: () => planCatalog.first,
    );
