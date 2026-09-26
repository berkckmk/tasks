import { formatLogDate, type Habit } from '../habits/habit.ts';
import { isRepeating } from '../reminders/recurrence.ts';
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

function isTaskDoneToday(task: TaskItem, now: Date) {
  if (task.status === 'done') return true;
  // A completed repeating task is reset to todo with its next dueDate.
  return isRepeating(task.repeatRule) && Boolean(task.lastCompletedAt && sameLocalDay(task.lastCompletedAt, now));
}

/**
 * Tasks that belong on a "today" widget: due today, overdue and still open,
 * undated and still open, or finished today. Older finished tasks and future
 * ones would otherwise inflate the progress count (it used to be every task).
 */
function isTaskForToday(task: TaskItem, now: Date) {
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  if (task.lastCompletedAt && sameLocalDay(task.lastCompletedAt, now)) return true;
  if (!task.dueDate) return task.status !== 'done';
  if (sameLocalDay(task.dueDate, now)) return true;
  return task.dueDate < startOfToday && task.status !== 'done';
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
  const todayTasks = tasks.filter((task) => isTaskForToday(task, now));
  const taskRows: WidgetRow[] = todayTasks.map((task) => ({
    id: task.id,
    kind: 'task',
    label: task.title,
    ...(isTaskDoneToday(task, now) ? { done: true } : {}),
    ...(!task.allDay && task.dueDate ? { time: formatTime(task.dueDate) } : {}),
  }));
  const reminderRows: WidgetRow[] = [];
  for (const reminder of reminders) {
    if (!reminder.dueAt) continue;
    const completedRepeatingToday = isRepeating(reminder.repeatRule)
      && Boolean(reminder.lastCompletedAt && sameLocalDay(reminder.lastCompletedAt, now));
    if (completedRepeatingToday) {
      // Completing moved dueAt to the next occurrence; today's one is done.
      reminderRows.push({
        id: reminder.id,
        kind: 'reminder',
        label: reminder.title,
        done: true,
        time: formatTime(reminder.lastCompletedAt!),
      });
      continue;
    }
    if (sameLocalDay(reminder.dueAt, now) || (reminder.dueAt < now && reminder.status !== 'completed')) {
      reminderRows.push({
        id: reminder.id,
        kind: 'reminder',
        label: reminder.title,
        ...(reminder.status === 'completed' ? { done: true } : {}),
        time: formatTime(reminder.dueAt),
      });
    }
  }
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
    tasksDone: todayTasks.filter((task) => isTaskDoneToday(task, now)).length,
    tasksTotal: todayTasks.length,
    bestStreak: habits.reduce((best, habit) => Math.max(best, habit.streak), 0),
    items: JSON.stringify(items),
    date: formatLogDate(now),
  };
}
