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
final currentPlanProvider = Provider<Plan>((ref) {
  final planId = ref.watch(subscriptionStatusProvider).valueOrNull?.planId ?? 'starter';
  return planById(planId);
});

final planEnforcementProvider = Provider<PlanEnforcement>((ref) {
  final plan = ref.watch(currentPlanProvider);
  final activeHabitCount = ref.watch(habitsProvider).valueOrNull?.length ?? 0;
  final activeTaskCount =
      ref.watch(tasksProvider).valueOrNull?.where((t) => !t.isDone).length ?? 0;
  return PlanEnforcement(
    plan: plan,
    activeHabitCount: activeHabitCount,
    activeTaskCount: activeTaskCount,
  );
});
