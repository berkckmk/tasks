import { getMessaging } from "firebase-admin/messaging";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { db } from "../lib/admin";
import {
  currentHourMinuteInTimeZone,
  parseReminderTime,
  plainDateInTimeZone,
  safeTimeZone,
} from "../lib/datetime";
import { forEachUser } from "../lib/users";

/** How often sendHabitReminders runs; also the width of its match window. */
const REMINDER_SLOT_MINUTES = 15;

async function sendToUserTokens(uid: string, title: string, body: string): Promise<void> {
  const tokensSnapshot = await db.collection("users").doc(uid).collection("fcmTokens").get();
  if (tokensSnapshot.empty) return;

  const tokens = tokensSnapshot.docs.map((doc) => doc.id);
  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
  });

  // Clean up tokens the platform reports as no longer valid (app
  // uninstalled, token expired, etc) so future runs don't keep retrying them.
  await Promise.all(
    response.responses.map((result, index) => {
      if (!result.success && isUnregisteredError(result.error?.code)) {
        return tokensSnapshot.docs[index].ref.delete();
      }
      return Promise.resolve();
    })
  );
}

function isUnregisteredError(code: string | undefined): boolean {
  return (
    code === "messaging/registration-token-not-registered" ||
    code === "messaging/invalid-registration-token"
  );
}

/**
 * Runs every 15 minutes. For each user with notifications enabled, checks
 * whether any habit's reminder time falls in the current slot — computed in
 * *that user's own timezone* — and sends a push if so.
 */
export const sendHabitReminders = onSchedule(
  { schedule: "every 15 minutes", timeoutSeconds: 540, memory: "512MiB" },
  async () => {
    await forEachUser(async (userDoc) => {
      const user = userDoc.data();
      if (user.appPreferences?.notificationsEnabled === false) return;

      const timezone = safeTimeZone(user.timezone as string | undefined);
      const [nowHour, nowMinute] = currentHourMinuteInTimeZone(timezone);
      // Half-open [slotStart, slotStart + 15) window. The previous check was
      // `abs(reminderMinute - nowMinute) < 15`, which is 29 minutes wide and
      // overlaps the neighbouring run: a 09:10 reminder matched both the
      // 09:00 and 09:15 runs (two pushes), while 09:59 matched neither,
      // because it also required reminderHour === nowHour.
      const nowSlot = Math.floor((nowHour * 60 + nowMinute) / REMINDER_SLOT_MINUTES);
      const today = plainDateInTimeZone(new Date(), timezone);

      const habitsSnapshot = await userDoc.ref.collection("habits").get();
      for (const habitDoc of habitsSnapshot.docs) {
        const habit = habitDoc.data();
        const reminderLabel = habit.reminderTimeLabel as string | undefined;
        if (!reminderLabel) continue;

        const parsed = parseReminderTime(reminderLabel);
        if (!parsed) continue;
        const [reminderHour, reminderMinute] = parsed;
        if (Math.floor((reminderHour * 60 + reminderMinute) / REMINDER_SLOT_MINUTES) !== nowSlot) {
          continue;
        }

        // Idempotency marker. onSchedule retries a failed run, and without
        // this every habit already notified in that run gets a second push.
        const alreadySentFor = habit.lastReminderSentOn as string | undefined;
        if (alreadySentFor === today) continue;

        await sendToUserTokens(userDoc.id, "Habit reminder", `Time for: ${habit.name as string}`);
        await habitDoc.ref.update({ lastReminderSentOn: today });
      }
    });
  }
);

/**
 * Runs hourly and sends each user one digest of the tasks due today, at
 * 08:00 *in their own timezone*.
 *
 * It has to run hourly rather than once daily because "08:00 local" happens
 * at a different UTC instant for every zone; the hourly pass sends only to
 * users whose local clock currently reads 08:xx, and the per-user
 * `lastDigestSentOn` marker keeps that to one send per local day.
 */
export const sendDailyTaskDigest = onSchedule(
  { schedule: "every 60 minutes", timeoutSeconds: 540, memory: "512MiB" },
  async () => {
    await forEachUser(async (userDoc) => {
      const user = userDoc.data();
      if (user.appPreferences?.notificationsEnabled === false) return;

      const timezone = safeTimeZone(user.timezone as string | undefined);
      const [localHour] = currentHourMinuteInTimeZone(timezone);
      if (localHour !== 8) return;

      const today = plainDateInTimeZone(new Date(), timezone);
      if ((user.lastDigestSentOn as string | undefined) === today) return;

      const tasksSnapshot = await userDoc.ref.collection("tasks").get();
      const dueToday = tasksSnapshot.docs.filter((doc) => {
        const data = doc.data();
        if (data.status === "done") return false;
        const dueDate = data.dueDate as FirebaseFirestore.Timestamp | undefined;
        // Compared in the user's zone, so "due today" means the same thing
        // here as it does on their screen.
        return dueDate && plainDateInTimeZone(dueDate.toDate(), timezone) === today;
      });

      // The marker is written even when there's nothing to send, so a user
      // with no tasks due isn't re-checked every hour for the rest of the day.
      await userDoc.ref.update({ lastDigestSentOn: today });

      if (dueToday.length > 0) {
        await sendToUserTokens(
          userDoc.id,
          "Today's tasks",
          `You have ${dueToday.length} task${dueToday.length === 1 ? "" : "s"} due today.`
        );
      }
    });
  }
);
