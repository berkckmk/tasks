import 'package:flutter_test/flutter_test.dart';

import 'package:steady_progress/features/pricing/data/plan_catalog.dart';
import 'package:steady_progress/features/subscription/domain/plan_enforcement.dart';
import 'package:steady_progress/features/subscription/domain/subscription_status.dart';

SubscriptionStatus _status({
  String planId = 'complete',
  SubscriptionState state = SubscriptionState.active,
  DateTime? expiresAt,
  DateTime? trialEndsAt,
}) =>
    SubscriptionStatus(
      planId: planId,
      status: state,
      startedAt: DateTime(2026, 1, 1),
      expiresAt: expiresAt,
      billingProvider: 'stripe',
      isTrialActive: state == SubscriptionState.trialing,
      trialEndsAt: trialEndsAt,
    );

void main() {
  final now = DateTime(2026, 8, 14);

  group('SubscriptionStatus.isEntitledAt', () {
    test('an active subscription with no expiry is entitled', () {
      expect(_status().isEntitledAt(now), isTrue);
    });

    test('expired and canceled are never entitled', () {
      expect(_status(state: SubscriptionState.expired).isEntitledAt(now), isFalse);
      expect(_status(state: SubscriptionState.canceled).isEntitledAt(now), isFalse);
    });

    test('an active subscription stops at expiresAt', () {
      expect(_status(expiresAt: DateTime(2026, 8, 15)).isEntitledAt(now), isTrue);
      expect(_status(expiresAt: DateTime(2026, 8, 13)).isEntitledAt(now), isFalse);
    });

    test('a trial stops at trialEndsAt', () {
      expect(
        _status(state: SubscriptionState.trialing, trialEndsAt: DateTime(2026, 8, 20))
            .isEntitledAt(now),
        isTrue,
      );
      expect(
        _status(state: SubscriptionState.trialing, trialEndsAt: DateTime(2026, 8, 1))
            .isEntitledAt(now),
        isFalse,
      );
    });
  });

  group('resolveActivePlanId', () {
    // These pin the *non-beta* behaviour, which is what ships when
    // kBetaAllAccess is turned off. They're written against isEntitledAt
    // directly so they stay meaningful while the beta flag is on.
    test('a lapsed subscription resolves to starter, not its stored plan', () {
      final lapsed = _status(planId: 'complete', expiresAt: DateTime(2026, 8, 1));
      expect(lapsed.planId, 'complete');
      expect(lapsed.isEntitledAt(now), isFalse,
          reason: 'stored planId must not be trusted once the period has lapsed');
    });
  });

  group('PlanEnforcement limits', () {
    final starter = planById('starter');
    final complete = planById('complete');

    test('starter blocks creation at its limit', () {
      expect(
        PlanEnforcement(plan: starter, activeHabitCount: 2, activeTaskCount: 0).canCreateHabit,
        isTrue,
      );
      expect(
        PlanEnforcement(plan: starter, activeHabitCount: 3, activeTaskCount: 0).canCreateHabit,
        isFalse,
      );
      expect(
        PlanEnforcement(plan: starter, activeHabitCount: 0, activeTaskCount: 20).canCreateTask,
        isFalse,
      );
    });

    test('an unlimited plan ignores the counts entirely', () {
      expect(
        PlanEnforcement(plan: complete, activeHabitCount: 9999, activeTaskCount: 9999)
            .canCreateHabit,
        isTrue,
      );
    });

    test('an unknown count fails closed on a limited plan', () {
      // Loading/errored streams used to collapse to 0, which reads as "well
      // under the limit" and offered a create button the server would reject.
      final loading = PlanEnforcement(plan: starter, activeHabitCount: null, activeTaskCount: null);
      expect(loading.canCreateHabit, isFalse);
      expect(loading.canCreateTask, isFalse);
    });

    test('an unknown count still passes on an unlimited plan', () {
      final loading = PlanEnforcement(plan: complete, activeHabitCount: null, activeTaskCount: null);
      expect(loading.canCreateHabit, isTrue);
      expect(loading.canCreateTask, isTrue);
    });
  });
}
