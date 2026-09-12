import { HttpsError } from "firebase-functions/v2/https";

import { db } from "./admin";

/**
 * Closed-beta switch — server-side mirror of `kBetaAllAccess` in
 * lib/features/subscription/domain/beta_access.dart. See that file for what
 * this is for and for the full list of places to flip when the beta ends
 * (this constant, the Dart one, and `betaAllAccess()` in firestore.rules).
 */
const BETA_ALL_ACCESS = true;
const BETA_PLAN_ID = "complete";

/**
 * Server-side mirror of PlanEnforcement
 * (lib/features/subscription/domain/plan_enforcement.dart). The Flutter
 * client's plan check only hides UI — it can't stop a signed-in user from
 * calling a Cloud Function directly with their own valid ID token. This is
 * what actually enforces plan gating for anything a Cloud Function does.
 *
 * Fails closed on every uncertain input: a missing subscription doc (e.g.
 * right after sign-up), a cancelled/expired one, or one whose `expiresAt`
 * has passed all resolve to "starter", never to a paid plan by accident.
 * That expiry check matters because nothing else revokes a plan — a Stripe
 * `customer.subscription.deleted` webhook that fails delivery, or a Play
 * purchase refunded out of band, would otherwise leave the plan granted
 * forever.
 */
export async function getUserPlanId(uid: string): Promise<string> {
  if (BETA_ALL_ACCESS) return BETA_PLAN_ID;

  const snapshot = await db.collection("users").doc(uid).collection("subscription").doc("status").get();
  const data = snapshot.data();
  if (!data) return "starter";

  const status = data.status as string | undefined;
  if (status === "expired" || status === "canceled") return "starter";

  const now = Date.now();
  const trialEndsAt = (data.trialEndsAt as FirebaseFirestore.Timestamp | undefined)?.toMillis();
  if (status === "trialing" && trialEndsAt !== undefined && now >= trialEndsAt) return "starter";

  const expiresAt = (data.expiresAt as FirebaseFirestore.Timestamp | undefined)?.toMillis();
  if (expiresAt !== undefined && now >= expiresAt) return "starter";

  return (data.planId as string | undefined) ?? "starter";
}

export async function assertPlan(uid: string, allowed: readonly string[]): Promise<void> {
  const planId = await getUserPlanId(uid);
  if (!allowed.includes(planId)) {
    throw new HttpsError(
      "permission-denied",
      `This feature requires one of: ${allowed.join(", ")}. Current plan: ${planId}.`
    );
  }
}
