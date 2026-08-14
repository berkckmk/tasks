import { HttpsError, onCall } from "firebase-functions/v2/https";

import { db } from "../lib/admin";
import { assertPlan } from "../lib/plan";
import { deleteTokens } from "../lib/tokens";
import { exchangeAndStoreCode } from "./oauth";

export const VALID_INTEGRATIONS = ["calendar", "sheets", "drive", "docs"] as const;
export type IntegrationId = (typeof VALID_INTEGRATIONS)[number];

export const SCOPES: Record<IntegrationId, string> = {
  calendar: "https://www.googleapis.com/auth/calendar.events",
  sheets: "https://www.googleapis.com/auth/spreadsheets",
  drive: "https://www.googleapis.com/auth/drive.file",
  docs: "https://www.googleapis.com/auth/documents",
};

export const INTEGRATION_DOC_ID: Record<IntegrationId, string> = {
  calendar: "google_calendar",
  sheets: "google_sheets",
  drive: "google_drive",
  docs: "google_docs",
};

function assertIntegration(value: unknown): asserts value is IntegrationId {
  if (typeof value !== "string" || !(VALID_INTEGRATIONS as readonly string[]).includes(value)) {
    throw new HttpsError("invalid-argument", `Unknown integration: ${String(value)}`);
  }
}

/**
 * Client calls this right after requesting ONE scope's server auth code —
 * never all four integrations' scopes at once. See
 * lib/features/google_integrations/application/google_integrations_actions.dart.
 */
export const connectGoogleIntegration = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");
  await assertPlan(uid, ["complete"]);

  const { integration, authCode } = request.data as { integration?: unknown; authCode?: unknown };
  assertIntegration(integration);
  if (typeof authCode !== "string" || authCode.length === 0) {
    throw new HttpsError("invalid-argument", "Missing authCode.");
  }

  const statusRef = db
    .collection("users")
    .doc(uid)
    .collection("integrations")
    .doc(INTEGRATION_DOC_ID[integration]);

  try {
    await exchangeAndStoreCode(uid, integration, authCode, SCOPES[integration]);
    await statusRef.set({ enabled: true, status: "connected", errorMessage: null }, { merge: true });
  } catch (error) {
    await statusRef.set(
      {
        enabled: false,
        status: "error",
        errorMessage: error instanceof Error ? error.message : "Connection failed.",
      },
      { merge: true }
    );
    throw error;
  }

  return { ok: true };
});

export const disconnectGoogleIntegration = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

  const { integration } = request.data as { integration?: unknown };
  assertIntegration(integration);

  await deleteTokens(uid, integration);
  await db
    .collection("users")
    .doc(uid)
    .collection("integrations")
    .doc(INTEGRATION_DOC_ID[integration])
    .set({ enabled: false, status: "notConnected" }, { merge: true });

  return { ok: true };
});
