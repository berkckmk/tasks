import assert from 'node:assert/strict';
import test from 'node:test';
import { parsePendingAdds, parsePendingToggles, parseWidgetRoute, previewSnapshot } from './widget-contract.ts';

test('legacy add queues without schedule retain the original all-day defaults', () => {
  const [row] = parsePendingAdds('[{"id":"add:123","kind":"task","label":"Plan","at":1000}]');
  assert.equal(row.startAt, 0);
  assert.equal(row.endAt, 0);
  assert.equal(row.allDay, true);
});
test('scheduled quick adds preserve millisecond timestamps, range and time choice', () => {
  const input = { id: 'add:123', kind: 'task' as const, label: 'Plan', startAt: 1788678000000, endAt: 1788681600000, allDay: false, at: 1788677000000 };
  assert.deepEqual(parsePendingAdds(JSON.stringify([input])), [input]);
});
test('rich pending adds preserve description, priority, repeatRule, importance, and habit metadata', () => {
  const input = {
    id: 'add:task:1',
    kind: 'task' as const,
    label: 'Complete Project',
    startAt: 1788678000000,
    endAt: 1788681600000,
    allDay: false,
    at: 1788677000000,
    description: 'Detailed description here',
    priority: 'high',
    repeatRule: 'Günlük',
    isImportant: false,
    category: 'morning',
    frequency: 'Daily',
    color: 0xff9e86ff,
  };
  assert.deepEqual(parsePendingAdds(JSON.stringify([input])), [input]);
});
test('malformed or unknown queue entries are not silently dropped and acknowledged', () => {
  for (const raw of ['{', '{}', '[null]', '[{"id":"1","kind":"unknown","done":true,"at":1}]', '[{"id":"1","kind":"habit","done":"true","at":1}]']) {
    assert.throws(() => parsePendingToggles(raw));
  }
});
test('toggle identity retains kind and timestamp, including the same id in different collections', () => {
  const input = [
    { id: 'shared', kind: 'habit', done: true, at: 100 },
    { id: 'shared', kind: 'task', done: false, at: 101 },
  ];
  assert.deepEqual(parsePendingToggles(JSON.stringify(input)), input);
});
test('widget deep links only accept existing collection/item destinations', () => {
  for (const route of [
    '/tasks/a/edit',
    '/task/a/edit',
    '/habits/b/edit',
    '/habit/b/edit',
    '/reminders/c/edit',
    '/reminder/c/edit',
    '/reminders',
    '/tasks',
    '/habits',
    '/tasks/a',
    '/reminders/c',
  ]) {
    assert.equal(parseWidgetRoute(route), route);
  }
  for (const route of ['https://example.com', '/auth', '/tasks/a/edit?redirect=x', '/tasks/a/b/edit', null]) {
    assert.equal(parseWidgetRoute(route), null);
  }
});
test('preview payload contains three Kotlin sections and uses only synthetic ids', () => {
  const items = JSON.parse(previewSnapshot.items);
  assert.deepEqual(Object.keys(items), ['habits', 'tasks', 'reminders']);
  for (const rows of Object.values(items) as { id: string }[][]) {
    assert.ok(rows.every((row) => row.id.startsWith('preview-')));
  }
});
