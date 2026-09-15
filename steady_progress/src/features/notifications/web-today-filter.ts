import { isCompletedToday } from '../../core/data/firestore-values.ts';
import type { ReminderItem } from '../reminders/reminder.ts';
import type { TaskItem } from '../tasks/task-item.ts';

export function sameLocalDay(left: Date, right: Date): boolean {
  return (
    left.getFullYear() === right.getFullYear() &&
    left.getMonth() === right.getMonth() &&
    left.getDate() === right.getDate()
  );
}

export function isReminderDueToday(
  reminder: ReminderItem,
  now: Date = new Date(),
): boolean {
  if (reminder.status === 'completed') return false;
  if (isCompletedToday(reminder.lastCompletedAt, now)) return false;
  if (!reminder.dueAt) return false;
  return sameLocalDay(reminder.dueAt, now);
}

export function isTaskDueToday(
  task: TaskItem,
  now: Date = new Date(),
): boolean {
  if (task.status === 'done') return false;
  if (isCompletedToday(task.lastCompletedAt, now)) return false;

  // 1. If dueDate is set
  if (task.dueDate) {
    if (sameLocalDay(task.dueDate, now)) return true;
    // Multi-day task spanning today
    if (task.startDate) {
      const startOfDay = new Date(
        task.startDate.getFullYear(),
        task.startDate.getMonth(),
        task.startDate.getDate(),
      ).getTime();
      const endOfDay = new Date(
        task.dueDate.getFullYear(),
        task.dueDate.getMonth(),
        task.dueDate.getDate(),
        23,
        59,
        59,
        999,
      ).getTime();
      const nowTime = now.getTime();
      if (nowTime >= startOfDay && nowTime <= endOfDay) {
        return true;
      }
    }
    return false;
  }

  // 2. If only startDate is set
  if (task.startDate && sameLocalDay(task.startDate, now)) {
    return true;
  }

  return false;
}

export function countTodayPendingItems({
  reminders,
  tasks,
  now = new Date(),
}: {
  reminders: ReminderItem[];
  tasks: TaskItem[];
  now?: Date;
}): number {
  const reminderCount = reminders.filter((r) => isReminderDueToday(r, now)).length;
  const taskCount = tasks.filter((t) => isTaskDueToday(t, now)).length;
  return reminderCount + taskCount;
}
