import { HttpsError, onCall } from "firebase-functions/v2/https";
import { calendar_v3, google } from "googleapis";

import { db } from "../lib/admin";
import { getAuthorizedClient } from "./oauth";

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
  const oauthClient = await getAuthorizedClient(uid, "calendar");
  const calendar = google.calendar({ version: "v3", auth: oauthClient });

  const userRef = db.collection("users").doc(uid);
  const profileSnapshot = await userRef.get();
  const timezone = (profileSnapshot.data()?.timezone as string | undefined) || "UTC";

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

    const isoDate = dueDate.toDate().toISOString().slice(0, 10);
    const requestBody: calendar_v3.Schema$Event = {
      summary: task.title as string,
      description: (task.description as string) || undefined,
      start: { date: isoDate, timeZone: timezone },
      end: { date: isoDate, timeZone: timezone },
    };

    const existingEventId = task.googleCalendarEventId as string | undefined;
    if (existingEventId) {
      await calendar.events.patch({ calendarId: "primary", eventId: existingEventId, requestBody });
    } else {
      const created = await calendar.events.insert({ calendarId: "primary", requestBody });
      await doc.ref.update({ googleCalendarEventId: created.data.id, lastSyncedAt: new Date() });
    }
    count++;
  }

  return count;
}

async function syncHabits(
  calendar: calendar_v3.Calendar,
  userRef: FirebaseFirestore.DocumentReference,
  timezone: string
): Promise<number> {
  const habitsSnapshot = await userRef.collection("habits").where("syncEnabled", "==", true).get();
  let count = 0;

  for (const doc of habitsSnapshot.docs) {
    const habit = doc.data();
    const [hour, minute] = parseReminderTime(habit.reminderTimeLabel as string | undefined);

    const start = new Date();
    start.setHours(hour, minute, 0, 0);
    const end = new Date(start.getTime() + 30 * 60 * 1000);

    const requestBody: calendar_v3.Schema$Event = {
      summary: `${habit.name as string} (habit reminder)`,
      start: { dateTime: start.toISOString(), timeZone: timezone },
      end: { dateTime: end.toISOString(), timeZone: timezone },
      recurrence: ["RRULE:FREQ=DAILY"],
    };

    const existingEventId = habit.googleCalendarReminderEventId as string | undefined;
    if (existingEventId) {
      await calendar.events.patch({ calendarId: "primary", eventId: existingEventId, requestBody });
    } else {
      const created = await calendar.events.insert({ calendarId: "primary", requestBody });
      await doc.ref.update({
        googleCalendarReminderEventId: created.data.id,
        lastSyncedAt: new Date(),
      });
    }
    count++;
  }

  return count;
}

function parseReminderTime(label: string | undefined): [number, number] {
  if (!label) return [9, 0];
  const match = /(\d{1,2}):(\d{2})\s*(AM|PM)?/i.exec(label);
  if (!match) return [9, 0];
  let hour = parseInt(match[1], 10);
  const minute = parseInt(match[2], 10);
  const meridiem = match[3]?.toUpperCase();
  if (meridiem === "PM" && hour < 12) hour += 12;
  if (meridiem === "AM" && hour === 12) hour = 0;
  return [hour, minute];
}

export const syncGoogleCalendar = onCall(async (request) => {
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
