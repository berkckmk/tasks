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
  assert.equal(monday.focus, 'İtiş 1');
  assert.equal(monday.isRestDay, false);
  assert.equal(monday.exercises.length, 8);
  assert.equal(monday.exercises[0].name, 'Plate Loaded Chest Press');
  assert.equal(monday.exercises[0].muscleGroup, 'Göğüs (6 Set)');
  assert.equal(monday.exercises[0].intensityNote, 'Orta/Genel göğüs, RIR 1');
  assert.equal(monday.exercises[3].name, 'Shoulder Press Machine');
  assert.equal(monday.exercises[3].muscleGroup, 'Omuz');
  assert.equal(monday.exercises[5].name, 'Cable Triceps Pushdown (Düz/V Bar)');
  assert.equal(monday.exercises[5].muscleGroup, 'Arka Kol (6 Set)');

  // Check Tuesday (Salı)
  const tuesday = WEEKLY_WORKOUT_ROUTINE.find((d) => d.dayId === 'tue');
  assert.ok(tuesday);
  assert.equal(tuesday.focus, 'Çekiş & Bacak 1');
  assert.equal(tuesday.isRestDay, false);
  assert.equal(tuesday.exercises.length, 9);
  assert.equal(tuesday.exercises[0].name, 'Lat Pulldown (Geniş Tutuş)');
  assert.equal(tuesday.exercises[0].muscleGroup, 'Sırt (6 Set)');
  assert.equal(tuesday.exercises[3].name, 'Incline Dumbbell Curl');
  assert.equal(tuesday.exercises[3].muscleGroup, 'Ön Kol (6 Set)');
  assert.equal(tuesday.exercises[6].name, 'Seated Leg Curl');
  assert.equal(tuesday.exercises[6].muscleGroup, 'Bacak (6 Set) (Sakin / Düşük Tempo)');

  // Check Wednesday (Çarşamba) - Rest
  const wednesday = WEEKLY_WORKOUT_ROUTINE.find((d) => d.dayId === 'wed');
  assert.ok(wednesday);
  assert.equal(wednesday.isRestDay, true);
  assert.equal(wednesday.focus, 'Dinlenme (Rest)');
  assert.equal(wednesday.notes, 'Toparlanma / CNS dinlenmesi');

  // Check Thursday (Perşembe)
  const thursday = WEEKLY_WORKOUT_ROUTINE.find((d) => d.dayId === 'thu');
  assert.ok(thursday);
  assert.equal(thursday.focus, 'İtiş 2');
  assert.equal(thursday.exercises.length, 8);
  assert.equal(thursday.exercises[0].name, 'Incline Chest Press Machine (Farklı)');

  // Check Friday (Cuma)
  const friday = WEEKLY_WORKOUT_ROUTINE.find((d) => d.dayId === 'fri');
  assert.ok(friday);
  assert.equal(friday.focus, 'Çekiş & Bacak 2');
  assert.equal(friday.exercises.length, 9);
  assert.equal(friday.exercises[0].name, 'Close Grip / Neutral Lat Pulldown (Farklı)');

  // Check Saturday (Cumartesi) & Sunday (Pazar) - Rest
  const saturday = WEEKLY_WORKOUT_ROUTINE.find((d) => d.dayId === 'sat');
  assert.ok(saturday);
  assert.equal(saturday.isRestDay, true);
  assert.equal(saturday.focus, 'Dinlenme');

  const sunday = WEEKLY_WORKOUT_ROUTINE.find((d) => d.dayId === 'sun');
  assert.ok(sunday);
  assert.equal(sunday.isRestDay, true);
  assert.equal(sunday.focus, 'Dinlenme (Rest)');
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
