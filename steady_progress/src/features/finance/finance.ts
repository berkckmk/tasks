import { dateFromFirestore, enumValue } from '../../core/data/firestore-values.ts';

export const transactionTypes = ['income', 'expense'] as const;
export type TransactionType = typeof transactionTypes[number];
export const incomeCategories = ['Salary', 'Freelance', 'Investment', 'Gift', 'Other'] as const;
export const expenseCategories = ['Housing', 'Food', 'Transport', 'Entertainment', 'Health', 'Shopping', 'Other'] as const;
export type FinanceTransaction = { id: string; type: TransactionType; amount: number; category: string; note: string; date: Date };
export type SavingsGoal = { id: string; title: string; targetAmount: number; currentAmount: number; targetDate: Date | null };

export function transactionFromDocument(id: string, data: Record<string, unknown>): FinanceTransaction {
  return { id, type: enumValue(data.type, transactionTypes, 'expense'), amount: typeof data.amount === 'number' ? data.amount : 0, category: typeof data.category === 'string' ? data.category : 'Other', note: typeof data.note === 'string' ? data.note : '', date: dateFromFirestore(data.date) ?? new Date() };
}
export function savingsGoalFromDocument(id: string, data: Record<string, unknown>): SavingsGoal {
  return { id, title: typeof data.title === 'string' ? data.title : '', targetAmount: typeof data.targetAmount === 'number' ? data.targetAmount : 0, currentAmount: typeof data.currentAmount === 'number' ? data.currentAmount : 0, targetDate: dateFromFirestore(data.targetDate) };
}
export function savingsProgress(goal: SavingsGoal) { return goal.targetAmount <= 0 ? 0 : Math.min(1, Math.max(0, goal.currentAmount / goal.targetAmount)); }
export function monthlyFinanceSummary(items: FinanceTransaction[], now = new Date()) {
  const current = items.filter((item) => item.date.getFullYear() === now.getFullYear() && item.date.getMonth() === now.getMonth());
  const income = current.filter((item) => item.type === 'income').reduce((sum, item) => sum + item.amount, 0);
  const expenses = current.filter((item) => item.type === 'expense').reduce((sum, item) => sum + item.amount, 0);
  return { income, expenses, savingsRate: income <= 0 ? 0 : Math.min(1, Math.max(-1, (income - expenses) / income)) };
}
