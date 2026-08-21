/**
 * Reading the notification switches off a user document.
 *
 * The keys are shared with the client
 * (`lib/features/notifications/domain/notification_settings.dart`); if you
 * rename one here, rename it there in the same change or the switch silently
 * stops doing anything.
 */

/** Channel keys, matching `NotificationChannel.key` on the client. */
export type NotificationChannel =
  | "notifyHabitReminders"
  | "notifyTaskDigest"
  | "notifyReminderAlerts";

/** Fallback digest hour, matching `NotificationSettings.defaultDigestHour`. */
const DEFAULT_DIGEST_HOUR = 8;

type UserData = FirebaseFirestore.DocumentData;

/**
 * Whether [channel] should be sent to this user.
 *
 * **Absent means enabled.** None of these keys exist on a profile written
 * before the settings screen shipped, and defaulting to off would silently
 * stop notifications for every existing user the moment this deployed. Only
 * an explicit `false` turns a channel off — which is exactly what the client
 * writes.
 *
 * The master switch is checked here too, so no caller can honour a channel
 * while ignoring "notifications off".
 */
export function wantsNotification(user: UserData, channel: NotificationChannel): boolean {
  const preferences = user.appPreferences as Record<string, unknown> | undefined;
  if (preferences?.notificationsEnabled === false) return false;
  return preferences?.[channel] !== false;
}

/**
 * The local hour the daily digest should arrive, 0-23.
 *
 * Clamped rather than trusted: `appPreferences` is client-written, and an
 * out-of-range hour would mean the hourly pass never matches and the user
 * simply stops getting a digest, with nothing logged anywhere.
 */
export function digestHour(user: UserData): number {
  const preferences = user.appPreferences as Record<string, unknown> | undefined;
  const raw = preferences?.taskDigestHour;
  if (typeof raw !== "number" || !Number.isInteger(raw) || raw < 0 || raw > 23) {
    return DEFAULT_DIGEST_HOUR;
  }
  return raw;
}
