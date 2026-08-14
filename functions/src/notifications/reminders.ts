import { getMessaging } from "firebase-admin/messaging";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { db } from "../lib/admin";

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

function currentHourMinuteInTimezone(timezone: string): [number, number] {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    hour: "numeric",
    minute: "numeric",
    hourCycle: "h23",
  });
  const parts = formatter.formatToParts(new Date());
  const hour = parseInt(parts.find((p) => p.type === "hour")?.value ?? "0", 10);
  const minute = parseInt(parts.find((p) => p.type === "minute")?.value ?? "0", 10);
  return [hour, minute];
}

/**
 * Runs every 15 minutes. For each user with notifications enabled, checks
 * whether any habit's reminder time falls in the current window — computed
 * in *that user's own timezone* — and sends a push if so.
 *
 * Scales by scanning every user document — fine at this app's current
 * size. Before that becomes a bottleneck, replace the full scan with a
 * fan-out (a Pub/Sub message per user, or a precomputed "next reminder at"
 * index queried directly) instead.
 */
export const sendHabitReminders = onSchedule("every 15 minutes", async () => {
  const usersSnapshot = await db.collection("users").get();

  for (const userDoc of usersSnapshot.docs) {
    const user = userDoc.data();
    if (user.appPreferences?.notificationsEnabled === false) continue;

    const timezone = (user.timezone as string) || "UTC";
    const [nowHour, nowMinute] = currentHourMinuteInTimezone(timezone);

    const habitsSnapshot = await userDoc.ref.collection("habits").get();
    for (const habitDoc of habitsSnapshot.docs) {
      const habit = habitDoc.data();
      const reminderLabel = habit.reminderTimeLabel as string | undefined;
      if (!reminderLabel) continue;

      const [reminderHour, reminderMinute] = parseReminderTime(reminderLabel);
      if (reminderHour === nowHour && Math.abs(reminderMinute - nowMinute) < 15) {
        await sendToUserTokens(userDoc.id, "Habit reminder", `Time for: ${habit.name as string}`);
      }
    }
  }
});

/**
 * Runs once daily. Sends one digest push per user listing how many tasks
 * are due "today". Today is computed in UTC for simplicity — good enough
 * for a first version; true per-timezone scheduling would need a per-user
 * cron rather than one global scheduled function.
 */
export const sendDailyTaskDigest = onSchedule("every day 08:00", async () => {
  const usersSnapshot = await db.collection("users").get();
  const todayStr = new Date().toISOString().slice(0, 10);

  for (const userDoc of usersSnapshot.docs) {
    const user = userDoc.data();
    if (user.appPreferences?.notificationsEnabled === false) continue;

    const tasksSnapshot = await userDoc.ref.collection("tasks").get();
    const dueToday = tasksSnapshot.docs.filter((doc) => {
      const data = doc.data();
      if (data.status === "done") return false;
      const dueDate = data.dueDate as FirebaseFirestore.Timestamp | undefined;
      return dueDate && dueDate.toDate().toISOString().slice(0, 10) === todayStr;
    });

    if (dueToday.length > 0) {
      await sendToUserTokens(
        userDoc.id,
        "Today's tasks",
        `You have ${dueToday.length} task${dueToday.length === 1 ? "" : "s"} due today.`
      );
    }
  }
});
