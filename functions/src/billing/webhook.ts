import { onRequest } from "firebase-functions/v2/https";
import Stripe from "stripe";

import { db } from "../lib/admin";
import { planIdFromPriceId } from "./priceMapping";

async function setSubscriptionPlan(
  uid: string,
  planId: string,
  status: "active" | "expired",
  stripeSubscriptionId: string | null
): Promise<void> {
  await db
    .collection("users")
    .doc(uid)
    .collection("subscription")
    .doc("status")
    .set(
      {
        planId: status === "active" ? planId : "starter",
        status: "active",
        billingProvider: "stripe",
        startedAt: new Date(),
        stripeSubscriptionId,
      },
      { merge: true }
    );
}

/**
 * Stripe webhook — the ONLY place, once this is live, that should be
 * allowed to write `subscription/status` for a paid plan. THE critical
 * rule: verify the signature before trusting anything in the request body.
 * Without this, anyone who found this URL could POST a fake
 * "subscription active" event and grant themselves a paid plan for free —
 * see the matching warning on DevBillingService in the Flutter app.
 */
export const handleBillingWebhook = onRequest(async (req, res) => {
  const secretKey = process.env.STRIPE_SECRET_KEY;
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!secretKey || !webhookSecret) {
    res.status(501).json({ error: "Stripe is not configured. See functions/.env.example." });
    return;
  }

  const stripe = new Stripe(secretKey);
  const signature = req.headers["stripe-signature"];

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(req.rawBody, signature as string, webhookSecret);
  } catch (error) {
    console.error("Stripe webhook signature verification failed:", error);
    res.status(400).send("Invalid signature");
    return;
  }

  switch (event.type) {
    case "checkout.session.completed": {
      const session = event.data.object as Stripe.Checkout.Session;
      const uid = session.client_reference_id ?? session.metadata?.uid;
      if (uid) {
        // planId is stamped into metadata by createStripeCheckoutSession at
        // session-creation time (derived server-side from the price the
        // user actually checked out with) — NOT hardcoded, so a Complete
        // purchase doesn't get silently downgraded to Growth. The fallback
        // only matters for a session created before this field existed.
        const planId = session.metadata?.planId ?? "growth";
        await setSubscriptionPlan(
          uid,
          planId,
          "active",
          typeof session.subscription === "string" ? session.subscription : null
        );
      }
      break;
    }
    case "customer.subscription.updated":
    case "customer.subscription.deleted": {
      const subscription = event.data.object as Stripe.Subscription;
      const uid = subscription.metadata?.uid;
      if (uid) {
        const isActive = subscription.status === "active" || subscription.status === "trialing";
        const priceId = subscription.items.data[0]?.price?.id;
        await setSubscriptionPlan(
          uid,
          planIdFromPriceId(priceId),
          isActive ? "active" : "expired",
          subscription.id
        );
      }
      break;
    }
    default:
      break;
  }

  res.status(200).json({ received: true });
});
