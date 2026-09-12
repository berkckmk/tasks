import { habitIsScheduledOn, parseHabitTime, type Habit } from '../habits/habit.ts';
import type { ReminderItem } from '../reminders/reminder.ts';
import type { TaskItem } from '../tasks/task-item.ts';

export type TodayKind = 'reminder' | 'task' | 'habit';
export type TodayEntry = {
  id: string;
  kind: TodayKind;
  title: string;
  note: string;
  time: Date | null;
  done: boolean;
};

function sameLocalDay(left: Date, right: Date) {
  return left.getFullYear() === right.getFullYear()
    && left.getMonth() === right.getMonth()
    && left.getDate() === right.getDate();
}

export function compareTodayEntries(left: TodayEntry, right: TodayEntry) {
  if (left.done !== right.done) return left.done ? 1 : -1;
  if (!left.time && !right.time) return left.title.localeCompare(right.title);
  if (!left.time) return 1;
  if (!right.time) return -1;
  return left.time.getTime() - right.time.getTime();
}

export function buildTodayEntries({
  habits,
  tasks,
  reminders,
  now = new Date(),
}: {
  habits: Habit[];
  tasks: TaskItem[];
  reminders: ReminderItem[];
  now?: Date;
}) {
  const entries: TodayEntry[] = [];
  for (const reminder of reminders) {
    const isDueToday = reminder.dueAt && sameLocalDay(reminder.dueAt, now);
    const wasCompletedToday = reminder.lastCompletedAt && sameLocalDay(reminder.lastCompletedAt, now);
    if (isDueToday) {
      entries.push({ id: reminder.id, kind: 'reminder', title: reminder.title, note: reminder.message, time: reminder.dueAt, done: reminder.status === 'completed' });
    } else if (wasCompletedToday && reminder.repeatRule && reminder.repeatRule !== 'Tekrarlama') {
      entries.push({ id: reminder.id, kind: 'reminder', title: reminder.title, note: reminder.message, time: reminder.lastCompletedAt ?? null, done: true });
    }
  }
  for (const task of tasks) {
    const isDueToday = task.dueDate && sameLocalDay(task.dueDate, now);
    const wasCompletedToday = task.lastCompletedAt && sameLocalDay(task.lastCompletedAt, now);
    if (isDueToday) {
      entries.push({ id: task.id, kind: 'task', title: task.title, note: task.description, time: task.allDay ? null : task.dueDate, done: task.status === 'done' });
    } else if (wasCompletedToday && task.repeatRule && task.repeatRule !== 'Tekrarlama') {
      entries.push({ id: task.id, kind: 'task', title: task.title, note: task.description, time: task.allDay ? null : (task.lastCompletedAt ?? null), done: true });
    }
  }
  for (const habit of habits) {
    if (!habitIsScheduledOn(habit, now)) continue;
    entries.push({ id: habit.id, kind: 'habit', title: habit.name, note: '', time: parseHabitTime(habit.reminderTimeLabel, now), done: habit.isCompletedToday });
  }
  return entries.sort(compareTodayEntries);

}
