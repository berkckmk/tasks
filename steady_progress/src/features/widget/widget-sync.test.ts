import assert from 'node:assert/strict';
import test from 'node:test';
import type { PendingAdd, PendingToggle } from './widget-contract.ts';
import {
  WidgetSyncCoordinator,
  type WidgetBridgePort,
  type WidgetMutationPort,
} from './widget-sync.ts';

const add: PendingAdd = {
  id: 'add:1', kind: 'task', label: 'From widget', startAt: 0, endAt: 0, allDay: true, at: 1,
};
const toggle: PendingToggle = { id: 'add:1', kind: 'task', done: true, at: 2 };

function harness(failToggle = false) {
  const events: string[] = [];
  const bridge: WidgetBridgePort = {
    readPendingAdds: async () => JSON.stringify([add]),
    readPendingToggles: async () => JSON.stringify([toggle]),
    acknowledgePendingAdds: async (entries) => { events.push(`ack-add:${entries[0].at}`); return true; },
    acknowledgePendingToggles: async (entries) => { events.push(`ack-toggle:${entries[0].at}`); return true; },
  };
  const mutations: WidgetMutationPort = {
    createFromWidget: async (_uid, entry) => {
      events.push(`create:${entry.id}`);
      return { itemId: 'server-task' };
    },
    setDoneFromWidget: async (_uid, entry, resolved) => {
      events.push(`toggle:${entry.id}->${resolved}`);
      if (failToggle) throw new Error('offline');
    },
  };
  return { events, coordinator: new WidgetSyncCoordinator(bridge, mutations) };
}

test('widget quick-add is created before its optimistic row toggle', async () => {
  const { events, coordinator } = harness();
  const result = await coordinator.drain('user-1');
  assert.deepEqual(events.slice(0, 2), ['create:add:1', 'toggle:add:1->server-task']);
  assert.deepEqual(events.slice(2), ['ack-add:1', 'ack-toggle:2']);
  assert.deepEqual(result, { skipped: false, addsApplied: 1, togglesApplied: 1, failures: 0 });
});

test('failed widget mutations remain unacknowledged for retry', async () => {
  const { events, coordinator } = harness(true);
  const result = await coordinator.drain('user-1');
  assert.equal(events.includes('ack-toggle:2'), false);
  assert.equal(result.failures, 1);
});

test('widget queue never drains before an authenticated user is known', async () => {
  const { events, coordinator } = harness();
  const result = await coordinator.drain(null);
  assert.equal(result.skipped, true);
  assert.deepEqual(events, []);
});
