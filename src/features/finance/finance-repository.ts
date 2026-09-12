import { userCollection, type DataGateway, type Unsubscribe } from '../../core/data/data-gateway.ts';
import { savingsGoalFromDocument, transactionFromDocument, type SavingsGoal, type TransactionType, type FinanceTransaction } from './finance.ts';

export class FinanceRepository {
  private readonly gateway: DataGateway;
  private readonly userId: string;
  constructor(gateway: DataGateway, userId: string) { this.gateway = gateway; this.userId = userId; }
  watchTransactions(onData: (items: FinanceTransaction[]) => void, onError: (error: unknown) => void): Unsubscribe { return this.gateway.watchCollection(userCollection(this.userId, 'finance_transactions'), { orderBy: { field: 'date', direction: 'desc' }, limit: 200 }, (rows) => onData(rows.map((row) => transactionFromDocument(row.id, row.data))), onError); }
  watchSavingsGoals(onData: (items: SavingsGoal[]) => void, onError: (error: unknown) => void): Unsubscribe { return this.gateway.watchCollection(userCollection(this.userId, 'savings_goals'), { orderBy: { field: 'createdAt', direction: 'desc' }, limit: 200 }, (rows) => onData(rows.map((row) => savingsGoalFromDocument(row.id, row.data))), onError); }
  async addTransaction(input: { type: TransactionType; amount: number; category: string; note: string; date: Date }) { return (await this.gateway.addDocument(userCollection(this.userId, 'finance_transactions'), { ...input, createdAt: this.gateway.serverTimestamp() })).id; }
  deleteTransaction(id: string) { return this.gateway.deleteDocument(`${userCollection(this.userId, 'finance_transactions')}/${id}`); }
  async saveSavingsGoal(input: Omit<SavingsGoal, 'id'> & { id?: string }) { const collection = userCollection(this.userId, 'savings_goals'); const data = { title: input.title, targetAmount: input.targetAmount, currentAmount: input.currentAmount, targetDate: input.targetDate }; if (input.id) { await this.gateway.setDocument(`${collection}/${input.id}`, data, { merge: true }); return input.id; } return (await this.gateway.addDocument(collection, { ...data, createdAt: this.gateway.serverTimestamp() })).id; }
  deleteSavingsGoal(id: string) { return this.gateway.deleteDocument(`${userCollection(this.userId, 'savings_goals')}/${id}`); }
}
