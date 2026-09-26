import { isCompletedToday } from '../../core/data/firestore-values.ts';
import { isRepeating } from './recurrence.ts';
import type { ReminderItem } from './reminder.ts';

export type ReminderSections = {
  todayItems: ReminderItem[];
  upcomingItems: ReminderItem[];
  pastItems: ReminderItem[];
};

/** Splits reminders into the Bugün / Yaklaşan / Geçmiş sections. */
export function groupReminders(items: ReminderItem[], now: Date = new Date()): ReminderSections {
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const endOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999).getTime();

  const todayItems: ReminderItem[] = [];
  const upcomingItems: ReminderItem[] = [];
  const pastItems: ReminderItem[] = [];

  for (const item of items) {
    if (item.status === 'completed') {
      pastItems.push(item);
      continue;
    }

    if (isCompletedToday(item.lastCompletedAt, now)) {
      // Today's occurrence is done: show it in Geçmiş...
      pastItems.push({ ...item, status: 'completed', dueAt: item.lastCompletedAt ?? item.dueAt });
      // ...and a repeating series still has its next occurrence to show
      // (it used to disappear from Yaklaşan until the next day).
      if (!isRepeating(item.repeatRule)) continue;
    }

    if (!item.dueAt) {
      todayItems.push(item);
      continue;
    }

    const dueTime = item.dueAt.getTime();
    if (dueTime < startOfToday && isRepeating(item.repeatRule)) {
      // Missed repeating reminder: still due today, not history. Storage is
      // rolled forward by ImportantAlarmSync.
      todayItems.push(item);
    } else if (dueTime < startOfToday) {
      pastItems.push(item);
    } else if (dueTime <= endOfToday) {
      todayItems.push(item);
    } else {
      upcomingItems.push(item);
    }
  }

  return { todayItems, upcomingItems, pastItems };
}
