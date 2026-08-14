import { HttpsError } from "firebase-functions/v2/https";

import { db } from "./admin";

/**
 * Server-side mirror of PlanEnforcement
 * (lib/features/subscription/domain/plan_enforcement.dart). The Flutter
 * client's plan check only hides UI — it can't stop a signed-in user from
 * calling a Cloud Function directly with their own valid ID token. This is
 * what actually enforces plan gating for anything a Cloud Function does.
 *
 * Fails closed: a missing subscription doc (e.g. right after sign-up)
 * resolves to "starter", never to an allowed plan by accident.
 */
export async function getUserPlanId(uid: string): Promise<string> {
  const snapshot = await db.collection("users").doc(uid).collection("subscription").doc("status").get();
  return (snapshot.data()?.planId as string | undefined) ?? "starter";
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
