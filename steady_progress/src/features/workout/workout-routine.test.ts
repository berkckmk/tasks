import test from 'node:test';
import assert from 'node:assert/strict';
import {
  WEEKLY_WORKOUT_ROUTINE,
  getTodayRoutine,
} from './workout-routine.ts';

test('WEEKLY_WORKOUT_ROUTINE contains all 7 days with required details', () => {
  assert.equal(WEEKLY_WORKOUT_ROUTINE.length, 7);

  // Check Monday (Pazartesi)
  const monday = WEEKLY_WORKOUT_ROUTINE.find((d) => d.dayId === 'mon');
  assert.ok(monday);
  assert.equal(monday.focus, 'İtiş');
  assert.equal(monday.isRestDay, false);
  assert.equal(monday.exercises.length, 6);
  assert.equal(monday.exercises[0].name, 'Plate Loaded Chest Press');
  assert.equal(monday.exercises[0].intensityNote, 'RIR 1');

  // Check Tuesday (Salı)
  const tuesday = WEEKLY_WORKOUT_ROUTINE.find((d) => d.dayId === 'tue');
  assert.ok(tuesday);
  assert.equal(tuesday.focus, 'Çekiş & Bacak');
  assert.equal(tuesday.isRestDay, false);
  assert.equal(tuesday.exercises.length, 7);
  assert.equal(tuesday.exercises[0].name, 'Lat Pulldown');

  // Check Wednesday (Çarşamba) - Rest
  const wednesday = WEEKLY_WORKOUT_ROUTINE.find((d) => d.dayId === 'wed');
  assert.ok(wednesday);
  assert.equal(wednesday.isRestDay, true);
  assert.equal(wednesday.focus, 'Dinlenme (Rest)');

  // Check Thursday (Perşembe)
  const thursday = WEEKLY_WORKOUT_ROUTINE.find((d) => d.dayId === 'thu');
  assert.ok(thursday);
  assert.equal(thursday.focus, 'İtiş');
  assert.equal(thursday.exercises.length, 6);

  // Check Friday (Cuma)
  const friday = WEEKLY_WORKOUT_ROUTINE.find((d) => d.dayId === 'fri');
  assert.ok(friday);
  assert.equal(friday.focus, 'Çekiş & Bacak');
  assert.equal(friday.exercises.length, 7);

  // Check Saturday (Cumartesi) & Sunday (Pazar) - Rest
  const saturday = WEEKLY_WORKOUT_ROUTINE.find((d) => d.dayId === 'sat');
  assert.ok(saturday);
  assert.equal(saturday.isRestDay, true);

  const sunday = WEEKLY_WORKOUT_ROUTINE.find((d) => d.dayId === 'sun');
  assert.ok(sunday);
  assert.equal(sunday.isRestDay, true);
});

test('getTodayRoutine returns matching day routine based on Date', () => {
  // Monday: 2026-10-19 was Monday
  const mondayDate = new Date('2026-10-19T10:00:00Z');
  const mondayRoutine = getTodayRoutine(mondayDate);
  assert.equal(mondayRoutine.dayId, 'mon');

  // Tuesday: 2026-10-20 was Tuesday
  const tuesdayDate = new Date('2026-10-20T10:00:00Z');
  const tuesdayRoutine = getTodayRoutine(tuesdayDate);
  assert.equal(tuesdayRoutine.dayId, 'tue');
});
