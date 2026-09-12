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

function stepForward(d: Date, rule: RepeatRule) {
  if (rule === 'Her gün') {
    d.setDate(d.getDate() + 1);
  } else if (rule === 'Hafta içi (Pzt-Cum)') {
    do {
      d.setDate(d.getDate() + 1);
    } while (d.getDay() === 0 || d.getDay() === 6);
  } else if (rule === 'Her hafta') {
    d.setDate(d.getDate() + 7);
  } else if (rule === 'Her ay') {
    const targetDay = d.getDate();
    d.setDate(1);
    d.setMonth(d.getMonth() + 1);
    const maxDays = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
    d.setDate(Math.min(targetDay, maxDays));
  } else if (rule === 'Her yıl') {
    const targetDay = d.getDate();
    const targetMonth = d.getMonth();
    d.setDate(1);
    d.setFullYear(d.getFullYear() + 1);
    d.setMonth(targetMonth);
    const maxDays = new Date(d.getFullYear(), targetMonth + 1, 0).getDate();
    d.setDate(Math.min(targetDay, maxDays));
  }
}

function stepBackward(d: Date, rule: RepeatRule) {
  if (rule === 'Her gün') {
    d.setDate(d.getDate() - 1);
  } else if (rule === 'Hafta içi (Pzt-Cum)') {
    do {
      d.setDate(d.getDate() - 1);
    } while (d.getDay() === 0 || d.getDay() === 6);
  } else if (rule === 'Her hafta') {
    d.setDate(d.getDate() - 7);
  } else if (rule === 'Her ay') {
    const targetDay = d.getDate();
    d.setDate(1);
    d.setMonth(d.getMonth() - 1);
    const maxDays = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
    d.setDate(Math.min(targetDay, maxDays));
  } else if (rule === 'Her yıl') {
    const targetDay = d.getDate();
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
): Date | null {
  if (!currentDueAt) return null;
  const normalized = normalizeRepeatRule(repeatRule);
  if (!normalized) return null;

  const next = new Date(currentDueAt.getTime());
  // Step at least once to the next scheduled slot
  stepForward(next, normalized);

  // If the next slot is still in the past or right now, advance until it is in the future
  let iterations = 0;
  while (next.getTime() <= fromDate.getTime() && iterations < 500) {
    stepForward(next, normalized);
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
): Date | null {
  if (!currentDueAt) return null;
  const normalized = normalizeRepeatRule(repeatRule);
  if (!normalized) return null;

  const prev = new Date(currentDueAt.getTime());
  stepBackward(prev, normalized);
  return prev;
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
