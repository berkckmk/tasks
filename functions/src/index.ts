import { setGlobalOptions } from "firebase-functions/v2";

/**
 * Runtime defaults for every function in this codebase.
 *
 * Previously nothing was declared at all, which meant the implicit defaults
 * applied: 256MiB, 60s, and unbounded scaling. `maxInstances` is the one that
 * matters most on a hobby-scale project — without it a runaway loop or a
 * traffic spike can scale to the project's full quota and bill accordingly.
 *
 * Region is pinned explicitly. It was already us-central1 by default and the
 * Flutter client calls the default region via `FirebaseFunctions.instance`,
 * so this only makes an existing coupling visible — but changing it here
 * without changing the client would break every callable, hence the note.
 */
setGlobalOptions({
  region: "us-central1",
  maxInstances: 10,
  memory: "256MiB",
  timeoutSeconds: 60,
});

export { createHabit } from "./habits/createHabit";
export { createTask } from "./tasks/createTask";
export { verifyPlayPurchase } from "./billing/playBilling";
export { createStripeCheckoutSession, createStripePortalSession } from "./billing/stripe";
export { handleBillingWebhook } from "./billing/webhook";
export { connectGoogleIntegration, disconnectGoogleIntegration } from "./google/connect";
export { syncGoogleCalendar } from "./google/calendar";
export {
  onHabitWriteCleanupCalendarEvent,
  onTaskWriteCleanupCalendarEvent,
} from "./google/calendarTriggers";
export { generateGoogleDocsReport } from "./google/docs";
export { backupToGoogleDrive } from "./google/drive";
export { exportToGoogleSheets } from "./google/sheets";
export { sendDailyTaskDigest, sendHabitReminders } from "./notifications/reminders";
export { scheduledCalendarSync } from "./scheduled/scheduledSync";
