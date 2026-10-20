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

test('fixed navbar slot colors provide consistent colors for 5 slots regardless of module', async () => {
  const {
    navbarSlotColors,
    navbarSlotActiveColors,
    navbarSlotGradients,
    getNavBarSlotColor,
    getNavBarSlotActiveColor,
    getNavBarSlotGradient,
    tabColors,
    tabActiveColors,
  } = await import('../../theme/colors.ts');

  assert.equal(navbarSlotColors.length, 5);
  assert.equal(navbarSlotActiveColors.length, 5);
  assert.equal(navbarSlotGradients.length, 5);

  // Slot 0 (Item 1) is Purple (reminders tone)
  assert.equal(getNavBarSlotColor(0), tabColors.reminders);
  assert.equal(getNavBarSlotActiveColor(0), tabActiveColors.reminders);

  // Slot 1 (Item 2) is Peach (today tone)
  assert.equal(getNavBarSlotColor(1), tabColors.today);
  assert.equal(getNavBarSlotActiveColor(1), tabActiveColors.today);

  // Slot 2 (Item 3) is Green (habits tone)
  assert.equal(getNavBarSlotColor(2), tabColors.habits);
  assert.equal(getNavBarSlotActiveColor(2), tabActiveColors.habits);

  // Slot 3 (Item 4) is Pink (tasks tone)
  assert.equal(getNavBarSlotColor(3), tabColors.tasks);
  assert.equal(getNavBarSlotActiveColor(3), tabActiveColors.tasks);

  // Slot 4 (Item 5 - More) is Blue (more tone)
  assert.equal(getNavBarSlotColor(4), tabColors.more);
  assert.equal(getNavBarSlotActiveColor(4), tabActiveColors.more);

  // Bounds clamping
  assert.equal(getNavBarSlotColor(-1), tabColors.reminders);
  assert.equal(getNavBarSlotColor(10), tabColors.more);
  assert.ok(getNavBarSlotGradient(2).pill.length >= 2);
});

test('slot-aware color resolution eliminates color conflict for added tracking items', async () => {
  const {
    setActiveNavBarSlots,
    getTabColor,
    getTabActiveColor,
    getTabGradient,
    getNavBarSlotColor,
    getNavBarSlotActiveColor,
    getNavBarSlotGradient,
    getModuleDefaultColor,
    tabColors,
  } = await import('../../theme/colors.ts');

  // Case 1: When workout is unplaced, it uses its standalone orange tone
  setActiveNavBarSlots(['reminders', 'index', 'habits', 'tasks']);
  assert.equal(getTabColor('workout'), tabColors.workout);
  assert.equal(getModuleDefaultColor('workout'), tabColors.workout);

  // Case 2: When workout is placed into Slot 3 (index 2 - Green slot)
  setActiveNavBarSlots(['reminders', 'index', 'workout', 'tasks']);
  // Its color MUST match Slot 3 (green) across the app to prevent color clashing
  assert.equal(getTabColor('workout'), getNavBarSlotColor(2));
  assert.equal(getTabActiveColor('workout'), getNavBarSlotActiveColor(2));
  assert.deepEqual(getTabGradient('workout'), getNavBarSlotGradient(2));

  // Turkish title normalization works seamlessly
  assert.equal(getTabColor('Antrenman'), getNavBarSlotColor(2));
  assert.equal(getTabColor('egzersiz programı'), getNavBarSlotColor(2));

  // Case 3: When finance is placed into Slot 1 (index 0 - Purple slot)
  setActiveNavBarSlots(['finance', 'index', 'workout', 'tasks']);
  assert.equal(getTabColor('finance'), getNavBarSlotColor(0));
  assert.equal(getTabActiveColor('finance'), getNavBarSlotActiveColor(0));
  assert.equal(getTabColor('Finans'), getNavBarSlotColor(0));

  // Reset back to default slots
  setActiveNavBarSlots(['reminders', 'index', 'habits', 'tasks']);
});
