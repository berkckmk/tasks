import test from 'node:test';
import assert from 'node:assert/strict';
import {
  DEFAULT_NAVBAR_SLOTS,
  FIXED_MORE_SLOT,
  SELECTABLE_TRACKING_ITEMS,
  isValidSlotId,
  sanitizeNavbarSlots,
  type NavSlotId,
} from './navbar-items.ts';

test('DEFAULT_NAVBAR_SLOTS contains exactly 4 items and does not contain more', () => {
  assert.equal(DEFAULT_NAVBAR_SLOTS.length, 4);
  assert.equal(DEFAULT_NAVBAR_SLOTS.includes(FIXED_MORE_SLOT as any), false);
  assert.deepEqual(DEFAULT_NAVBAR_SLOTS, ['reminders', 'index', 'habits', 'tasks']);
});

test('SELECTABLE_TRACKING_ITEMS contains all tracking items and excludes fixed more', () => {
  assert.ok(SELECTABLE_TRACKING_ITEMS.length >= 10);
  const ids = SELECTABLE_TRACKING_ITEMS.map((item) => item.id);
  assert.ok(ids.includes('goals'));
  assert.ok(ids.includes('finance'));
  assert.ok(ids.includes('workout'));
  assert.ok(ids.includes('learning'));
  assert.ok(ids.includes('analytics'));
  assert.ok(ids.includes('reports'));
  assert.ok(ids.includes('content'));
  assert.ok(ids.includes('habits'));
  assert.ok(ids.includes('tasks'));
  assert.ok(ids.includes('reminders'));
  assert.ok(ids.includes('index'));
  assert.equal(ids.includes('more'), false);
});

test('isValidSlotId rejects more and unknown strings', () => {
  assert.equal(isValidSlotId('more'), false);
  assert.equal(isValidSlotId('unknown_area'), false);
  assert.equal(isValidSlotId('goals'), true);
  assert.equal(isValidSlotId('workout'), true);
});

test('sanitizeNavbarSlots preserves valid custom 4-slot arrangements', () => {
  const custom: NavSlotId[] = ['workout', 'finance', 'goals', 'content'];
  const sanitized = sanitizeNavbarSlots(custom);
  assert.deepEqual(sanitized, custom);
});

test('sanitizeNavbarSlots fills fallbacks on invalid, partial or duplicate slots', () => {
  // Empty
  assert.deepEqual(sanitizeNavbarSlots([]), DEFAULT_NAVBAR_SLOTS);
  // Non-array
  assert.deepEqual(sanitizeNavbarSlots(null), DEFAULT_NAVBAR_SLOTS);
  // Duplicates & invalid
  const input = ['workout', 'workout', 'invalid_slot', 'finance'];
  const sanitized = sanitizeNavbarSlots(input);
  assert.equal(sanitized.length, 4);
  assert.equal(sanitized[0], 'workout');
  assert.equal(sanitized[1], 'finance');
  // 3rd and 4th filled from defaults
  assert.ok(sanitized[2] && sanitized[3]);
  const unique = new Set(sanitized);
  assert.equal(unique.size, 4);
});
