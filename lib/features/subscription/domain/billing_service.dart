import 'purchase_result.dart';

/// The seam for real payments. Every screen in the app talks to this
/// interface — never to a payment SDK directly — so swapping in Stripe,
/// RevenueCat, Google Play Billing, Lemon Squeezy, or Paddle later is a
/// single provider override (see `billingServiceProvider`), not a UI
/// rewrite. See DevBillingService for the current placeholder and notes on
/// what a real implementation needs to do differently.
abstract class BillingService {
  Future<PurchaseResult> purchasePlan(String planId, {required bool yearly});

  Future<PurchaseResult> restorePurchases();

  /// Opens the platform's subscription management surface (Play Store
  /// subscriptions, App Store, or the billing provider's customer portal).
  Future<void> openManageSubscription();
}
