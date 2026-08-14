import { HttpsError, onCall } from "firebase-functions/v2/https";
import Stripe from "stripe";

import { db } from "../lib/admin";
import { stripeSecretKey } from "../lib/secrets";
import { planIdFromPriceId } from "./priceMapping";

/**
 * Whether a checkout redirect target is one of ours.
 *
 * Stripe's hosted page will redirect anywhere it's told, so unvalidated
 * success/cancel URLs turn the checkout domain into an open redirector that
 * can be used as a hop in a phishing chain. Origins come from
 * APP_ALLOWED_ORIGINS (comma-separated) — see functions/.env.example.
 */
function isAllowedRedirect(url: string): boolean {
  const allowed = (process.env.APP_ALLOWED_ORIGINS ?? "")
    .split(",")
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);
  if (allowed.length === 0) return false;

  try {
    return allowed.includes(new URL(url).origin);
  } catch {
    return false;
  }
}

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
export const createStripeCheckoutSession = onCall({ secrets: [stripeSecretKey] }, async (request) => {
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

  // Derived from priceId server-side (never trust a client-supplied planId)
  // so the webhook knows exactly which plan was purchased without having to
  // fetch/expand line items later.
  //
  // Rejecting an unrecognised price is the important half: `priceId` comes
  // straight from the client, so without this check any other recurring
  // price in the Stripe account could be used to buy a plan at the wrong
  // price.
  const planId = planIdFromPriceId(priceId);
  if (!planId) {
    throw new HttpsError("invalid-argument", "Unknown priceId.");
  }

  if (!isAllowedRedirect(successUrl) || !isAllowedRedirect(cancelUrl)) {
    throw new HttpsError("invalid-argument", "successUrl/cancelUrl must be an app URL.");
  }

  const stripe = getStripeClient();
  const session = await stripe.checkout.sessions.create({
    mode: "subscription",
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: successUrl,
    cancel_url: cancelUrl,
    client_reference_id: uid,
    subscription_data: { metadata: { uid, planId } },
    metadata: { uid, planId },
    // Stamped on the Customer as well, so createStripePortalSession can find
    // it. Without this the portal lookup below never matched anything and
    // every user got "No Stripe customer found".
    customer_creation: "always",
  });

  if (!session.url) throw new HttpsError("internal", "Stripe did not return a checkout URL.");
  return { url: session.url };
});

/** Opens Stripe's hosted "manage my subscription" portal for the caller. */
export const createStripePortalSession = onCall({ secrets: [stripeSecretKey] }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

  const { returnUrl } = request.data as { returnUrl?: unknown };
  if (typeof returnUrl !== "string") {
    throw new HttpsError("invalid-argument", "Missing returnUrl.");
  }

  if (!isAllowedRedirect(returnUrl)) {
    throw new HttpsError("invalid-argument", "returnUrl must be an app URL.");
  }

  // Read the customer id the webhook stored, rather than searching Stripe by
  // metadata. The old search could never match — metadata was only ever set
  // on the Session and Subscription, never on the Customer — so this call
  // always failed with "No Stripe customer found", making subscriptions
  // unmanageable in-app. It also interpolated `uid` into a Stripe Search
  // Query Language string with no escaping.
  const snapshot = await db
    .collection("users")
    .doc(uid)
    .collection("subscription")
    .doc("status")
    .get();
  const customerId = snapshot.data()?.stripeCustomerId as string | undefined;
  if (!customerId) {
    throw new HttpsError("failed-precondition", "No Stripe customer found for this user yet.");
  }

  const stripe = getStripeClient();
  const session = await stripe.billingPortal.sessions.create({
    customer: customerId,
    return_url: returnUrl,
  });

  return { url: session.url };
});
