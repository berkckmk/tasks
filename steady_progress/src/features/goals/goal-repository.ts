import type { DataGateway, Unsubscribe } from '../../core/data/data-gateway.ts';
import { userCollection } from '../../core/data/data-gateway.ts';
import { goalFromDocument, type Goal, type GoalCategory, type GoalProgressType, type Milestone } from './goal.ts';
export type SaveGoalInput = { id?: string; title: string; description: string; category: GoalCategory; targetDate: Date | null; progressType: GoalProgressType; manualProgress: number; milestones: Milestone[] };
export class GoalRepository {
  constructor(privateGateway: DataGateway, privateUserId: string) { this.gateway = privateGateway; this.userId = privateUserId; }
  private readonly gateway: DataGateway; private readonly userId: string;
  watch(onData: (items: Goal[]) => void, onError: (error: unknown) => void): Unsubscribe { return this.gateway.watchCollection(userCollection(this.userId, 'goals'), { orderBy: { field: 'createdAt', direction: 'desc' }, limit: 200 }, (rows) => onData(rows.map((row) => goalFromDocument(row.id, row.data))), onError); }
  async save(input: SaveGoalInput) { const path = userCollection(this.userId, 'goals'); const data = { title: input.title, description: input.description, category: input.category, targetDate: input.targetDate, progressType: input.progressType, manualProgress: Math.max(0, Math.min(1, input.manualProgress)), milestones: input.milestones, updatedAt: this.gateway.serverTimestamp() }; if (input.id) { await this.gateway.setDocument(`${path}/${input.id}`, data, { merge: true }); return input.id; } return (await this.gateway.addDocument(path, { ...data, createdAt: this.gateway.serverTimestamp() })).id; }
  delete(id: string) { return this.gateway.deleteDocument(`${userCollection(this.userId, 'goals')}/${id}`); }
}
