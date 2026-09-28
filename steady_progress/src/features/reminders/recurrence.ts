export const repeatRules = [
  'Tekrarlama',
  'Her gün',
  'Hafta içi (Pzt-Cum)',
  'Her hafta',
  'Her ay',
  'Her yıl',
] as const;

export type RepeatRule = typeof repeatRules[number];

export function normalizeRepeatRule(rule: string | null | undefined): RepeatRule | null {
  if (!rule) return null;
  const trimmed = rule.trim().toLowerCase();
  if (trimmed === 'tekrarlama' || trimmed === 'none' || trimmed === '') return null;
  if (trimmed === 'her gün' || trimmed === 'her gun' || trimmed === 'daily') return 'Her gün';
  if (
    trimmed === 'hafta içi (pzt-cum)' ||
    trimmed === 'hafta içi' ||
    trimmed === 'hafta ici' ||
    trimmed === 'weekdays'
  ) return 'Hafta içi (Pzt-Cum)';
  if (trimmed === 'her hafta' || trimmed === 'weekly') return 'Her hafta';
  if (trimmed === 'her ay' || trimmed === 'monthly') return 'Her ay';
  if (trimmed === 'her yıl' || trimmed === 'her yil' || trimmed === 'yearly') return 'Her yıl';
  return (repeatRules as readonly string[]).includes(rule) ? (rule as RepeatRule) : null;
}

/**
 * `anchorDay` is the day of month the series was created on. Without it a
 * monthly series that once clamps (31 Jan -> 28 Feb) would stay on the 28th.
 */
function stepForward(d: Date, rule: RepeatRule, anchorDay?: number | null) {
  if (rule === 'Her gün') {
    d.setDate(d.getDate() + 1);
  } else if (rule === 'Hafta içi (Pzt-Cum)') {
    do {
      d.setDate(d.getDate() + 1);
    } while (d.getDay() === 0 || d.getDay() === 6);
  } else if (rule === 'Her hafta') {
    d.setDate(d.getDate() + 7);
  } else if (rule === 'Her ay') {
    const targetDay = anchorDay ?? d.getDate();
    d.setDate(1);
    d.setMonth(d.getMonth() + 1);
    const maxDays = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
    d.setDate(Math.min(targetDay, maxDays));
  } else if (rule === 'Her yıl') {
    const targetDay = anchorDay ?? d.getDate();
    const targetMonth = d.getMonth();
    d.setDate(1);
    d.setFullYear(d.getFullYear() + 1);
    d.setMonth(targetMonth);
    const maxDays = new Date(d.getFullYear(), targetMonth + 1, 0).getDate();
    d.setDate(Math.min(targetDay, maxDays));
  }
}

function stepBackward(d: Date, rule: RepeatRule, anchorDay?: number | null) {
  if (rule === 'Her gün') {
    d.setDate(d.getDate() - 1);
  } else if (rule === 'Hafta içi (Pzt-Cum)') {
    do {
      d.setDate(d.getDate() - 1);
    } while (d.getDay() === 0 || d.getDay() === 6);
  } else if (rule === 'Her hafta') {
    d.setDate(d.getDate() - 7);
  } else if (rule === 'Her ay') {
    const targetDay = anchorDay ?? d.getDate();
    d.setDate(1);
    d.setMonth(d.getMonth() - 1);
    const maxDays = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
    d.setDate(Math.min(targetDay, maxDays));
  } else if (rule === 'Her yıl') {
    const targetDay = anchorDay ?? d.getDate();
    const targetMonth = d.getMonth();
    d.setDate(1);
    d.setFullYear(d.getFullYear() - 1);
    d.setMonth(targetMonth);
    const maxDays = new Date(d.getFullYear(), targetMonth + 1, 0).getDate();
    d.setDate(Math.min(targetDay, maxDays));
  }
}

/**
 * Calculates the next occurrence date for a repeating item.
 * Preserves the original time (hours, minutes, seconds).
 * Ensures the resulting date is in the future relative to `fromDate`.
 */
export function calculateNextDueDate(
  currentDueAt: Date | null | undefined,
  repeatRule: string | null | undefined,
  fromDate: Date = new Date(),
  anchorDay?: number | null,
): Date | null {
  if (!currentDueAt) return null;
  const normalized = normalizeRepeatRule(repeatRule);
  if (!normalized) return null;

  const next = new Date(currentDueAt.getTime());
  // Step at least once to the next scheduled slot
  stepForward(next, normalized, anchorDay);

  // If the next slot is still in the past or right now, advance until it is in the future
  let iterations = 0;
  while (next.getTime() <= fromDate.getTime() && iterations < 500) {
    stepForward(next, normalized, anchorDay);
    iterations += 1;
  }
  return next;
}

/**
 * Reverts a repeating date back to its previous occurrence.
 * Used when an item was ticked and user un-ticks / undos the action.
 */
export function calculatePreviousDueDate(
  currentDueAt: Date | null | undefined,
  repeatRule: string | null | undefined,
  anchorDay?: number | null,
): Date | null {
  if (!currentDueAt) return null;
  const normalized = normalizeRepeatRule(repeatRule);
  if (!normalized) return null;

  const prev = new Date(currentDueAt.getTime());
  stepBackward(prev, normalized, anchorDay);
  return prev;
}

/**
 * First occurrence of the series on or after `startOfDay`. Used to bring a
 * missed repeating item back to today instead of leaving it stuck in the past.
 * Returns the input unchanged when it is already on/after `startOfDay`.
 */
export function rollForwardToDay(
  dueAt: Date,
  repeatRule: string | null | undefined,
  startOfDay: Date,
  anchorDay?: number | null,
): Date | null {
  const normalized = normalizeRepeatRule(repeatRule);
  if (!normalized) return null;
  const next = new Date(dueAt.getTime());
  let iterations = 0;
  while (next.getTime() < startOfDay.getTime() && iterations < 2000) {
    stepForward(next, normalized, anchorDay);
    iterations += 1;
  }
  return next;
}

/** Day of month to anchor monthly/yearly series on; null for other rules. */
export function repeatAnchorDayFor(dueAt: Date | null | undefined, repeatRule: string | null | undefined): number | null {
  const normalized = normalizeRepeatRule(repeatRule);
  if (!dueAt || (normalized !== 'Her ay' && normalized !== 'Her yıl')) return null;
  return dueAt.getDate();
}

export function isRepeating(repeatRule: string | null | undefined): boolean {
  return normalizeRepeatRule(repeatRule) !== null;
}

export function formatDayOfWeekShort(date: Date | null | undefined): string | null {
  if (!date || isNaN(date.getTime())) return null;
  const label = new Intl.DateTimeFormat('tr-TR', { weekday: 'short' }).format(date);
  return label.replace(/\.$/, '');
}

/**
 * Returns the short day of week (e.g. "Cum", "Sal", "Per") for repeating items,
 * EXCEPT when the recurrence is "Her gün" (as daily repeats every day).
 */
export function getRecurrenceDayBadge(
  repeatRule: string | null | undefined,
  date: Date | null | undefined,
): string | null {
  const normalized = normalizeRepeatRule(repeatRule);
  if (!normalized || normalized === 'Her gün') return null;
  return formatDayOfWeekShort(date);
}

/**
 * Moves `date` forward one period at a time while it lands on an occurrence
 * that is already completed (e.g. days ticked off ahead of time), so the
 * series never schedules a day the user has already done.
 */
export function skipCompletedOccurrences(
  date: Date,
  repeatRule: string | null | undefined,
  completedOccurrenceMs: ReadonlySet<number>,
  anchorDay?: number | null,
): Date {
  let next = date;
  let guard = 0;
  while (completedOccurrenceMs.has(next.getTime()) && guard < 500) {
    const stepped = calculateNextDueDate(next, repeatRule, next, anchorDay);
    if (!stepped) break;
    next = stepped;
    guard += 1;
  }
  return next;
}

/**
 * For a series that fell behind (dueAt before `startOfDay`): the occurrences
 * that passed without being done (`missed`, oldest first) and the first
 * occurrence on/after `startOfDay` that is not already done (`current`).
 * A series that is not behind returns no missed days and `current = dueAt`.
 */
export function catchUpOccurrences(
  dueAt: Date,
  repeatRule: string | null | undefined,
  startOfDay: Date,
  completedOccurrenceMs: ReadonlySet<number> = new Set(),
  anchorDay?: number | null,
): { missed: Date[]; current: Date } {
  const missed: Date[] = [];
  let cursor = new Date(dueAt.getTime());
  let guard = 0;
  while (cursor.getTime() < startOfDay.getTime() && guard < 2000) {
    if (!completedOccurrenceMs.has(cursor.getTime())) missed.push(new Date(cursor.getTime()));
    const stepped = calculateNextDueDate(cursor, repeatRule, cursor, anchorDay);
    if (!stepped) break;
    cursor = stepped;
    guard += 1;
  }
  return { missed, current: skipCompletedOccurrences(cursor, repeatRule, completedOccurrenceMs, anchorDay) };
}
