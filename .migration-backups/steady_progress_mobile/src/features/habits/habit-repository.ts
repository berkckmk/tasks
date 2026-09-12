import type { DataGateway, Unsubscribe } from '../../core/data/data-gateway.ts';
import { userCollection } from '../../core/data/data-gateway.ts';
import {
  formatLogDate,
  habitFromDocument,
  habitLogFromDocument,
  type Habit,
  type HabitCategory,
  type HabitLog,
} from './habit.ts';

export type SaveHabitInput = {
  id?: string;
  name: string;
  category: HabitCategory;
  frequencyLabel: string;
  colorValue: number;
  reminderTimeLabel: string | null;
  clientMutationId?: string;
};

export class HabitRepository {
  private readonly gateway: DataGateway;
  private readonly userId: string;

  constructor(gateway: DataGateway, userId: string) {
    this.gateway = gateway;
    this.userId = userId;
  }

  watch(onData: (habits: Habit[]) => void, onError: (error: unknown) => void): Unsubscribe {
    return this.gateway.watchCollection(
      userCollection(this.userId, 'habits'),
      { orderBy: { field: 'createdAt' }, limit: 200 },
      (rows) => onData(rows.map((row) => habitFromDocument(row.id, row.data))),
      onError,
    );
  }

  watchRecentLogs(
    onData: (logs: HabitLog[]) => void,
    onError: (error: unknown) => void,
    cutoffDate: string,
  ): Unsubscribe {
    return this.gateway.watchCollection(
      userCollection(this.userId, 'habit_logs'),
      { filters: [{ field: 'date', operator: '>=', value: cutoffDate }] },
      (rows) => onData(rows.map((row) => habitLogFromDocument(row.id, row.data))),
      onError,
    );
  }

  async save(input: SaveHabitInput): Promise<string> {
    const collection = userCollection(this.userId, 'habits');
    if (!input.id) {
      const created = await this.gateway.callFunction('createHabit', {
        name: input.name,
        category: input.category,
        frequencyLabel: input.frequencyLabel,
        colorValue: input.colorValue,
        reminderTimeLabel: input.reminderTimeLabel,
        ...(input.clientMutationId ? { clientMutationId: input.clientMutationId } : {}),
      });
      const id = typeof created.id === 'string'
        ? created.id
        : typeof created.habitId === 'string'
          ? created.habitId
          : null;
      if (!id) throw new Error('createHabit did not return an id');
      return id;
    }
    await this.gateway.setDocument(`${collection}/${input.id}`, {
      name: input.name,
      category: input.category,
      frequencyLabel: input.frequencyLabel,
      colorValue: input.colorValue,
      reminderTimeLabel: input.reminderTimeLabel,
      updatedAt: this.gateway.serverTimestamp(),
    }, { merge: true });
    return input.id;
  }

  async delete(id: string) {
    const logsPath = userCollection(this.userId, 'habit_logs');
    const logs = await this.gateway.getCollection(logsPath, {
      filters: [{ field: 'habitId', operator: '==', value: id }],
    });
    // Delete logs first so a failed cleanup leaves the habit visible and the
    // deletion can be retried, matching the fixed Flutter behavior.
    await this.gateway.deleteDocuments(logs.map((log) => `${logsPath}/${log.id}`));
    await this.gateway.deleteDocument(`${userCollection(this.userId, 'habits')}/${id}`);
  }

  setCompletionToday(id: string, completed: boolean, today = new Date()) {
    const date = formatLogDate(today);
    const path = `${userCollection(this.userId, 'habit_logs')}/${id}_${date}`;
    if (!completed) return this.gateway.deleteDocument(path);
    return this.gateway.setDocument(path, {
      habitId: id,
      date,
      completed: true,
      completedAt: this.gateway.serverTimestamp(),
    });
  }

  setSyncEnabled(id: string, enabled: boolean) {
    return this.gateway.updateDocument(`${userCollection(this.userId, 'habits')}/${id}`, {
      syncEnabled: enabled,
    });
  }
}
