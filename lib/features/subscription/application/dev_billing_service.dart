import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../auth/application/auth_providers.dart';
import '../domain/billing_service.dart';
import '../domain/purchase_result.dart';
import 'subscription_providers.dart';

/// Stand-in for a real payment provider. Instead of charging anyone, it
/// just writes the chosen plan straight to `subscription/status` — useful
/// for developing/testing the rest of the app before Stripe/Play Billing is
/// actually configured with real product/price IDs.
///
/// TODO(payments): a real implementation must NOT call
/// `SubscriptionRepository.setPlan` directly from the client like this one
/// does. Instead: kick off checkout with the provider's SDK, then let a
/// server-side webhook (verified against the provider) write
/// `subscription/status` — otherwise a user could grant themselves a paid
/// plan for free by calling this method directly.
class DevBillingService implements BillingService {
  DevBillingService(this._ref);

  final Ref _ref;

  @override
  Future<PurchaseResult> purchasePlan(String planId, {required bool yearly}) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) {
      return const PurchaseResult(
        status: PurchaseResultStatus.error,
        message: 'You need to be signed in to change plans.',
      );
    }

    final analytics = _ref.read(analyticsServiceProvider);
    await analytics.logPlanUpgradeAttempted(planId);

    final repository = _ref.read(subscriptionRepositoryProvider);
    await repository.setPlan(uid: uid, planId: planId, billingProvider: 'none');
    await analytics.logPlanUpgraded(planId);

    return const PurchaseResult(
      status: PurchaseResultStatus.success,
      message: 'Plan updated. (Dev mode — no real payment was charged.)',
    );
  }

  @override
  Future<PurchaseResult> restorePurchases() async {
    return const PurchaseResult(
      status: PurchaseResultStatus.error,
      message: "Restore purchases isn't available yet — no payment provider is connected.",
    );
  }

  @override
  Future<void> openManageSubscription() async {
    // No-op until a real billing provider is connected.
  }
}

// This is the ONE place that decides who actually handles a purchase.
//
// PlayBillingService (Android, real Play Billing via `in_app_purchase`) and
// StripeCheckoutService (Web, real Stripe Checkout redirect) already exist
// and are ready to use — see lib/features/subscription/data/. They are NOT
// wired in here yet because they need real product/price IDs configured in
// Play Console and the Stripe Dashboard first (see
// domain/billing_product_ids.dart) — pointing this provider at them before
// that setup exists would just replace working dev-mode plan switching with
// calls that fail with "not configured" errors.
//
// To go live: replace the body below with something like
//   if (kIsWeb) return StripeCheckoutService(ref.watch(firebaseFunctionsProvider));
//   return PlayBillingService(ref.watch(firebaseFunctionsProvider));
final billingServiceProvider = Provider<BillingService>((ref) => DevBillingService(ref));
