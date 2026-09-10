import { getMessaging } from "firebase-admin/messaging";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { db } from "../lib/admin";
import {
  currentHourMinuteInTimeZone,
  parseReminderTime,
  plainDateInTimeZone,
  safeTimeZone,
  wallClockLabelInTimeZone,
} from "../lib/datetime";
import { forEachUser } from "../lib/users";
import { digestHour, wantsNotification } from "./preferences";

/** How often sendHabitReminders runs; also the width of its match window. */
const REMINDER_SLOT_MINUTES = 15;

async function sendToUserTokens(
  uid: string,
  title: string,
  body: string,
  channelId: string = "channel_normal",
  data: Record<string, string> = {}
): Promise<void> {
  const tokensSnapshot = await db.collection("users").doc(uid).collection("fcmTokens").get();
  if (tokensSnapshot.empty) return;

  const tokens = tokensSnapshot.docs.map((doc) => doc.id);
  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
    android: {
      priority: "high",
      notification: {
        channelId,
        defaultSound: channelId !== "channel_low",
        defaultVibrateTimings: channelId !== "channel_low",
      },
    },
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
      if (!wantsNotification(user, "notifyHabitReminders")) return;

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

        await sendToUserTokens(
          userDoc.id,
          "Habit reminder",
          `Time for: ${habit.name as string}`,
          "channel_normal",
          {
            habitId: habitDoc.id,
            type: "habit",
          }
        );
        await habitDoc.ref.update({ lastReminderSentOn: today });
      }
    });
  }
);

/**
 * Runs hourly and sends each user one digest of the tasks due today, at the
 * hour they chose *in their own timezone* (default 08:00).
 *
 * It has to run hourly rather than once daily because a given local hour
 * happens at a different UTC instant in every zone; the hourly pass sends
 * only to users whose local clock currently reads that hour, and the
 * per-user `lastDigestSentOn` marker keeps that to one send per local day.
 *
 * Changing the hour later in the day does not produce a second digest: the
 * marker is already set for that local date.
 */
export const sendDailyTaskDigest = onSchedule(
  { schedule: "every 60 minutes", timeoutSeconds: 540, memory: "512MiB" },
  async () => {
    await forEachUser(async (userDoc) => {
      const user = userDoc.data();
      if (!wantsNotification(user, "notifyTaskDigest")) return;

      const timezone = safeTimeZone(user.timezone as string | undefined);
      const [localHour] = currentHourMinuteInTimeZone(timezone);
      if (localHour !== digestHour(user)) return;

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
          `You have ${dueToday.length} task${dueToday.length === 1 ? "" : "s"} due today.`,
          "channel_normal",
          {
            type: "digest",
          }
        );
      }
    });
  }
);

/**
 * How far back a due reminder is still worth sending.
 *
 * The pass runs every 15 minutes, so a window of one slot would be enough on
 * a good day — but a failed or skipped run would then drop those reminders on
 * the floor with nothing to show for it. A day of slack lets the next run
 * catch up, while still not resurrecting something the user set last week.
 */
const REMINDER_MAX_LATENESS_MS = 24 * 60 * 60 * 1000;

/**
 * Sends a push when a reminder in `users/{uid}/reminders` comes due.
 *
 * This is what the "Reminder alerts" switch controls. Until it existed the
 * reminders feature stored a `dueAt` and never did anything with it — the
 * screen listed reminders and nothing ever arrived.
 *
 * Unlike habit reminders and the digest, "due" needs no timezone arithmetic:
 * `dueAt` is an absolute instant, so comparing it to `now` is correct in every
 * zone. The user's timezone is still needed for the *message*, which quotes
 * the time back to them in their own clock.
 */
export const sendDueReminders = onSchedule(
  { schedule: "every 15 minutes", timeoutSeconds: 540, memory: "512MiB" },
  async () => {
    const now = new Date();
    const cutoff = new Date(now.getTime() - REMINDER_MAX_LATENESS_MS);

    await forEachUser(async (userDoc) => {
      const user = userDoc.data();
      if (!wantsNotification(user, "notifyReminderAlerts")) return;

      const timezone = safeTimeZone(user.timezone as string | undefined);

      // Ranged on dueAt only, which is a single-field index Firestore
      // maintains automatically. Adding `where("status", "==", ...)` would
      // turn this into a composite index that has to be deployed by hand
      // before the query works at all — and a missing index fails at runtime,
      // not at deploy (see docs/DEPLOYMENT_STATE.md). The status and
      // already-sent checks are cheap enough to do here instead; the window
      // holds at most a day of one user's reminders.
      const dueSnapshot = await userDoc.ref
        .collection("reminders")
        .where("dueAt", ">", cutoff)
        .where("dueAt", "<=", now)
        .get();

      for (const reminderDoc of dueSnapshot.docs) {
        const reminder = reminderDoc.data();
        if (reminder.status !== "scheduled") continue;

        // Idempotency marker, same role as lastReminderSentOn on habits.
        // Cleared by the client whenever the reminder is edited, so
        // rescheduling one re-arms it — see FirestoreReminderRepository.
        if (reminder.notifiedAt) continue;

        const dueAt = reminder.dueAt as FirebaseFirestore.Timestamp;
        const title = (reminder.title as string | undefined) ?? "Reminder";
        const message = (reminder.message as string | undefined) ?? "";
        const at = wallClockLabelInTimeZone(dueAt.toDate(), timezone);
        const priorityStr = (reminder.priority as string | undefined) ?? "normal";
        const channelId =
          priorityStr === "important"
            ? "channel_important"
            : priorityStr === "low"
            ? "channel_low"
            : "channel_normal";

        await sendToUserTokens(
          userDoc.id,
          title,
          message.length > 0 ? message : `Due at ${at}.`,
          channelId,
          {
            reminderId: reminderDoc.id,
            priority: priorityStr,
            type: "reminder",
          }
        );
        await reminderDoc.ref.update({ notifiedAt: now });
      }
    });
  }
);
