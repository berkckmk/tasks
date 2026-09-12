import { onSchedule } from "firebase-functions/v2/scheduler";

import { syncForUser } from "../google/calendar";
import { db } from "../lib/admin";
import { googleSecrets } from "../lib/secrets";

/** Integrations handled per page. */
const PAGE_SIZE = 100;

/**
 * True for the OAuth failure that means the user revoked our access (or the
 * refresh token was otherwise invalidated). Retrying is pointless — it will
 * fail identically every day until they reconnect.
 */
function isRevokedGrantError(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error);
  return message.includes("invalid_grant") || message.includes("Token has been expired or revoked");
}

/**
 * Runs daily. Re-syncs Calendar for every user who has it connected — the
 * server-side complement to the in-app "Sync now" button, so sync stays
 * fresh even if the user doesn't open the app that day. (Sheets/Drive/Docs
 * are export-style actions the user triggers explicitly, not scheduled.)
 *
 * Pages through the results rather than materialising every connected user
 * at once, and checkpoints on the page cursor — the previous version loaded
 * everything in one `.get()` and synced serially inside a 60s budget, so it
 * died partway through and (having no cursor) re-synced the same
 * alphabetically-first users every day while the tail was never synced.
 *
 * Non-calendar integration documents are still filtered in memory. Firestore
 * can't filter a collection group by document id — `__name__` compares full
 * paths there, not ids — so narrowing this server-side would mean
 * denormalising an `integrationId` field onto every integration document.
 * At four documents per user that read amplification isn't worth it yet.
 */
export const scheduledCalendarSync = onSchedule(
  { schedule: "every 24 hours", timeoutSeconds: 540, memory: "512MiB", secrets: googleSecrets },
  async () => {
    let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;
    let synced = 0;
    let failed = 0;

    for (;;) {
      let query = db
        .collectionGroup("integrations")
        .where("status", "==", "connected")
        .orderBy("__name__")
        .limit(PAGE_SIZE);
      if (cursor) query = query.startAfter(cursor);

      const page = await query.get();
      if (page.empty) break;

      for (const doc of page.docs) {
        if (doc.id !== "google_calendar") continue;
        const uid = doc.ref.parent.parent?.id;
        if (!uid) continue;

        try {
          await syncForUser(uid);
          synced++;
        } catch (error) {
          failed++;
          console.error(`Scheduled Calendar sync failed for ${uid}:`, error);

          // Mark the integration so the user is actually told to reconnect.
          // Without this a revoked grant is retried every day forever and
          // the app keeps showing "connected".
          if (isRevokedGrantError(error)) {
            await doc.ref.set(
              {
                status: "error",
                errorMessage: "Google access was revoked. Reconnect to resume syncing.",
              },
              { merge: true }
            );
          }
        }
      }

      if (page.size < PAGE_SIZE) break;
      cursor = page.docs[page.size - 1];
    }

    console.log(`Scheduled Calendar sync: ${synced} synced, ${failed} failed.`);
  }
);
