import assert from 'node:assert/strict';
import test from 'node:test';
import { habitFromDocument } from '../habits/habit.ts';
import { reminderFromDocument } from '../reminders/reminder.ts';
import { taskFromDocument } from '../tasks/task-item.ts';
import { buildWidgetSnapshot, widgetItemLimit } from './widget-snapshot.ts';

test('live widget snapshot matches Flutter date scope, ordering and counters', () => {
  const now = new Date(2026, 8, 9, 12);
  const habits = [
    { ...habitFromDocument('done', { name: 'Done habit', reminderTimeLabel: '08:00' }), isCompletedToday: true, streak: 4 },
    { ...habitFromDocument('later', { name: 'Later habit' }), streak: 1 },
  ];
  const tasks = [
    taskFromDocument('all-day', { title: 'All day', status: 'todo', allDay: true }),
    taskFromDocument('timed', { title: 'Timed', status: 'todo', allDay: false, dueDate: new Date(2026, 8, 9, 9) }),
    taskFromDocument('done-task', { title: 'Done', status: 'done' }),
  ];
  const reminders = [
    reminderFromDocument('overdue', { title: 'Overdue', dueAt: new Date(2026, 8, 8, 10), status: 'scheduled' }),
    reminderFromDocument('old-done', { title: 'Old done', dueAt: new Date(2026, 8, 8, 10), status: 'completed' }),
    reminderFromDocument('today', { title: 'Today', dueAt: new Date(2026, 8, 9, 15), status: 'scheduled' }),
    reminderFromDocument('future', { title: 'Future', dueAt: new Date(2026, 8, 10, 10), status: 'scheduled' }),
  ];
  const snapshot = buildWidgetSnapshot({ habits, tasks, reminders, now, formatTime: (date) => `${date.getHours()}:00` });
  const items = JSON.parse(snapshot.items);
  assert.deepEqual(snapshot, { ...snapshot, habitsDone: 1, habitsTotal: 2, tasksDone: 1, tasksTotal: 3, bestStreak: 4 });
  assert.deepEqual(items.tasks.map((row: { id: string }) => row.id), ['timed', 'all-day', 'done-task']);
  assert.deepEqual(items.reminders.map((row: { id: string }) => row.id), ['overdue', 'today']);
});

test('each widget collection is limited to twelve rows after sorting', () => {
  const habits = Array.from({ length: widgetItemLimit + 5 }, (_, index) => habitFromDocument(String(index), { name: String(index).padStart(2, '0') }));
  const snapshot = buildWidgetSnapshot({ habits, tasks: [], reminders: [] });
  const items = JSON.parse(snapshot.items);
  assert.equal(items.habits.length, widgetItemLimit);
  assert.equal(snapshot.habitsTotal, widgetItemLimit + 5);
});

test('defaultTime formats times in 24-hour Europe/Istanbul format', () => {
  // Test 15:45 in Europe/Istanbul
  const date = new Date('2026-09-11T12:45:00Z'); // 12:45 UTC = 15:45 in Europe/Istanbul (+3)
  const reminders = [
    reminderFromDocument('istanbul-time', { title: 'Istanbul Reminder', dueAt: date, status: 'scheduled' }),
  ];
  const snapshot = buildWidgetSnapshot({ habits: [], tasks: [], reminders, now: date });
  const items = JSON.parse(snapshot.items);
  assert.equal(items.reminders[0].time, '15:45');
  assert.ok(!items.reminders[0].time.includes('PM'));
  assert.ok(!items.reminders[0].time.includes('AM'));
});

test('snapshot carries reference date and rolls over habit completion on day change', () => {
  const day1 = new Date(2026, 8, 13, 20); // Sept 13, 2026, 8:00 PM
  const day2 = new Date(2026, 8, 14, 8);  // Sept 14, 2026, 8:00 AM (next morning)

  const habit = { ...habitFromDocument('h1', { name: 'Morning run' }), streak: 5 };

  // On day 1 (completed)
  const snapDay1 = buildWidgetSnapshot({
    habits: [{ ...habit, isCompletedToday: true }],
    tasks: [],
    reminders: [],
    now: day1,
  });
  assert.equal(snapDay1.date, '2026-09-13');
  assert.equal(snapDay1.habitsDone, 1);

  // On day 2 (next morning, before any logs created for day 2)
  const snapDay2 = buildWidgetSnapshot({
    habits: [{ ...habit, isCompletedToday: false }],
    tasks: [],
    reminders: [],
    now: day2,
  });
  assert.equal(snapDay2.date, '2026-09-14');
  assert.equal(snapDay2.habitsDone, 0);
  assert.equal(snapDay2.bestStreak, 5);
});
