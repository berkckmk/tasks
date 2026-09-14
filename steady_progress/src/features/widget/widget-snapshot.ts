import { formatLogDate, type Habit } from '../habits/habit.ts';
import type { ReminderItem } from '../reminders/reminder.ts';
import type { TaskItem } from '../tasks/task-item.ts';
import type { WidgetItems, WidgetRow, WidgetSnapshot } from './widget-contract.ts';

export const widgetItemLimit = 12;

type SnapshotInput = {
  habits: Habit[];
  tasks: TaskItem[];
  reminders: ReminderItem[];
  now?: Date;
  formatTime?: (date: Date) => string;
};

function defaultTime(date: Date) {
  return new Intl.DateTimeFormat('tr-TR', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
    timeZone: 'Europe/Istanbul',
  }).format(date);
}

function sameLocalDay(left: Date, right: Date) {
  return left.getFullYear() === right.getFullYear()
    && left.getMonth() === right.getMonth()
    && left.getDate() === right.getDate();
}

function byDoneThenTime(left: WidgetRow, right: WidgetRow) {
  if (Boolean(left.done) !== Boolean(right.done)) return left.done ? 1 : -1;
  const leftTime = left.time ?? '';
  const rightTime = right.time ?? '';
  if (!leftTime && !rightTime) return left.label.localeCompare(right.label);
  if (!leftTime) return 1;
  if (!rightTime) return -1;
  return leftTime.localeCompare(rightTime);
}

/** Mirrors the final Flutter snapshot rules consumed by the frozen Kotlin widget. */
export function buildWidgetSnapshot({
  habits,
  tasks,
  reminders,
  now = new Date(),
  formatTime = defaultTime,
}: SnapshotInput): WidgetSnapshot {
  const habitRows: WidgetRow[] = habits.map((habit) => ({
    id: habit.id,
    kind: 'habit',
    label: habit.name,
    ...(habit.isCompletedToday ? { done: true } : {}),
    ...(habit.reminderTimeLabel ? { time: habit.reminderTimeLabel } : {}),
  }));
  const taskRows: WidgetRow[] = tasks.map((task) => ({
    id: task.id,
    kind: 'task',
    label: task.title,
    ...(task.status === 'done' ? { done: true } : {}),
    ...(!task.allDay && task.dueDate ? { time: formatTime(task.dueDate) } : {}),
  }));
  const reminderRows: WidgetRow[] = reminders
    .filter((reminder) => reminder.dueAt && (
      sameLocalDay(reminder.dueAt, now)
      || (reminder.dueAt < now && reminder.status !== 'completed')
    ))
    .map((reminder) => ({
      id: reminder.id,
      kind: 'reminder',
      label: reminder.title,
      ...(reminder.status === 'completed' ? { done: true } : {}),
      time: formatTime(reminder.dueAt!),
    }));
  habitRows.sort(byDoneThenTime);
  taskRows.sort(byDoneThenTime);
  reminderRows.sort(byDoneThenTime);
  const items: WidgetItems = {
    habits: habitRows.slice(0, widgetItemLimit),
    tasks: taskRows.slice(0, widgetItemLimit),
    reminders: reminderRows.slice(0, widgetItemLimit),
  };
  return {
    habitsDone: habits.filter((habit) => habit.isCompletedToday).length,
    habitsTotal: habits.length,
    tasksDone: tasks.filter((task) => task.status === 'done').length,
    tasksTotal: tasks.length,
    bestStreak: habits.reduce((best, habit) => Math.max(best, habit.streak), 0),
    items: JSON.stringify(items),
    date: formatLogDate(now),
  };
}
