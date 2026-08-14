/**
 * Timezone- and calendar-correct date helpers shared by the calendar sync
 * and the notification schedulers.
 *
 * Everything here works in a *named IANA zone* rather than the function's
 * own clock. Cloud Functions run in UTC, so any `new Date()` +
 * `setHours()`/`toISOString()` arithmetic silently produces UTC wall-clock
 * times and then labels them with the user's timezone — which is how a user
 * in UTC+3 asking for a 09:00 reminder ended up with a 12:00 event.
 */

/** A plain calendar date with no time or offset, e.g. "2026-08-14". */
export type PlainDate = string;

/**
 * Whether the runtime recognises [timezone] as an IANA zone.
 *
 * Worth checking before every use: the timezone comes from the user profile
 * document, which the client writes, and `Intl.DateTimeFormat` throws a
 * `RangeError` on anything it doesn't recognise (including plausible-looking
 * values like "GMT+3"). An unguarded throw inside a scheduled job's user
 * loop aborts the entire run, so one bad profile silently stops every later
 * user from getting notifications.
 */
export function isValidTimeZone(timezone: string): boolean {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: timezone });
    return true;
  } catch {
    return false;
  }
}

/** [timezone] if the runtime understands it, otherwise "UTC". */
export function safeTimeZone(timezone: string | undefined): string {
  if (!timezone) return "UTC";
  return isValidTimeZone(timezone) ? timezone : "UTC";
}

function partsInTimeZone(
  date: Date,
  timezone: string,
  options: Intl.DateTimeFormatOptions
): Record<string, string> {
  const formatter = new Intl.DateTimeFormat("en-US", { timeZone: timezone, ...options });
  const result: Record<string, string> = {};
  for (const part of formatter.formatToParts(date)) result[part.type] = part.value;
  return result;
}

/** The calendar date [date] falls on, as seen in [timezone]. */
export function plainDateInTimeZone(date: Date, timezone: string): PlainDate {
  const parts = partsInTimeZone(date, timezone, {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  return `${parts.year}-${parts.month}-${parts.day}`;
}

/** Wall-clock hour and minute right now in [timezone], 24-hour. */
export function currentHourMinuteInTimeZone(timezone: string): [number, number] {
  const parts = partsInTimeZone(new Date(), timezone, {
    hour: "numeric",
    minute: "numeric",
    hourCycle: "h23",
  });
  return [parseInt(parts.hour ?? "0", 10), parseInt(parts.minute ?? "0", 10)];
}

/**
 * Adds [days] calendar days to a plain date.
 *
 * Uses `Date.UTC` deliberately: a plain date has no zone, so doing the
 * arithmetic in UTC (where every day is exactly 24h) is the only way to make
 * it DST-proof. Doing it in local time would skip or repeat a day across a
 * transition.
 */
export function addDays(date: PlainDate, days: number): PlainDate {
  const [year, month, day] = date.split("-").map((part) => parseInt(part, 10));
  const shifted = new Date(Date.UTC(year, month - 1, day + days));
  return shifted.toISOString().slice(0, 10);
}

/**
 * The UTC instant corresponding to a given wall-clock time in [timezone].
 *
 * Works by formatting a guess back in the target zone and correcting by the
 * difference, which is exact for every real zone offset (all are whole
 * minutes) and needs no timezone database of our own.
 */
export function zonedWallClockToUtc(
  date: PlainDate,
  hour: number,
  minute: number,
  timezone: string
): Date {
  const [year, month, day] = date.split("-").map((part) => parseInt(part, 10));
  const guess = new Date(Date.UTC(year, month - 1, day, hour, minute, 0, 0));
  const parts = partsInTimeZone(guess, timezone, {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "numeric",
    minute: "numeric",
    second: "numeric",
    hourCycle: "h23",
  });
  const asSeenInZone = Date.UTC(
    parseInt(parts.year, 10),
    parseInt(parts.month, 10) - 1,
    parseInt(parts.day, 10),
    parseInt(parts.hour, 10),
    parseInt(parts.minute, 10),
    parseInt(parts.second, 10)
  );
  return new Date(guess.getTime() * 2 - asSeenInZone);
}

/**
 * Parses a reminder label like "09:00", "9:00 AM", "7:30 PM".
 *
 * Returns null rather than a default for anything out of range — "99:99"
 * previously parsed to [99, 99], which `setHours(99, 99)` then rolled four
 * days into the future.
 */
export function parseReminderTime(label: string | undefined): [number, number] | null {
  if (!label) return null;
  const match = /^\s*(\d{1,2}):(\d{2})\s*(AM|PM)?\s*$/i.exec(label);
  if (!match) return null;

  let hour = parseInt(match[1], 10);
  const minute = parseInt(match[2], 10);
  const meridiem = match[3]?.toUpperCase();

  if (meridiem) {
    if (hour < 1 || hour > 12) return null;
    if (meridiem === "PM" && hour < 12) hour += 12;
    if (meridiem === "AM" && hour === 12) hour = 0;
  } else if (hour > 23) {
    return null;
  }
  if (minute > 59) return null;

  return [hour, minute];
}
