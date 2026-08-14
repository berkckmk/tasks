import 'subscription_status.dart';

abstract class SubscriptionRepository {
  Stream<SubscriptionStatus?> watchStatus(String uid);

  /// Called once, right after sign-up — defaults every new user to Starter.
  /// Takes `uid` directly (rather than reading it from auth state) so it
  /// can be called the instant sign-up succeeds, before the reactive auth
  /// state stream has necessarily caught up.
  Future<void> createInitialStatus(String uid);

  /// Called by [BillingService] implementations once a purchase is
  /// confirmed (today, that's immediately — see DevBillingService).
  Future<void> setPlan({required String uid, required String planId, required String billingProvider});
}
