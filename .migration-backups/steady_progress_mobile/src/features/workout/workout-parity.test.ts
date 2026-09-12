import assert from 'node:assert/strict';
import test from 'node:test';
import { MemoryDataGateway } from '../../core/data/memory-data-gateway.ts';
import {
  exerciseLogFromDocument,
  startOfLocalWeek,
  type ExerciseLog,
  type Workout,
} from './workout.ts';
import { WorkoutRepository } from './workout-repository.ts';

test('workout document parsing preserves Flutter defaults and numeric coercion', () => {
  const log = exerciseLogFromDocument('log-1', {
    workoutId: 'workout-1',
    name: 'Bench press',
    sets: 3.8,
    reps: 10,
    weight: 42.5,
    isPersonalRecord: true,
  });
  assert.deepEqual(log, {
    id: 'log-1',
    workoutId: 'workout-1',
    name: 'Bench press',
    sets: 3,
    reps: 10,
    weight: 42.5,
    isPersonalRecord: true,
  });
});

test('week calculation starts on Monday at local midnight', () => {
  const monday = startOfLocalWeek(new Date(2026, 8, 9, 18, 30));
  assert.deepEqual(
    [monday.getFullYear(), monday.getMonth(), monday.getDate(), monday.getHours()],
    [2026, 8, 7, 0],
  );
});

test('workout repository logs exercises and removes their documents with the workout', async () => {
  const gateway = new MemoryDataGateway('preview-user');
  const repository = new WorkoutRepository(gateway, 'preview-user');
  let workouts: Workout[] = [];
  let logs: ExerciseLog[] = [];
  const stopWorkouts = repository.watchWorkouts(
    (items) => { workouts = items; },
    (error) => assert.fail(String(error)),
  );
  const stopLogs = repository.watchExerciseLogs(
    (items) => { logs = items; },
    (error) => assert.fail(String(error)),
  );

  const id = await repository.logWorkout({
    name: 'Upper body',
    date: new Date(2026, 8, 8),
    exercises: [{ name: 'Bench press', sets: 3, reps: 10, weight: 40 }],
  });
  assert.equal(workouts[0].id, id);
  assert.equal(logs[0].workoutId, id);
  assert.equal(logs[0].name, 'Bench press');

  await repository.deleteWorkout(id);
  assert.deepEqual(workouts, []);
  assert.deepEqual(logs, []);
  stopWorkouts();
  stopLogs();
});
