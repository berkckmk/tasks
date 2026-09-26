import { calculateNextDueDate, isRepeating } from './recurrence.ts';
import type { ReminderItem, ReminderPriority } from './reminder.ts';

export type PlannedAlarm = {
  id: string;
  timestampMs: number;
  title: string;
  message: string;
  priority: ReminderPriority;
};

/**
 * The native alarm each reminder should have right now.
 *
 * A future dueAt is used as is. A repeating reminder whose occurrence already
 * passed (missed, or ringing right now) gets its next occurrence, so a missed
 * dose never leaves the series without an alarm. Past one-off reminders get
 * none.
 */
export function planAlarms(items: ReminderItem[], now: Date = new Date()): Map<string, PlannedAlarm> {
  const plan = new Map<string, PlannedAlarm>();
  for (const item of items) {
    if (item.status === 'completed' || item.status === 'missed' || !item.dueAt) continue;
    let at: Date | null = item.dueAt;
    if (at.getTime() <= now.getTime()) {
      at = isRepeating(item.repeatRule)
        ? calculateNextDueDate(item.snoozedFromDueAt ?? item.dueAt, item.repeatRule, now, item.repeatAnchorDay)
        : null;
    }
    if (!at) continue;
    plan.set(item.id, {
      id: item.id,
      timestampMs: at.getTime(),
      title: item.title,
      message: item.message,
      priority: item.priority,
    });
  }
  return plan;
}

/**
 * Alarms to cancel after a snapshot: reminders this session had scheduled that
 * are now deleted (e.g. on the web) or completed. Reminders that merely became
 * overdue are left alone, because cancelling also silences an alarm that is
 * ringing right now.
 */
export function alarmsToCancel(previouslyPlanned: Iterable<string>, items: ReminderItem[]): string[] {
  const byId = new Map(items.map((item) => [item.id, item]));
  const result: string[] = [];
  for (const id of previouslyPlanned) {
    const item = byId.get(id);
    if (!item || item.status === 'completed') result.push(id);
  }
  return result;
}
