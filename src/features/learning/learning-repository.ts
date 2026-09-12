import type { DataGateway, Unsubscribe } from '../../core/data/data-gateway.ts';
import { userCollection } from '../../core/data/data-gateway.ts';
import {
  learningItemFromDocument,
  type LearningItem,
  type LearningStatus,
  type LearningType,
} from './learning-item.ts';

export type SaveLearningInput = {
  id?: string;
  title: string;
  type: LearningType;
  status: LearningStatus;
  rating: number;
  notes: string;
  keyTakeaways: string[];
};

export class LearningRepository {
  private readonly gateway: DataGateway;
  private readonly userId: string;

  constructor(gateway: DataGateway, userId: string) {
    this.gateway = gateway;
    this.userId = userId;
  }

  watch(onData: (items: LearningItem[]) => void, onError: (error: unknown) => void): Unsubscribe {
    return this.gateway.watchCollection(
      userCollection(this.userId, 'learning_items'),
      { orderBy: { field: 'createdAt', direction: 'desc' }, limit: 200 },
      (rows) => onData(rows.map((row) => learningItemFromDocument(row.id, row.data))),
      onError,
    );
  }

  async save(input: SaveLearningInput): Promise<string> {
    const collection = userCollection(this.userId, 'learning_items');
    const data = {
      title: input.title,
      type: input.type,
      status: input.status,
      rating: Math.max(0, Math.min(5, Math.trunc(input.rating))),
      notes: input.notes,
      keyTakeaways: input.keyTakeaways,
      updatedAt: this.gateway.serverTimestamp(),
    };
    if (!input.id) {
      return (await this.gateway.addDocument(collection, {
        ...data,
        createdAt: this.gateway.serverTimestamp(),
      })).id;
    }
    await this.gateway.setDocument(`${collection}/${input.id}`, data, { merge: true });
    return input.id;
  }

  delete(id: string) {
    return this.gateway.deleteDocument(`${userCollection(this.userId, 'learning_items')}/${id}`);
  }
}
