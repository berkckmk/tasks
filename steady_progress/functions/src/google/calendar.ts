import { HttpsError, onCall } from "firebase-functions/v2/https";
import { calendar_v3, google } from "googleapis";

import { db } from "../lib/admin";
import {
  addDays,
  parseReminderTime,
  plainDateInTimeZone,
  safeTimeZone,
  zonedWallClockToUtc,
} from "../lib/datetime";
import { assertPlan } from "../lib/plan";
import { googleSecrets } from "../lib/secrets";
import { getAuthorizedClient } from "./oauth";

/**
 * True for the Google API errors that mean "this event no longer exists"
 * (the user deleted it in Google Calendar, or it was already cancelled).
 * Those are recoverable: forget the stored id and insert a fresh event.
 */
function isMissingEventError(error: unknown): boolean {
  const status = (error as { code?: number; status?: number })?.code;
  return status === 404 || status === 410;
}

interface SyncResult {
  tasksSynced: number;
  habitsSynced: number;
}

/**
 * Syncs every syncEnabled task/habit for [uid]. Never creates a duplicate
 * event: a task/habit that already has a googleCalendarEventId /
 * googleCalendarReminderEventId is patched in place, not re-inserted.
 */
export async function syncForUser(uid: string): Promise<SyncResult> {
  // Checked here (not just in the syncGoogleCalendar callable) so a user
  // who downgrades after connecting also stops being synced by
  // scheduledCalendarSync, which calls this function directly.
  await assertPlan(uid, ["complete"]);

  const oauthClient = await getAuthorizedClient(uid, "calendar");
  const calendar = google.calendar({ version: "v3", auth: oauthClient });

  const userRef = db.collection("users").doc(uid);
  const profileSnapshot = await userRef.get();
  const timezone = safeTimeZone(profileSnapshot.data()?.timezone as string | undefined);

  const tasksSynced = await syncTasks(calendar, userRef, timezone);
  const habitsSynced = await syncHabits(calendar, userRef, timezone);

  await userRef
    .collection("integrations")
    .doc("google_calendar")
    .set({ lastSyncedAt: new Date(), status: "connected", errorMessage: null }, { merge: true });

  return { tasksSynced, habitsSynced };
}

async function syncTasks(
  calendar: calendar_v3.Calendar,
  userRef: FirebaseFirestore.DocumentReference,
  timezone: string
): Promise<number> {
  const tasksSnapshot = await userRef.collection("tasks").where("syncEnabled", "==", true).get();
  let count = 0;

  for (const doc of tasksSnapshot.docs) {
    const task = doc.data();
    const dueDate = task.dueDate as FirebaseFirestore.Timestamp | undefined;
    if (!dueDate) continue;

    // The due date is whatever calendar day it falls on *for this user* —
    // computing it in UTC put a task due at 20:00 in UTC-5 on the next day.
    const startDate = plainDateInTimeZone(dueDate.toDate(), timezone);
    const requestBody: calendar_v3.Schema$Event = {
      summary: task.title as string,
      description: (task.description as string) || undefined,
      // Google treats end.date as *exclusive*, so a one-day all-day event
      // ends on the following day. Passing the same date for both made the
      // API reject every insert, which failed the whole sync.
      // `timeZone` is meaningless alongside `date` and is omitted.
      start: { date: startDate },
      end: { date: addDays(startDate, 1) },
    };

    await upsertEvent(calendar, doc, "googleCalendarEventId", requestBody);
    count++;
  }

  return count;
}

/**
 * Patches the event [idField] points at, or inserts a new one and stores its
 * id. If the stored event has been deleted in Google Calendar, the id is
 * dropped and the event re-inserted — otherwise that one task would fail
 * forever, and (because the failure propagates) take every later item in the
 * sync down with it.
 */
async function upsertEvent(
  calendar: calendar_v3.Calendar,
  doc: FirebaseFirestore.QueryDocumentSnapshot,
  idField: string,
  requestBody: calendar_v3.Schema$Event
): Promise<void> {
  const existingEventId = doc.data()[idField] as string | undefined;

  if (existingEventId) {
    try {
      await calendar.events.patch({
        calendarId: "primary",
        eventId: existingEventId,
        requestBody,
      });
      return;
    } catch (error) {
      if (!isMissingEventError(error)) throw error;
    }
  }

  const created = await calendar.events.insert({ calendarId: "primary", requestBody });
  await doc.ref.update({ [idField]: created.data.id, lastSyncedAt: new Date() });
}

async function syncHabits(
  calendar: calendar_v3.Calendar,
  userRef: FirebaseFirestore.DocumentReference,
  timezone: string
): Promise<number> {
  const habitsSnapshot = await userRef.collection("habits").where("syncEnabled", "==", true).get();
  let count = 0;

  const todayInZone = plainDateInTimeZone(new Date(), timezone);

  for (const doc of habitsSnapshot.docs) {
    const habit = doc.data();
    const label = habit.reminderTimeLabel as string | undefined;
    // No reminder time set is normal — default to 09:00. A label that's
    // present but unparseable is corrupt data, and inventing a time for it
    // would put a wrong event on someone's calendar, so skip it.
    const parsed = label ? parseReminderTime(label) : [9, 0];
    if (!parsed) {
      console.warn(`Skipping habit ${doc.id}: unparseable reminderTimeLabel ${JSON.stringify(label)}`);
      continue;
    }
    const [hour, minute] = parsed;

    // Built as a wall-clock time *in the user's zone*, not the function's.
    // `new Date()` + setHours() runs in UTC on Cloud Functions, so a user in
    // UTC+3 asking for 09:00 was getting a 12:00 event.
    const start = zonedWallClockToUtc(todayInZone, hour, minute, timezone);
    const end = new Date(start.getTime() + 30 * 60 * 1000);

    const requestBody: calendar_v3.Schema$Event = {
      summary: `${habit.name as string} (habit reminder)`,
      // timeZone matters here: it's what keeps the daily recurrence pinned
      // to 09:00 local across DST rather than drifting by an hour.
      start: { dateTime: start.toISOString(), timeZone: timezone },
      end: { dateTime: end.toISOString(), timeZone: timezone },
      recurrence: ["RRULE:FREQ=DAILY"],
    };

    await upsertEvent(calendar, doc, "googleCalendarReminderEventId", requestBody);
    count++;
  }

  return count;
}

export const syncGoogleCalendar = onCall({ secrets: googleSecrets }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

  try {
    return await syncForUser(uid);
  } catch (error) {
    await db
      .collection("users")
      .doc(uid)
      .collection("integrations")
      .doc("google_calendar")
      .set(
        { status: "error", errorMessage: error instanceof Error ? error.message : "Sync failed." },
        { merge: true }
      );
    throw error;
  }
});
