import { onSchedule } from "firebase-functions/v2/scheduler";

import { syncForUser } from "../google/calendar";
import { db } from "../lib/admin";

/**
 * Runs daily. Re-syncs Calendar for every user who has it connected — the
 * server-side complement to the in-app "Sync now" button, so sync stays
 * fresh even if the user doesn't open the app that day. (Sheets/Drive/Docs
 * are export-style actions the user triggers explicitly, not scheduled.)
 */
export const scheduledCalendarSync = onSchedule("every 24 hours", async () => {
  const connectedCalendars = await db
    .collectionGroup("integrations")
    .where("status", "==", "connected")
    .get();

  for (const doc of connectedCalendars.docs) {
    if (doc.id !== "google_calendar") continue;
    const uid = doc.ref.parent.parent?.id;
    if (!uid) continue;

    try {
      await syncForUser(uid);
    } catch (error) {
      console.error(`Scheduled Calendar sync failed for ${uid}:`, error);
    }
  }
});
