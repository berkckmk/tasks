import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { google } from "googleapis";

import { getAuthorizedClient } from "./oauth";

/**
 * Deletes the linked Calendar event when a task/habit is deleted, or when
 * the user turns sync off — this is the "allow unlinking/deleting synced
 * events" requirement. If Calendar isn't connected anymore,
 * getAuthorizedClient throws, which we swallow (best-effort cleanup, not
 * worth failing the whole write over).
 */
async function deleteCalendarEvent(uid: string, eventId: string): Promise<void> {
  try {
    const client = await getAuthorizedClient(uid, "calendar");
    const calendar = google.calendar({ version: "v3", auth: client });
    await calendar.events.delete({ calendarId: "primary", eventId });
  } catch (error) {
    console.warn(`Skipping calendar event cleanup for ${uid}/${eventId}:`, error);
  }
}

export const onTaskWriteCleanupCalendarEvent = onDocumentWritten(
  "users/{uid}/tasks/{taskId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    const eventId = before?.googleCalendarEventId as string | undefined;
    if (!eventId) return;

    const wasDeleted = !after;
    const syncTurnedOff = after !== undefined && after.syncEnabled !== true;
    if (wasDeleted || syncTurnedOff) {
      await deleteCalendarEvent(event.params.uid, eventId);
    }
  }
);

export const onHabitWriteCleanupCalendarEvent = onDocumentWritten(
  "users/{uid}/habits/{habitId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    const eventId = before?.googleCalendarReminderEventId as string | undefined;
    if (!eventId) return;

    const wasDeleted = !after;
    const syncTurnedOff = after !== undefined && after.syncEnabled !== true;
    if (wasDeleted || syncTurnedOff) {
      await deleteCalendarEvent(event.params.uid, eventId);
    }
  }
);
