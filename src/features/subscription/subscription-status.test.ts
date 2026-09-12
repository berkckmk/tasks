import assert from 'node:assert/strict';
import test from 'node:test';
import { isSubscriptionEntitled, subscriptionStatusFromDocument } from './subscription-status.ts';

test('subscription entitlement fails closed after cancellation or expiry', () => {
  const active = subscriptionStatusFromDocument({ planId: 'growth', status: 'active' });
  assert.equal(isSubscriptionEntitled(active, new Date('2026-01-01T00:00:00Z')), true);
  assert.equal(isSubscriptionEntitled({ ...active, status: 'canceled' }), false);
  assert.equal(isSubscriptionEntitled({ ...active, expiresAt: new Date('2025-12-31T23:59:59Z') }, new Date('2026-01-01T00:00:00Z')), false);
});
