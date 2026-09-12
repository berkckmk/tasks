import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/play_billing_service.dart';
import '../data/stripe_checkout_service.dart';
import '../domain/beta_access.dart';
import '../domain/billing_service.dart';
import '../domain/purchase_result.dart';

/// The billing implementation used while [kBetaAllAccess] is on.
///
/// It cannot grant anything, and that's the point: entitlement lives in
/// `users/{uid}/subscription/status`, which firestore.rules now makes
/// Admin-SDK-only. The previous stub wrote that document straight from the
/// client, which is exactly the hole that made every server-side plan check
/// bypassable. During the beta nobody needs to buy anything anyway — every
/// account already resolves to the Complete plan.
class BetaBillingService implements BillingService {
  const BetaBillingService();

  @override
  Future<PurchaseResult> purchasePlan(String planId, {required bool yearly}) async {
    return const PurchaseResult(
      status: PurchaseResultStatus.success,
      message: "You're in the closed beta — every feature is already unlocked, free of charge.",
    );
  }

  @override
  Future<PurchaseResult> restorePurchases() async {
    return const PurchaseResult(
      status: PurchaseResultStatus.success,
      message: 'Nothing to restore — the closed beta unlocks everything already.',
    );
  }

  @override
  Future<void> openManageSubscription() async {
    // No subscription to manage during the beta.
  }
}

// This is the ONE place that decides who actually handles a purchase.
//
// While kBetaAllAccess is on, that's BetaBillingService — nobody is charged
// and every account is on Complete regardless of what this returns.
//
// PlayBillingService (Android, real Play Billing via `in_app_purchase`) and
// StripeCheckoutService (Web, real Stripe Checkout redirect) are complete
// and stay compiled in; both route entitlement through a Cloud Function that
// verifies with the provider before the Admin SDK writes subscription/status.
// To go live: turn off the three kBetaAllAccess mirrors (see beta_access.dart),
// fill in the real product/price IDs in domain/billing_product_ids.dart, and
// delete the `kBetaAllAccess` branch below.
final billingServiceProvider = Provider<BillingService>((ref) {
  if (kBetaAllAccess) return const BetaBillingService();
  final functions = ref.watch(firebaseFunctionsProvider);
  return kIsWeb ? StripeCheckoutService(functions) : PlayBillingService(functions);
});
