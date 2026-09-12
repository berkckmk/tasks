import test from 'node:test';
import assert from 'node:assert/strict';
import {
  calculateNextDueDate,
  calculatePreviousDueDate,
  formatDayOfWeekShort,
  getRecurrenceDayBadge,
  normalizeRepeatRule,
  repeatRules,
} from './recurrence.ts';

test('normalizeRepeatRule maps aliases and returns standard rules', () => {
  assert.equal(normalizeRepeatRule('Her gün'), 'Her gün');
  assert.equal(normalizeRepeatRule('daily'), 'Her gün');
  assert.equal(normalizeRepeatRule('Hafta içi'), 'Hafta içi (Pzt-Cum)');
  assert.equal(normalizeRepeatRule('weekdays'), 'Hafta içi (Pzt-Cum)');
  assert.equal(normalizeRepeatRule('Her hafta'), 'Her hafta');
  assert.equal(normalizeRepeatRule('weekly'), 'Her hafta');
  assert.equal(normalizeRepeatRule('Her ay'), 'Her ay');
  assert.equal(normalizeRepeatRule('monthly'), 'Her ay');
  assert.equal(normalizeRepeatRule('Her yıl'), 'Her yıl');
  assert.equal(normalizeRepeatRule('yearly'), 'Her yıl');
  assert.equal(normalizeRepeatRule('Tekrarlama'), null);
  assert.equal(normalizeRepeatRule(null), null);
});

test('calculateNextDueDate: Her gün advances 1 day preserving time', () => {
  const current = new Date(2026, 8, 11, 9, 30, 0); // Sep 11, 2026 09:30
  const now = new Date(2026, 8, 11, 10, 0, 0); // Sep 11, 2026 10:00
  const next = calculateNextDueDate(current, 'Her gün', now);
  assert.ok(next);
  assert.equal(next.getFullYear(), 2026);
  assert.equal(next.getMonth(), 8);
  assert.equal(next.getDate(), 12);
  assert.equal(next.getHours(), 9);
  assert.equal(next.getMinutes(), 30);
});

test('calculateNextDueDate: Her gün advances past overdue dates to the future', () => {
  const current = new Date(2026, 8, 8, 9, 30, 0); // 3 days overdue
  const now = new Date(2026, 8, 11, 10, 0, 0);
  const next = calculateNextDueDate(current, 'Her gün', now);
  assert.ok(next);
  assert.equal(next.getDate(), 12);
  assert.equal(next.getHours(), 9);
});

test('calculateNextDueDate: Hafta içi skips weekends from Friday to Monday', () => {
  const friday = new Date(2026, 8, 11, 14, 0, 0); // Sep 11, 2026 is a Friday!
  const now = new Date(2026, 8, 11, 15, 0, 0);
  const next = calculateNextDueDate(friday, 'Hafta içi (Pzt-Cum)', now);
  assert.ok(next);
  assert.equal(next.getDate(), 14); // Sep 14, 2026 is Monday
  assert.equal(next.getDay(), 1); // Monday
  assert.equal(next.getHours(), 14);
});

test('calculateNextDueDate: Her hafta advances 7 days', () => {
  const current = new Date(2026, 8, 11, 10, 0, 0);
  const now = new Date(2026, 8, 11, 11, 0, 0);
  const next = calculateNextDueDate(current, 'Her hafta', now);
  assert.ok(next);
  assert.equal(next.getDate(), 18);
  assert.equal(next.getDay(), current.getDay());
});

test('calculateNextDueDate: Her ay advances 1 month clamping day overflow', () => {
  const jan31 = new Date(2026, 0, 31, 12, 0, 0); // Jan 31
  const now = new Date(2026, 0, 31, 13, 0, 0);
  const next = calculateNextDueDate(jan31, 'Her ay', now);
  assert.ok(next);
  assert.equal(next.getMonth(), 1); // Feb
  assert.equal(next.getDate(), 28); // Feb 28
  assert.equal(next.getHours(), 12);
});

test('calculateNextDueDate: Her yıl advances 1 year', () => {
  const current = new Date(2026, 8, 11, 8, 0, 0);
  const now = new Date(2026, 8, 11, 9, 0, 0);
  const next = calculateNextDueDate(current, 'Her yıl', now);
  assert.ok(next);
  assert.equal(next.getFullYear(), 2027);
  assert.equal(next.getMonth(), 8);
  assert.equal(next.getDate(), 11);
  assert.equal(next.getHours(), 8);
});

test('calculatePreviousDueDate: reverts properly for undo', () => {
  const monday = new Date(2026, 8, 14, 9, 0, 0);
  const prevWeekday = calculatePreviousDueDate(monday, 'Hafta içi (Pzt-Cum)');
  assert.ok(prevWeekday);
  assert.equal(prevWeekday.getDate(), 11); // Friday

  const day12 = new Date(2026, 8, 12, 9, 0, 0);
  const prevDaily = calculatePreviousDueDate(day12, 'Her gün');
  assert.ok(prevDaily);
  assert.equal(prevDaily.getDate(), 11);
});

test('getRecurrenceDayBadge: returns Turkish weekday abbreviation except for Her gün', () => {
  const friday = new Date(2026, 8, 11, 10, 0); // 11 Sep 2026 = Cuma
  const tuesday = new Date(2026, 8, 15, 14, 0); // 15 Sep 2026 = Salı
  const thursday = new Date(2026, 8, 17, 12, 0); // 17 Sep 2026 = Perşembe

  assert.equal(formatDayOfWeekShort(friday), 'Cum');
  assert.equal(formatDayOfWeekShort(tuesday), 'Sal');
  assert.equal(formatDayOfWeekShort(thursday), 'Per');

  // Her gün MUST return null (excluded as requested)
  assert.equal(getRecurrenceDayBadge('Her gün', friday), null);
  assert.equal(getRecurrenceDayBadge('daily', friday), null);

  // Non-repeating or null MUST return null
  assert.equal(getRecurrenceDayBadge('Tekrarlama', friday), null);
  assert.equal(getRecurrenceDayBadge(null, friday), null);

  // Her hafta returns the day of recurrence
  assert.equal(getRecurrenceDayBadge('Her hafta', tuesday), 'Sal');
  assert.equal(getRecurrenceDayBadge('Her hafta', thursday), 'Per');
  assert.equal(getRecurrenceDayBadge('Her hafta', friday), 'Cum');

  // Other recurrences (Her ay, Her yıl, Hafta içi) return the weekday
  assert.equal(getRecurrenceDayBadge('Her ay', tuesday), 'Sal');
  assert.equal(getRecurrenceDayBadge('Hafta içi (Pzt-Cum)', friday), 'Cum');
});

