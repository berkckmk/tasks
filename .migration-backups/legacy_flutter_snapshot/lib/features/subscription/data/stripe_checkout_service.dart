import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/billing_product_ids.dart';
import '../domain/billing_service.dart';
import '../domain/purchase_result.dart';

/// Real Stripe integration for web, using Stripe's hosted Checkout page
/// (redirect-based, not embedded card fields) — no card data ever touches
/// this app or its client-side code, Stripe handles that entirely on their
/// domain. Not the active default yet — see the comment on
/// `billingServiceProvider` in subscription_providers.dart.
///
/// Completion is NOT handled here: after checkout, Stripe calls
/// `handleBillingWebhook` (functions/src/billing/webhook.ts), which verifies
/// the event signature and only then updates `subscription/status`. This
/// class just starts the flow and redirects.
class StripeCheckoutService implements BillingService {
  StripeCheckoutService(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<PurchaseResult> purchasePlan(String planId, {required bool yearly}) async {
    final priceId = BillingProductIds.stripePriceIds[planId];
    if (priceId == null) {
      return PurchaseResult(
        status: PurchaseResultStatus.error,
        message: 'No Stripe price configured for "$planId".',
      );
    }

    try {
      final origin = Uri.base.origin;
      final result =
          await _functions.httpsCallable('createStripeCheckoutSession').call<Map<String, dynamic>>({
        'priceId': priceId,
        'successUrl': '$origin/pricing?checkout=success',
        'cancelUrl': '$origin/pricing?checkout=cancelled',
      });

      final url = result.data['url'] as String?;
      if (url == null) {
        return const PurchaseResult(
          status: PurchaseResultStatus.error,
          message: 'Could not start checkout.',
        );
      }

      await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
      return const PurchaseResult(
        status: PurchaseResultStatus.pending,
        message: 'Redirecting to Stripe Checkout...',
      );
    } catch (e) {
      return PurchaseResult(status: PurchaseResultStatus.error, message: 'Checkout failed: $e');
    }
  }

  @override
  Future<PurchaseResult> restorePurchases() async {
    return const PurchaseResult(
      status: PurchaseResultStatus.error,
      message: 'Not applicable for Stripe — use "Manage subscription" instead.',
    );
  }

  @override
  Future<void> openManageSubscription() async {
    try {
      final result =
          await _functions.httpsCallable('createStripePortalSession').call<Map<String, dynamic>>({
        'returnUrl': Uri.base.origin,
      });
      final url = result.data['url'] as String?;
      if (url != null) {
        await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
      }
    } catch (_) {
      // Best-effort — surfacing this failure isn't critical enough to
      // block the caller; the portal button just won't navigate.
    }
  }
}
