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
