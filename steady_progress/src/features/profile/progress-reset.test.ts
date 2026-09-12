import test from 'node:test';
import assert from 'node:assert/strict';
import { MemoryDataGateway } from '../../core/data/memory-data-gateway.ts';
import { resetProgressForAreas } from './progress-reset.ts';

test('resetProgressForAreas resets completed tasks and reminders', async () => {
  const gateway = new MemoryDataGateway('test-user');

  // Add tasks
  await gateway.setDocument('users/test-user/tasks/task-1', {
    title: 'Task 1',
    status: 'done',
  });
  await gateway.setDocument('users/test-user/tasks/task-2', {
    title: 'Task 2',
    status: 'inProgress',
  });
  await gateway.setDocument('users/test-user/tasks/task-3', {
    title: 'Task 3',
    status: 'todo',
  });

  // Add reminders
  await gateway.setDocument('users/test-user/reminders/rem-1', {
    title: 'Reminder 1',
    status: 'completed',
  });
  await gateway.setDocument('users/test-user/reminders/rem-2', {
    title: 'Reminder 2',
    status: 'scheduled',
  });

  // Reset tasks and reminders
  await resetProgressForAreas(gateway, 'test-user', ['tasks', 'reminders']);

  const t1 = await gateway.getDocument('users/test-user/tasks/task-1');
  const t2 = await gateway.getDocument('users/test-user/tasks/task-2');
  const t3 = await gateway.getDocument('users/test-user/tasks/task-3');
  assert.equal(t1?.data.status, 'todo');
  assert.equal(t2?.data.status, 'todo');
  assert.equal(t3?.data.status, 'todo');

  const r1 = await gateway.getDocument('users/test-user/reminders/rem-1');
  const r2 = await gateway.getDocument('users/test-user/reminders/rem-2');
  assert.equal(r1?.data.status, 'scheduled');
  assert.equal(r2?.data.status, 'scheduled');
});

test('resetProgressForAreas deletes habit logs and workouts', async () => {
  const gateway = new MemoryDataGateway('test-user');

  await gateway.setDocument('users/test-user/habit_logs/log-1', {
    habitId: 'h1',
    date: '2026-09-09',
  });
  await gateway.setDocument('users/test-user/workouts/w-1', {
    name: 'Chest day',
  });
  await gateway.setDocument('users/test-user/exercise_logs/el-1', {
    name: 'Bench press',
  });

  await resetProgressForAreas(gateway, 'test-user', ['habits', 'workout']);

  const log = await gateway.getDocument('users/test-user/habit_logs/log-1');
  const workout = await gateway.getDocument('users/test-user/workouts/w-1');
  const exLog = await gateway.getDocument('users/test-user/exercise_logs/el-1');

  assert.equal(log, null);
  assert.equal(workout, null);
  assert.equal(exLog, null);
});
