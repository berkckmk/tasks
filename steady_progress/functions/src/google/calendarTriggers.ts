import { FieldValue } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { google } from "googleapis";

import { googleSecrets } from "../lib/secrets";
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
  { document: "users/{uid}/tasks/{taskId}", secrets: googleSecrets },
  (event) => cleanupOnWrite(event, "googleCalendarEventId")
);

export const onHabitWriteCleanupCalendarEvent = onDocumentWritten(
  { document: "users/{uid}/habits/{habitId}", secrets: googleSecrets },
  (event) => cleanupOnWrite(event, "googleCalendarReminderEventId")
);

async function cleanupOnWrite(
  event: {
    data?: {
      before?: FirebaseFirestore.DocumentSnapshot;
      after?: FirebaseFirestore.DocumentSnapshot;
    };
    params: { uid: string };
  },
  idField: string
): Promise<void> {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  const eventId = before?.[idField] as string | undefined;
  if (!eventId) return;

  const stillExists = after !== undefined;
  const syncTurnedOff = stillExists && after.syncEnabled !== true;
  if (!stillExists || syncTurnedOff) {
    await deleteCalendarEvent(event.params.uid, eventId);

    // Clear the stored id too. Leaving it behind on a document that still
    // exists points at an event that no longer does, so the next sync would
    // patch a deleted event and fail — permanently, since nothing else ever
    // clears it. Guarded against a write loop: this only runs when the id
    // was set, and it unsets it.
    if (stillExists && after[idField] !== undefined) {
      await event.data!.after!.ref.update({ [idField]: FieldValue.delete() });
    }
  }
}
