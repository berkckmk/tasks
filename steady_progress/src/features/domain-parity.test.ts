import assert from 'node:assert/strict';
import test from 'node:test';
import {
  formatHabitTime,
  habitFromDocument,
  habitHasFixedDays,
  habitIsScheduledOn,
  mergeHabitsWithLogs,
  parseHabitTime,
  type HabitLog,
} from './habits/habit.ts';
import { learningItemFromDocument } from './learning/learning-item.ts';
import { effectiveReminderPriority, reminderFromDocument } from './reminders/reminder.ts';
import { taskFromDocument, taskSpansDays } from './tasks/task-item.ts';

test('legacy tasks remain all-day and malformed enums keep Flutter defaults', () => {
  const task = taskFromDocument('t1', { title: 'Plan', priority: 'unknown', status: 42 });
  assert.equal(task.allDay, true);
  assert.equal(task.priority, 'medium');
  assert.equal(task.status, 'todo');
});

test('task date ranges use local calendar days rather than elapsed hours', () => {
  const task = taskFromDocument('t1', {
    startDate: { toDate: () => new Date(2026, 8, 8, 22) },
    dueDate: { toDate: () => new Date(2026, 8, 9, 1) },
  });
  assert.equal(taskSpansDays(task), true);
});

test('habit streak may end yesterday and ignores incomplete logs', () => {
  const habit = habitFromDocument('h1', { name: 'Walk' });
  const logs: HabitLog[] = [
    { id: '1', habitId: 'h1', date: '2026-09-07', completed: true, completedAt: null },
    { id: '2', habitId: 'h1', date: '2026-09-06', completed: true, completedAt: null },
    { id: '3', habitId: 'h1', date: '2026-09-05', completed: false, completedAt: null },
  ];
  const [merged] = mergeHabitsWithLogs([habit], logs, new Date(2026, 8, 8));
  assert.equal(merged.streak, 2);
  assert.equal(merged.isCompletedToday, false);
});

test('Weekdays is fixed to Monday-Friday while count-per-week habits remain available', () => {
  const saturday = new Date(2026, 8, 5);
  const tuesday = new Date(2026, 8, 1);
  const weekdays = habitFromDocument('weekdays', { frequencyLabel: ' Weekdays ' });
  assert.equal(habitIsScheduledOn(weekdays, tuesday), true);
  assert.equal(habitIsScheduledOn(weekdays, saturday), false);
  assert.equal(habitHasFixedDays(weekdays), true);

  for (const frequencyLabel of ['Daily', 'Weekly', '3x / week', '5x / week', 'Legacy value']) {
    const habit = habitFromDocument(frequencyLabel, { frequencyLabel });
    assert.equal(habitIsScheduledOn(habit, saturday), true);
    assert.equal(habitHasFixedDays(habit), false);
  }
});

test('habit reminder labels preserve legacy 12-hour values and save a canonical 24-hour value', () => {
  const day = new Date(2026, 8, 1);
  assert.deepEqual(parseHabitTime('7:30 PM', day), new Date(2026, 8, 1, 19, 30));
  assert.deepEqual(parseHabitTime('12:00 AM', day), new Date(2026, 8, 1, 0, 0));
  assert.equal(parseHabitTime('25:90', day), null);
  assert.equal(formatHabitTime(new Date(2026, 8, 1, 8, 5)), '08:05');
});

test('medicine reminders inherit important priority exactly like Flutter', () => {
  assert.equal(effectiveReminderPriority('Vitamin', '', 'normal'), 'important');
  assert.equal(effectiveReminderPriority('Vitamin', '', 'low'), 'low');
  assert.equal(reminderFromDocument('r1', { title: 'İlaç', priority: 'normal' }).priority, 'important');
});

test('learning parser bounds ratings and stringifies legacy takeaways', () => {
  const learning = learningItemFromDocument('l1', { rating: 9, keyTakeaways: ['One', 2] });
  assert.equal(learning.rating, 5);
  assert.deepEqual(learning.keyTakeaways, ['One', '2']);
});
