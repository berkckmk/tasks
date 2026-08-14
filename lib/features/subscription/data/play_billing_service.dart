import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../domain/billing_product_ids.dart';
import '../domain/billing_service.dart';
import '../domain/purchase_result.dart';

/// Real Google Play Billing integration via `in_app_purchase`. Not the
/// active default yet — see the comment on `billingServiceProvider` in
/// subscription_providers.dart for how to switch over once Play Console is
/// actually configured. Until then, calling this against an unregistered
/// product ID returns a clear "not configured" error instead of crashing.
///
/// Purchases are never trusted client-side: every successful purchase is
/// verified server-side by the `verifyPlayPurchase` Cloud Function (which
/// calls the Android Publisher API) before `subscription/status` is
/// updated — the client only finds out the *result* of that verification.
class PlayBillingService implements BillingService {
  PlayBillingService(this._functions) {
    _subscription = _iap.purchaseStream.listen(_onPurchaseUpdate);
  }

  final FirebaseFunctions _functions;
  final InAppPurchase _iap = InAppPurchase.instance;
  late final StreamSubscription<List<PurchaseDetails>> _subscription;
  Completer<PurchaseResult>? _pendingPurchase;

  @override
  Future<PurchaseResult> purchasePlan(String planId, {required bool yearly}) async {
    final productId = BillingProductIds.playProductIds[planId];
    if (productId == null) {
      return PurchaseResult(
        status: PurchaseResultStatus.error,
        message: 'No Play product configured for "$planId".',
      );
    }

    if (!await _iap.isAvailable()) {
      return const PurchaseResult(
        status: PurchaseResultStatus.error,
        message: 'Google Play Billing is unavailable on this device.',
      );
    }

    final response = await _iap.queryProductDetails({productId});
    if (response.notFoundIDs.contains(productId) || response.productDetails.isEmpty) {
      return PurchaseResult(
        status: PurchaseResultStatus.error,
        message: 'Product "$productId" isn\'t set up in Play Console yet.',
      );
    }

    _pendingPurchase = Completer<PurchaseResult>();
    final started = await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: response.productDetails.first),
    );
    if (!started) {
      final completer = _pendingPurchase;
      _pendingPurchase = null;
      completer?.complete(
        const PurchaseResult(status: PurchaseResultStatus.error, message: 'Could not start the purchase.'),
      );
    }

    return _pendingPurchase?.future ??
        const PurchaseResult(status: PurchaseResultStatus.error, message: 'Could not start the purchase.');
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;

      PurchaseResult? result;
      if (purchase.status == PurchaseStatus.error) {
        result = PurchaseResult(
          status: PurchaseResultStatus.error,
          message: purchase.error?.message ?? 'Purchase failed.',
        );
      } else if (purchase.status == PurchaseStatus.canceled) {
        result = const PurchaseResult(status: PurchaseResultStatus.cancelled);
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        result = await _verifyPurchase(purchase);
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }

      if (result != null) {
        _pendingPurchase?.complete(result);
        _pendingPurchase = null;
      }
    }
  }

  Future<PurchaseResult> _verifyPurchase(PurchaseDetails purchase) async {
    try {
      final result = await _functions.httpsCallable('verifyPlayPurchase').call<Map<String, dynamic>>({
        'productId': purchase.productID,
        'purchaseToken': purchase.verificationData.serverVerificationData,
      });
      final granted = result.data['granted'] == true;
      return granted
          ? const PurchaseResult(status: PurchaseResultStatus.success, message: 'Plan updated.')
          : const PurchaseResult(
              status: PurchaseResultStatus.error,
              message: "Purchase couldn't be verified.",
            );
    } catch (e) {
      return PurchaseResult(status: PurchaseResultStatus.error, message: 'Verification failed: $e');
    }
  }

  @override
  Future<PurchaseResult> restorePurchases() async {
    await _iap.restorePurchases();
    return const PurchaseResult(
      status: PurchaseResultStatus.pending,
      message: 'Checking for previous purchases...',
    );
  }

  @override
  Future<void> openManageSubscription() async {
    // Deep link target for a real implementation:
    // https://play.google.com/store/account/subscriptions
  }

  void dispose() => _subscription.cancel();
}
