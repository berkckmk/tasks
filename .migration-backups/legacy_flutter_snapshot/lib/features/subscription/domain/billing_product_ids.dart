/// Product/price identifiers a real billing provider needs. These are
/// PLACEHOLDERS — they must match whatever you actually create in Play
/// Console (subscription products) and the Stripe Dashboard (prices)
/// before PlayBillingService/StripeCheckoutService can complete a real
/// purchase.
class BillingProductIds {
  BillingProductIds._();

  /// Google Play Console subscription product IDs.
  static const Map<String, String> playProductIds = {
    'growth': 'steady_progress_growth_monthly',
    'complete': 'steady_progress_complete_monthly',
  };

  /// Stripe price IDs (Dashboard > Product catalog > Prices).
  static const Map<String, String> stripePriceIds = {
    'growth': 'price_REPLACE_WITH_GROWTH_PRICE_ID',
    'complete': 'price_REPLACE_WITH_COMPLETE_PRICE_ID',
  };
}
