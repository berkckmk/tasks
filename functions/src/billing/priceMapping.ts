/**
 * Server-side source of truth for "which Stripe price is which plan" —
 * shared by createStripeCheckoutSession (to validate the requested price and
 * stamp the plan into session metadata at creation time) and the webhook (as
 * a fallback for events that only carry a price ID, like subscription
 * updates). Deriving this server-side — rather than trusting a
 * client-supplied `planId` alongside `priceId` — is what stops a client from
 * requesting checkout for the cheap price while claiming the expensive plan.
 *
 * Returns null for anything unrecognised, and every caller treats that as a
 * refusal. This used to default to "growth", which failed *open* in two
 * ways: a caller could check out with any other recurring price in the
 * Stripe account (a $1 test price, a legacy discounted price) and be granted
 * Growth, and if the STRIPE_PRICE_* env vars were unset in an environment,
 * every price mapped to Growth — silently downgrading real Complete
 * subscribers on their next subscription.updated event.
 */
export function planIdFromPriceId(priceId: string | undefined): string | null {
  if (!priceId) return null;

  const growth = process.env.STRIPE_PRICE_GROWTH;
  const complete = process.env.STRIPE_PRICE_COMPLETE;

  if (growth && priceId === growth) return "growth";
  if (complete && priceId === complete) return "complete";
  return null;
}

/** Every price ID this deployment recognises. Empty if Stripe isn't configured. */
export function configuredPriceIds(): string[] {
  return [process.env.STRIPE_PRICE_GROWTH, process.env.STRIPE_PRICE_COMPLETE].filter(
    (value): value is string => typeof value === "string" && value.length > 0
  );
}
