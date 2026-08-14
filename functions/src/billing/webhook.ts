import { onRequest } from "firebase-functions/v2/https";
import Stripe from "stripe";

import { db } from "../lib/admin";
import { stripeSecrets } from "../lib/secrets";
import { planIdFromPriceId } from "./priceMapping";

interface PlanUpdate {
  uid: string;
  planId: string;
  /** Mirrors SubscriptionState in the Flutter client. */
  status: "active" | "expired" | "canceled";
  stripeSubscriptionId: string | null;
  stripeCustomerId: string | null;
  expiresAt: Date | null;
}

async function setSubscriptionPlan(update: PlanUpdate): Promise<void> {
  const doc = db
    .collection("users")
    .doc(update.uid)
    .collection("subscription")
    .doc("status");

  // startedAt is only stamped when the document doesn't have one yet.
  // Rewriting it on every event destroyed the real start date each time
  // Stripe redelivered — and tenure/trial logic is computed from it.
  const existing = await doc.get();
  const startedAt = existing.data()?.startedAt ?? new Date();

  await doc.set(
    {
      planId: update.status === "active" ? update.planId : "starter",
      status: update.status,
      billingProvider: "stripe",
      startedAt,
      stripeSubscriptionId: update.stripeSubscriptionId,
      // Needed by createStripePortalSession — without it the "manage
      // subscription" flow has no customer to open the portal for.
      ...(update.stripeCustomerId ? { stripeCustomerId: update.stripeCustomerId } : {}),
      expiresAt: update.expiresAt,
      isTrialActive: false,
    },
    { merge: true }
  );
}

/**
 * Records that [eventId] has been handled, returning false if it already
 * had been.
 *
 * Stripe retries deliveries, and `constructEvent` accepts any correctly
 * signed body within its 300s tolerance, so the same event can legitimately
 * arrive more than once. The transaction makes the check atomic against two
 * concurrent redeliveries.
 */
async function claimEvent(eventId: string): Promise<boolean> {
  const ref = db.collection("stripeEvents").doc(eventId);
  return db.runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    if (existing.exists) return false;
    tx.set(ref, { handledAt: new Date() });
    return true;
  });
}

function idOf(value: string | { id: string } | null | undefined): string | null {
  if (!value) return null;
  return typeof value === "string" ? value : value.id;
}

/**
 * Stripe webhook — the ONLY place that may write `subscription/status` for a
 * paid plan (alongside verifyPlayPurchase). THE critical rule: verify the
 * signature before trusting anything in the request body. Without it, anyone
 * who found this URL could POST a fake "subscription active" event and grant
 * themselves a paid plan for free.
 */
export const handleBillingWebhook = onRequest(
  { secrets: stripeSecrets, memory: "256MiB", timeoutSeconds: 60 },
  async (req, res) => {
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

    try {
      if (!(await claimEvent(event.id))) {
        // Already processed. Ack so Stripe stops retrying.
        res.status(200).json({ received: true, duplicate: true });
        return;
      }

      await handleEvent(event);
      res.status(200).json({ received: true });
    } catch (error) {
      // Respond explicitly so Stripe retries, instead of leaving the request
      // hanging until the invocation times out.
      console.error(`Failed to handle Stripe event ${event.id}:`, error);
      res.status(500).json({ error: "Webhook handler failed." });
    }
  }
);

async function handleEvent(event: Stripe.Event): Promise<void> {
  switch (event.type) {
    case "checkout.session.completed": {
      const session = event.data.object as Stripe.Checkout.Session;
      const uid = session.client_reference_id ?? session.metadata?.uid;
      if (!uid) return;

      // Delayed-notification payment methods (SEPA, bacs, boleto) fire this
      // event while the payment is still `unpaid`. Granting on that gave a
      // free plan until a payment that might never clear.
      if (session.payment_status !== "paid") {
        console.log(`Session ${session.id} completed but payment_status=${session.payment_status}.`);
        return;
      }

      const planId = session.metadata?.planId;
      if (!planId) {
        console.error(`Session ${session.id} has no planId metadata; refusing to grant a plan.`);
        return;
      }

      await setSubscriptionPlan({
        uid,
        planId,
        status: "active",
        stripeSubscriptionId: idOf(session.subscription),
        stripeCustomerId: idOf(session.customer),
        expiresAt: null,
      });
      break;
    }

    case "checkout.session.async_payment_failed": {
      const session = event.data.object as Stripe.Checkout.Session;
      const uid = session.client_reference_id ?? session.metadata?.uid;
      if (!uid) return;
      await setSubscriptionPlan({
        uid,
        planId: "starter",
        status: "expired",
        stripeSubscriptionId: idOf(session.subscription),
        stripeCustomerId: idOf(session.customer),
        expiresAt: null,
      });
      break;
    }

    case "customer.subscription.updated":
    case "customer.subscription.deleted": {
      const subscription = event.data.object as Stripe.Subscription;
      const uid = subscription.metadata?.uid;
      if (!uid) return;

      const planId = planIdFromPriceId(subscription.items.data[0]?.price?.id);
      if (!planId) {
        // Fail closed: an unrecognised price used to resolve to "growth",
        // which silently downgraded Complete subscribers whenever the
        // STRIPE_PRICE_* env vars were missing.
        console.error(`Subscription ${subscription.id} has an unrecognised price; ignoring.`);
        return;
      }

      // `past_due`/`unpaid` mean Stripe is still retrying the charge. Cutting
      // access off at the first dunning attempt punished paying customers;
      // entitlement ends when the subscription is actually deleted, or when
      // the period it was paid for runs out (expiresAt below).
      const entitled = ["active", "trialing", "past_due", "unpaid"].includes(subscription.status);
      const periodEnd = subscription.current_period_end;

      await setSubscriptionPlan({
        uid,
        planId,
        status: entitled ? "active" : event.type === "customer.subscription.deleted" ? "canceled" : "expired",
        stripeSubscriptionId: subscription.id,
        stripeCustomerId: idOf(subscription.customer),
        expiresAt: entitled && periodEnd ? new Date(periodEnd * 1000) : null,
      });
      break;
    }

    default:
      break;
  }
}
