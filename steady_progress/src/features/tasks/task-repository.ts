import type { DataGateway, Unsubscribe } from '../../core/data/data-gateway.ts';
import { userCollection } from '../../core/data/data-gateway.ts';
import { dateFromFirestore } from '../../core/data/firestore-values.ts';
import { calculateNextDueDate, calculatePreviousDueDate } from '../reminders/recurrence.ts';
import {
  taskFromDocument,
  type TaskItem,
  type TaskPriority,
  type TaskStatus,
} from './task-item.ts';

export type SaveTaskInput = {
  id?: string;
  title: string;
  description: string;
  startDate: Date | null;
  dueDate: Date | null;
  allDay: boolean;
  priority: TaskPriority;
  status: TaskStatus;
  relatedGoalId: string | null;
  clientMutationId?: string;
  repeatRule?: string | null;
  lastCompletedAt?: Date | null;
};


export class TaskRepository {
  private readonly gateway: DataGateway;
  private readonly userId: string;

  constructor(gateway: DataGateway, userId: string) {
    this.gateway = gateway;
    this.userId = userId;
  }

  watch(onData: (tasks: TaskItem[]) => void, onError: (error: unknown) => void): Unsubscribe {
    return this.gateway.watchCollection(
      userCollection(this.userId, 'tasks'),
      { orderBy: { field: 'createdAt', direction: 'desc' }, limit: 200 },
      (rows) => onData(rows.map((row) => taskFromDocument(row.id, row.data))),
      onError,
    );
  }

  async save(input: SaveTaskInput): Promise<string> {
    const collection = userCollection(this.userId, 'tasks');
    if (!input.id) {
      const created = await this.gateway.callFunction('createTask', {
        title: input.title,
        description: input.description,
        startDate: input.startDate?.toISOString() ?? null,
        dueDate: input.dueDate?.toISOString() ?? null,
        allDay: input.allDay,
        priority: input.priority,
        relatedGoalId: input.relatedGoalId,
        ...(input.clientMutationId ? { clientMutationId: input.clientMutationId } : {}),
      });
      const id = typeof created.id === 'string'
        ? created.id
        : typeof created.taskId === 'string'
          ? created.taskId
          : null;
      if (!id) throw new Error('createTask did not return an id');
      // Keeps compatibility with the older deployed callable which may omit
      // range fields. Updates are allowed after the server creates the doc.
      await this.gateway.setDocument(`${collection}/${id}`, {
        startDate: input.startDate,
        dueDate: input.dueDate,
        allDay: input.allDay,
        ...(input.repeatRule !== undefined ? { repeatRule: input.repeatRule } : {}),
        ...(input.status && input.status !== 'todo' ? { status: input.status } : {}),
        updatedAt: this.gateway.serverTimestamp(),
      }, { merge: true });
      return id;
    }
    await this.gateway.setDocument(`${collection}/${input.id}`, {
      title: input.title,
      description: input.description,
      startDate: input.startDate,
      dueDate: input.dueDate,
      allDay: input.allDay,
      priority: input.priority,
      status: input.status,
      relatedGoalId: input.relatedGoalId,
      ...(input.repeatRule !== undefined ? { repeatRule: input.repeatRule } : {}),
      updatedAt: this.gateway.serverTimestamp(),
    }, { merge: true });
    return input.id;
  }

  delete(id: string) {
    return this.gateway.deleteDocument(`${userCollection(this.userId, 'tasks')}/${id}`);
  }

  async setDone(id: string, done: boolean): Promise<{ wasRepeated: boolean; nextDueDate?: Date }> {
    const docPath = `${userCollection(this.userId, 'tasks')}/${id}`;
    if (done) {
      const doc = await this.gateway.getDocument(docPath);
      const data = doc?.data;
      const repeatRule = typeof data?.repeatRule === 'string' ? data.repeatRule : null;
      const rawDue = data?.dueDate;
      const dueDate = dateFromFirestore(rawDue);

      if (repeatRule && repeatRule !== 'Tekrarlama' && dueDate) {
        const nextDueDate = calculateNextDueDate(dueDate, repeatRule);
        if (nextDueDate) {
          let nextStartDate: Date | null = null;
          const rawStart = data?.startDate;
          const startDate = dateFromFirestore(rawStart);
          if (startDate) {
            const diffMs = dueDate.getTime() - startDate.getTime();
            nextStartDate = new Date(nextDueDate.getTime() - diffMs);
          }
          const completedAt = new Date();
          await this.gateway.updateDocument(docPath, {
            dueDate: nextDueDate,
            ...(nextStartDate ? { startDate: nextStartDate } : {}),
            status: 'todo',
            lastCompletedAt: completedAt,
            updatedAt: this.gateway.serverTimestamp(),
          });
          return { wasRepeated: true, nextDueDate };
        }
      }
    } else {
      const doc = await this.gateway.getDocument(docPath);
      const data = doc?.data;
      const repeatRule = typeof data?.repeatRule === 'string' ? data.repeatRule : null;
      const rawDue = data?.dueDate;
      const dueDate = dateFromFirestore(rawDue);
      const hasCompletedToday = data?.lastCompletedAt != null;

      if (repeatRule && repeatRule !== 'Tekrarlama' && dueDate && hasCompletedToday) {
        const prevDueDate = calculatePreviousDueDate(dueDate, repeatRule);
        if (prevDueDate) {
          let prevStartDate: Date | null = null;
          const rawStart = data?.startDate;
          const startDate = dateFromFirestore(rawStart);
          if (startDate) {
            const diffMs = dueDate.getTime() - startDate.getTime();
            prevStartDate = new Date(prevDueDate.getTime() - diffMs);
          }
          await this.gateway.updateDocument(docPath, {
            dueDate: prevDueDate,
            ...(prevStartDate ? { startDate: prevStartDate } : {}),
            status: 'todo',
            lastCompletedAt: this.gateway.deleteField(),
            updatedAt: this.gateway.serverTimestamp(),
          });
          return { wasRepeated: false };
        }
      }
    }

    const completedAt = new Date();
    await this.gateway.updateDocument(docPath, {
      status: done ? 'done' : 'todo',
      ...(done ? { lastCompletedAt: completedAt } : { lastCompletedAt: this.gateway.deleteField() }),
      updatedAt: this.gateway.serverTimestamp(),
    });
    return { wasRepeated: false };
  }



  setSyncEnabled(id: string, enabled: boolean) {
    return this.gateway.updateDocument(`${userCollection(this.userId, 'tasks')}/${id}`, {
      syncEnabled: enabled,
    });
  }
}
