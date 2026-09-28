import { isCompletedToday } from '../../core/data/firestore-values.ts';
import { catchUpOccurrences, isRepeating } from './recurrence.ts';
import type { ReminderItem } from './reminder.ts';

export type ReminderSections = {
  todayItems: ReminderItem[];
  upcomingItems: ReminderItem[];
  /** Geçmiş: occurrences that passed without being done. */
  missedItems: ReminderItem[];
  /** Yapılanlar: done items (repeating ones only for ticks made today). */
  doneItems: ReminderItem[];
};

/**
 * Splits reminders into Bugün / Yaklaşan / Geçmiş (not done in time) /
 * Yapılanlar (done). Each reminder has at most one row per section; a
 * repeating reminder's row stands for its most recent day and carries how
 * many days it covers (`rowCount`).
 */
export function groupReminders(items: ReminderItem[], now: Date = new Date()): ReminderSections {
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const endOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999).getTime();

  const todayItems: ReminderItem[] = [];
  const upcomingItems: ReminderItem[] = [];
  const missedItems: ReminderItem[] = [];
  const doneItems: ReminderItem[] = [];

  const placeActive = (item: ReminderItem) => {
    if (!item.dueAt || item.dueAt.getTime() <= endOfToday) todayItems.push(item);
    else upcomingItems.push(item);
  };

  for (const item of items) {
    if (item.status === 'completed') {
      doneItems.push({ ...item, rowRole: 'done' });
      continue;
    }

    if (!isRepeating(item.repeatRule)) {
      if (item.dueAt && item.dueAt < startOfToday) missedItems.push({ ...item, rowRole: 'missed' });
      else placeActive(item);
      continue;
    }

    // Yapılanlar: one row for the days ticked today, showing the latest one.
    const completions = item.completions ?? [];
    const doneToday = completions.filter((entry) => isCompletedToday(entry.completedAt, now));
    if (doneToday.length > 0) {
      const latest = doneToday[doneToday.length - 1];
      doneItems.push({
        ...item,
        status: 'completed',
        dueAt: latest.occurrence,
        lastCompletedAt: latest.completedAt,
        rowRole: 'done',
        rowCount: doneToday.length,
      });
    } else if (completions.length === 0 && isCompletedToday(item.lastCompletedAt, now)) {
      // Completed before occurrences were recorded.
      doneItems.push({ ...item, status: 'completed', dueAt: item.lastCompletedAt ?? item.dueAt, rowRole: 'done' });
    }

    // A series that fell behind is caught up in storage by ImportantAlarmSync;
    // until that write lands the passed days already count as missed here.
    let missed = item.missedOccurrences ?? [];
    let current = item.dueAt;
    if (item.dueAt && item.dueAt < startOfToday) {
      const completed = new Set(completions.map((entry) => entry.occurrence.getTime()));
      const caughtUp = catchUpOccurrences(
        item.snoozedFromDueAt ?? item.dueAt,
        item.repeatRule,
        startOfToday,
        completed,
        item.repeatAnchorDay,
      );
      missed = [...missed, ...caughtUp.missed];
      current = caughtUp.current;
    }

    // Geçmiş: one row for the missed days, showing the latest one.
    if (missed.length > 0) {
      const latestMissed = missed.reduce((a, b) => (b > a ? b : a));
      missedItems.push({ ...item, dueAt: latestMissed, rowRole: 'missed', rowCount: missed.length });
    }

    placeActive(current === item.dueAt ? item : { ...item, dueAt: current });
  }

  return { todayItems, upcomingItems, missedItems, doneItems };
}
