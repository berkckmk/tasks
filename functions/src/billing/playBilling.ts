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

    const expiryTimeMillis = Number(response.data.expiryTimeMillis ?? 0);
    const isActive = expiryTimeMillis > Date.now();

    if (isActive) {
      await db
        .collection("users")
        .doc(uid)
        .collection("subscription")
        .doc("status")
        .set(
          {
            planId: planIdFromProductId(productId),
            status: "active",
            billingProvider: "play_billing",
            startedAt: new Date(),
            expiresAt: new Date(expiryTimeMillis),
          },
          { merge: true }
        );
    }

    return { granted: isActive };
  } catch (error) {
    console.error("Play purchase verification failed:", error);
    return { granted: false };
  }
});
