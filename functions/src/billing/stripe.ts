import { HttpsError, onCall } from "firebase-functions/v2/https";
import Stripe from "stripe";

function getStripeClient(): Stripe {
  const secretKey = process.env.STRIPE_SECRET_KEY;
  if (!secretKey) {
    throw new HttpsError(
      "failed-precondition",
      "Stripe is not configured on the server. See functions/.env.example."
    );
  }
  return new Stripe(secretKey);
}

/**
 * Starts a Stripe Checkout session (hosted page — no card data touches this
 * app). The client just redirects to the returned URL; completion is
 * handled entirely by handleBillingWebhook, not by this call's return
 * value, since the user might close the tab before finishing checkout.
 */
export const createStripeCheckoutSession = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

  const { priceId, successUrl, cancelUrl } = request.data as {
    priceId?: unknown;
    successUrl?: unknown;
    cancelUrl?: unknown;
  };
  if (
    typeof priceId !== "string" ||
    typeof successUrl !== "string" ||
    typeof cancelUrl !== "string"
  ) {
    throw new HttpsError("invalid-argument", "Missing priceId/successUrl/cancelUrl.");
  }

  const stripe = getStripeClient();
  const session = await stripe.checkout.sessions.create({
    mode: "subscription",
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: successUrl,
    cancel_url: cancelUrl,
    client_reference_id: uid,
    subscription_data: { metadata: { uid } },
    metadata: { uid },
  });

  if (!session.url) throw new HttpsError("internal", "Stripe did not return a checkout URL.");
  return { url: session.url };
});

/** Opens Stripe's hosted "manage my subscription" portal for the caller. */
export const createStripePortalSession = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

  const { returnUrl } = request.data as { returnUrl?: unknown };
  if (typeof returnUrl !== "string") {
    throw new HttpsError("invalid-argument", "Missing returnUrl.");
  }

  const stripe = getStripeClient();
  // A production implementation should look up this user's stored Stripe
  // customer ID (saved on subscription/status by the webhook) rather than
  // searching by metadata on every call — searches are eventually
  // consistent and rate-limited.
  const customers = await stripe.customers.search({ query: `metadata['uid']:'${uid}'` });
  const customer = customers.data[0];
  if (!customer) {
    throw new HttpsError("failed-precondition", "No Stripe customer found for this user yet.");
  }

  const session = await stripe.billingPortal.sessions.create({
    customer: customer.id,
    return_url: returnUrl,
  });

  return { url: session.url };
});
