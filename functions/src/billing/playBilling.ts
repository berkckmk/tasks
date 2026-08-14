import { HttpsError, onCall } from "firebase-functions/v2/https";
import { google } from "googleapis";

import { db } from "../lib/admin";

function planIdFromProductId(productId: string): string {
  const map: Record<string, string> = {
    steady_progress_growth_monthly: "growth",
    steady_progress_complete_monthly: "complete",
  };
  return map[productId] ?? "starter";
}

/**
 * Verifies a Google Play purchase token against the Android Publisher API
 * before granting entitlement — never trust `PurchaseStatus.purchased`
 * client-side alone, since a rooted/tampered device can fake that state.
 *
 * Requires the function's runtime service account to be added in Play
 * Console (Users and permissions > invite the service account's email with
 * "View app information and download bulk reports" + financial data
 * access), and ANDROID_PACKAGE_NAME set (see functions/.env.example).
 */
export const verifyPlayPurchase = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

  const { productId, purchaseToken } = request.data as {
    productId?: unknown;
    purchaseToken?: unknown;
  };
  if (typeof productId !== "string" || typeof purchaseToken !== "string") {
    throw new HttpsError("invalid-argument", "Missing productId/purchaseToken.");
  }

  const packageName = process.env.ANDROID_PACKAGE_NAME;
  if (!packageName) {
    throw new HttpsError("failed-precondition", "ANDROID_PACKAGE_NAME is not configured.");
  }

  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const androidPublisher = google.androidpublisher({ version: "v3", auth });

  try {
    const response = await androidPublisher.purchases.subscriptions.get({
      packageName,
      subscriptionId: productId,
      token: purchaseToken,
    });

    // The purchase's obfuscated account ID must match the caller's own
    // Firebase uid (set client-side via PurchaseParam.applicationUserName —
    // see PlayBillingService.purchasePlan). Without this check, a valid
    // purchase token obtained through any means for a DIFFERENT Google
    // account could be replayed here to grant a plan to this account for
    // free.
    if (response.data.obfuscatedExternalAccountId !== uid) {
      console.warn(`Play purchase account mismatch for ${uid}: token belongs to a different account.`);
      return { granted: false };
    }

    const expiryTimeMillis = Number(response.data.expiryTimeMillis ?? 0);
    const isActive = expiryTimeMillis > Date.now();

    const planId = planIdFromProductId(productId);
    if (planId === "starter") {
      console.warn(`Play purchase for unknown productId ${productId}; refusing to grant.`);
      return { granted: false };
    }

    if (!isActive) return { granted: false };

    const subscriptionDoc = db
      .collection("users")
      .doc(uid)
      .collection("subscription")
      .doc("status");
    const existing = await subscriptionDoc.get();

    await subscriptionDoc.set(
      {
        planId,
        status: "active",
        billingProvider: "play_billing",
        // Preserved rather than restamped, so re-verifying an existing
        // purchase (which the client does on every launch) doesn't keep
        // moving the subscription's start date forward.
        startedAt: existing.data()?.startedAt ?? new Date(),
        expiresAt: new Date(expiryTimeMillis),
        isTrialActive: false,
        playPurchaseToken: purchaseToken,
      },
      { merge: true }
    );

    // Acknowledge server-side, and only now that the purchase is verified
    // and entitlement is stored. Play auto-refunds a purchase that isn't
    // acknowledged within three days; the client used to acknowledge even
    // when verification had failed, which defeated that safety net.
    if (response.data.acknowledgementState === 0) {
      await androidPublisher.purchases.subscriptions.acknowledge({
        packageName,
        subscriptionId: productId,
        token: purchaseToken,
        requestBody: {},
      });
    }

    return { granted: true };
  } catch (error) {
    console.error("Play purchase verification failed:", error);
    // A Play API outage is not the same as a forged token, and telling a
    // paying user "couldn't be verified" with no retry is the worse failure.
    throw new HttpsError("internal", "Could not verify the purchase right now. Please try again.");
  }
});
