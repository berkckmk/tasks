import assert from 'node:assert/strict';
import test from 'node:test';
import { habitFromDocument } from '../habits/habit.ts';
import { reminderFromDocument } from '../reminders/reminder.ts';
import { taskFromDocument } from '../tasks/task-item.ts';
import { buildTodayEntries } from './today.ts';

test('Today combines only today records and sorts incomplete timed rows first', () => {
  const now = new Date(2026, 8, 9, 12);
  const habits = [{ ...habitFromDocument('habit', { name: 'Anytime habit' }), isCompletedToday: false }];
  const tasks = [
    taskFromDocument('today-task', { title: 'All-day task', dueDate: new Date(2026, 8, 9), allDay: true }),
    taskFromDocument('tomorrow-task', { title: 'Tomorrow', dueDate: new Date(2026, 8, 10), allDay: true }),
  ];
  const reminders = [
    reminderFromDocument('timed', { title: 'Early reminder', dueAt: new Date(2026, 8, 9, 9), status: 'scheduled' }),
    reminderFromDocument('done', { title: 'Done reminder', dueAt: new Date(2026, 8, 9, 8), status: 'completed' }),
  ];
  const entries = buildTodayEntries({ habits, tasks, reminders, now });
  assert.deepEqual(entries.map((entry) => entry.id), ['timed', 'today-task', 'habit', 'done']);
  assert.equal(entries.some((entry) => entry.id === 'tomorrow-task'), false);
});

test('Today shows repeating reminders completed today as done, and pending tomorrow', () => {
  const today = new Date(2026, 8, 11, 12, 0, 0);
  const tomorrow = new Date(2026, 8, 12, 12, 0, 0);

  // A daily reminder that was completed today and its dueAt advanced to tomorrow
  const repeatingReminder = reminderFromDocument('daily-med', {
    title: 'Medicine',
    dueAt: new Date(2026, 8, 12, 9, 0, 0), // advanced to tomorrow
    status: 'scheduled',
    repeatRule: 'Her gün',
    lastCompletedAt: new Date(2026, 8, 11, 9, 5, 0), // completed today
  });

  // Check today's entries
  const todayEntries = buildTodayEntries({
    habits: [],
    tasks: [],
    reminders: [repeatingReminder],
    now: today,
  });
  assert.equal(todayEntries.length, 1);
  assert.equal(todayEntries[0].id, 'daily-med');
  assert.equal(todayEntries[0].done, true);

  // Check tomorrow's entries
  const tomorrowEntries = buildTodayEntries({
    habits: [],
    tasks: [],
    reminders: [repeatingReminder],
    now: tomorrow,
  });
  assert.equal(tomorrowEntries.length, 1);
  assert.equal(tomorrowEntries[0].id, 'daily-med');
  assert.equal(tomorrowEntries[0].done, false);
});

