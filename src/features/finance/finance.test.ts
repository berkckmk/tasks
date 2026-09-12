import assert from 'node:assert/strict';
import test from 'node:test';
import { MemoryDataGateway } from '../../core/data/memory-data-gateway.ts';
import { FinanceRepository } from './finance-repository.ts';
import { monthlyFinanceSummary, savingsGoalFromDocument, savingsProgress } from './finance.ts';

test('finance computes monthly totals and preserves cents', () => {
  const summary = monthlyFinanceSummary([
    { id: 'a', type: 'income', amount: 100.55, category: 'Salary', note: '', date: new Date(2026, 8, 2) },
    { id: 'b', type: 'expense', amount: 40.25, category: 'Food', note: '', date: new Date(2026, 8, 3) },
    { id: 'old', type: 'expense', amount: 99, category: 'Other', note: '', date: new Date(2026, 7, 3) },
  ], new Date(2026, 8, 9));
  assert.equal(summary.income, 100.55);
  assert.equal(summary.expenses, 40.25);
  assert.ok(Math.abs(summary.savingsRate - (60.3 / 100.55)) < 0.000001);
});

test('savings goals clamp progress and round-trip through the gateway', async () => {
  assert.equal(savingsProgress(savingsGoalFromDocument('g', { targetAmount: 10, currentAmount: 20 })), 1);
  const gateway = new MemoryDataGateway(); const repository = new FinanceRepository(gateway, 'preview-user'); let goals = 0;
  const stop = repository.watchSavingsGoals((items) => { goals = items.length; }, (error) => assert.fail(String(error)));
  const id = await repository.saveSavingsGoal({ title: 'Trip', targetAmount: 500.5, currentAmount: 20.25, targetDate: null }); assert.equal(goals, 1);
  await repository.deleteSavingsGoal(id); assert.equal(goals, 0); stop();
});
