import 'subscription_status.dart';

abstract class SubscriptionRepository {
  Stream<SubscriptionStatus?> watchStatus(String uid);

  /// Called once, right after sign-up — defaults every new user to Starter.
  /// Takes `uid` directly (rather than reading it from auth state) so it
  /// can be called the instant sign-up succeeds, before the reactive auth
  /// state stream has necessarily caught up.
  Future<void> createInitialStatus(String uid);

  // There is deliberately no `setPlan` here. Entitlement is written only by
  // the Admin SDK — handleBillingWebhook (Stripe signature verified) and
  // verifyPlayPurchase (Play Developer API verified) — and firestore.rules
  // denies `update` on subscription/status outright, so a client-side setter
  // could not succeed even if something called it. Plan changes reach the
  // app by flowing back down through [watchStatus].
}
