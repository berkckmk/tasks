import test from 'node:test';
import assert from 'node:assert/strict';
import {
  sameLocalDay,
  isReminderDueToday,
  isTaskDueToday,
  countTodayPendingItems,
} from './web-today-filter.ts';
import type { ReminderItem } from '../reminders/reminder.ts';
import type { TaskItem } from '../tasks/task-item.ts';

const baseReminder: ReminderItem = {
  id: 'r1',
  title: 'Test Reminder',
  message: '',
  dueAt: null,
  status: 'scheduled',
  priority: 'normal',
  starred: false,
  earlyAlertMinutes: null,
  repeatRule: null,
  location: null,
  category: 'General',
  checklist: [],
};

const baseTask: TaskItem = {
  id: 't1',
  title: 'Test Task',
  description: '',
  startDate: null,
  dueDate: null,
  allDay: false,
  priority: 'medium',
  status: 'todo',
  relatedGoalId: null,
  syncEnabled: false,
  googleCalendarEventId: null,
  lastSyncedAt: null,
};

test('web-today-filter: correctly matches same local day', () => {
  const d1 = new Date(2026, 8, 15, 10, 30);
  const d2 = new Date(2026, 8, 15, 22, 0);
  const d3 = new Date(2026, 8, 16, 0, 1);
  assert.equal(sameLocalDay(d1, d2), true);
  assert.equal(sameLocalDay(d1, d3), false);
});

test('web-today-filter: isReminderDueToday only includes today items', () => {
  const today = new Date(2026, 8, 15, 14, 0);
  const dueToday = new Date(2026, 8, 15, 18, 0);
  const dueTomorrow = new Date(2026, 8, 16, 9, 0);
  const dueYesterday = new Date(2026, 8, 14, 12, 0);

  // Scheduled for today -> true
  assert.equal(
    isReminderDueToday({ ...baseReminder, dueAt: dueToday }, today),
    true,
  );

  // Completed -> false
  assert.equal(
    isReminderDueToday({ ...baseReminder, dueAt: dueToday, status: 'completed' }, today),
    false,
  );

  // Completed today via lastCompletedAt -> false
  assert.equal(
    isReminderDueToday({ ...baseReminder, dueAt: dueToday, lastCompletedAt: today }, today),
    false,
  );

  // Tomorrow or yesterday -> false
  assert.equal(
    isReminderDueToday({ ...baseReminder, dueAt: dueTomorrow }, today),
    false,
  );
  assert.equal(
    isReminderDueToday({ ...baseReminder, dueAt: dueYesterday }, today),
    false,
  );

  // No date -> false
  assert.equal(
    isReminderDueToday({ ...baseReminder, dueAt: null }, today),
    false,
  );
});

test('web-today-filter: isTaskDueToday only includes today items', () => {
  const today = new Date(2026, 8, 15, 14, 0);
  const dueToday = new Date(2026, 8, 15, 18, 0);
  const dueTomorrow = new Date(2026, 8, 16, 9, 0);
  const dueYesterday = new Date(2026, 8, 14, 12, 0);

  // Task due today -> true
  assert.equal(
    isTaskDueToday({ ...baseTask, dueDate: dueToday }, today),
    true,
  );

  // Task done -> false
  assert.equal(
    isTaskDueToday({ ...baseTask, dueDate: dueToday, status: 'done' }, today),
    false,
  );

  // Task done today via lastCompletedAt -> false
  assert.equal(
    isTaskDueToday({ ...baseTask, dueDate: dueToday, lastCompletedAt: today }, today),
    false,
  );

  // Task due tomorrow or yesterday -> false
  assert.equal(
    isTaskDueToday({ ...baseTask, dueDate: dueTomorrow }, today),
    false,
  );
  assert.equal(
    isTaskDueToday({ ...baseTask, dueDate: dueYesterday }, today),
    false,
  );

  // Undated task -> false
  assert.equal(
    isTaskDueToday({ ...baseTask, dueDate: null, startDate: null }, today),
    false,
  );

  // Multi-day task spanning today -> true
  assert.equal(
    isTaskDueToday({ ...baseTask, startDate: dueYesterday, dueDate: dueTomorrow }, today),
    true,
  );
});

test('web-today-filter: countTodayPendingItems aggregates only today items', () => {
  const today = new Date(2026, 8, 15, 14, 0);
  const dueToday = new Date(2026, 8, 15, 18, 0);
  const dueTomorrow = new Date(2026, 8, 16, 9, 0);

  const reminders: ReminderItem[] = [
    { ...baseReminder, id: 'r1', dueAt: dueToday }, // +1
    { ...baseReminder, id: 'r2', dueAt: dueTomorrow }, // not today
    { ...baseReminder, id: 'r3', dueAt: dueToday, status: 'completed' }, // completed
  ];

  const tasks: TaskItem[] = [
    { ...baseTask, id: 't1', dueDate: dueToday }, // +1
    { ...baseTask, id: 't2', dueDate: dueToday, status: 'done' }, // done
    { ...baseTask, id: 't3', dueDate: null }, // undated
    { ...baseTask, id: 't4', dueDate: dueTomorrow }, // tomorrow
  ];

  const count = countTodayPendingItems({ reminders, tasks, now: today });
  assert.equal(count, 2);
});
