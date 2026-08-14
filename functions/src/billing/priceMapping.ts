/**
 * Server-side source of truth for "which Stripe price is which plan" —
 * shared by createStripeCheckoutSession (to stamp the plan into session
 * metadata at creation time) and the webhook (as a fallback for events
 * that only carry a price ID, like subscription updates). Deriving this
 * server-side — rather than trusting a client-supplied `planId` alongside
 * `priceId` — is what stops a client from requesting checkout for the
 * cheap price while claiming the expensive plan.
 */
export function planIdFromPriceId(priceId: string | undefined): string {
  if (!priceId) return "growth";
  const map: Record<string, string> = {
    [process.env.STRIPE_PRICE_GROWTH ?? "__unset_growth__"]: "growth",
    [process.env.STRIPE_PRICE_COMPLETE ?? "__unset_complete__"]: "complete",
  };
  return map[priceId] ?? "growth";
}
