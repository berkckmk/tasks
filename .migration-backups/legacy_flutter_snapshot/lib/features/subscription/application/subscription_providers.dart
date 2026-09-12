import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../habits/application/habit_providers.dart';
import '../../pricing/data/plan_catalog.dart';
import '../../pricing/domain/plan.dart';
import '../../tasks/application/task_providers.dart';
import '../data/firestore_subscription_repository.dart';
import '../domain/plan_enforcement.dart';
import '../domain/subscription_repository.dart';
import '../domain/subscription_status.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return FirestoreSubscriptionRepository(ref.watch(firestoreProvider));
});

final subscriptionStatusProvider = StreamProvider<SubscriptionStatus?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(subscriptionRepositoryProvider).watchStatus(uid);
});

/// Defaults to Starter while the subscription doc is still loading (or for
/// a signed-out user), so gated UI never flashes an unlocked state.
/// [resolveActivePlanId] also downgrades a lapsed/cancelled subscription and
/// applies the closed-beta all-access override — see `domain/beta_access.dart`.
final currentPlanProvider = Provider<Plan>((ref) {
  final status = ref.watch(subscriptionStatusProvider).valueOrNull;
  return planById(resolveActivePlanId(status));
});

final planEnforcementProvider = Provider<PlanEnforcement>((ref) {
  final plan = ref.watch(currentPlanProvider);
  // `null` (still loading, or errored) is deliberately NOT collapsed to 0
  // here: a count of 0 would read as "well under the limit" and let the UI
  // offer a create button the server would then reject. PlanEnforcement
  // treats an unknown count as "can't confirm there's room" instead.
  final habitCount = ref.watch(habitsProvider).valueOrNull?.length;
  final taskCount = ref.watch(tasksProvider).valueOrNull?.where((t) => !t.isDone).length;
  return PlanEnforcement(
    plan: plan,
    activeHabitCount: habitCount,
    activeTaskCount: taskCount,
  );
});
