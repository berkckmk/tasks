import type { DataGateway, Unsubscribe } from '../../core/data/data-gateway.ts';
import { userCollection } from '../../core/data/data-gateway.ts';
import { dateFromFirestore } from '../../core/data/firestore-values.ts';
import { calculateNextDueDate, calculatePreviousDueDate, isRepeating, repeatAnchorDayFor } from '../reminders/recurrence.ts';
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
        ...(input.repeatRule !== undefined ? { repeatRule: input.repeatRule, repeatAnchorDay: repeatAnchorDayFor(input.dueDate, input.repeatRule) } : {}),
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
      ...(input.repeatRule !== undefined ? { repeatRule: input.repeatRule, repeatAnchorDay: repeatAnchorDayFor(input.dueDate, input.repeatRule) } : {}),
      previousDueDate: this.gateway.deleteField(),
      previousStartDate: this.gateway.deleteField(),
      updatedAt: this.gateway.serverTimestamp(),
    }, { merge: true });
    return input.id;
  }

  delete(id: string) {
    return this.gateway.deleteDocument(`${userCollection(this.userId, 'tasks')}/${id}`);
  }

  async setDone(id: string, done: boolean, now: Date = new Date()): Promise<{ wasRepeated: boolean; nextDueDate?: Date }> {
    const docPath = `${userCollection(this.userId, 'tasks')}/${id}`;
    const doc = await this.gateway.getDocument(docPath);
    const data = doc?.data;
    const repeatRule = typeof data?.repeatRule === 'string' ? data.repeatRule : null;
    const dueDate = dateFromFirestore(data?.dueDate);
    const startDate = dateFromFirestore(data?.startDate);
    const anchorDay = typeof data?.repeatAnchorDay === 'number' ? data.repeatAnchorDay : null;

    if (done && isRepeating(repeatRule) && dueDate) {
      const nextDueDate = calculateNextDueDate(dueDate, repeatRule, now, anchorDay);
      if (nextDueDate) {
        const nextStartDate = startDate
          ? new Date(nextDueDate.getTime() - (dueDate.getTime() - startDate.getTime()))
          : null;
        await this.gateway.updateDocument(docPath, {
          dueDate: nextDueDate,
          ...(nextStartDate ? { startDate: nextStartDate } : {}),
          // Remembered so an undo returns to exactly this occurrence.
          previousDueDate: dueDate,
          ...(startDate ? { previousStartDate: startDate } : {}),
          status: 'todo',
          lastCompletedAt: now,
          updatedAt: this.gateway.serverTimestamp(),
        });
        return { wasRepeated: true, nextDueDate };
      }
    }

    if (!done && isRepeating(repeatRule) && dueDate && data?.lastCompletedAt != null) {
      const storedPrevDue = dateFromFirestore(data?.previousDueDate);
      const prevDueDate = storedPrevDue ?? calculatePreviousDueDate(dueDate, repeatRule, anchorDay);
      if (prevDueDate) {
        const prevStartDate = storedPrevDue
          ? dateFromFirestore(data?.previousStartDate)
          : startDate
            ? new Date(prevDueDate.getTime() - (dueDate.getTime() - startDate.getTime()))
            : null;
        await this.gateway.updateDocument(docPath, {
          dueDate: prevDueDate,
          ...(prevStartDate ? { startDate: prevStartDate } : {}),
          status: 'todo',
          lastCompletedAt: this.gateway.deleteField(),
          previousDueDate: this.gateway.deleteField(),
          previousStartDate: this.gateway.deleteField(),
          updatedAt: this.gateway.serverTimestamp(),
        });
        return { wasRepeated: false };
      }
    }

    await this.gateway.updateDocument(docPath, {
      status: done ? 'done' : 'todo',
      ...(done ? { lastCompletedAt: now } : { lastCompletedAt: this.gateway.deleteField() }),
      updatedAt: this.gateway.serverTimestamp(),
    });
    return { wasRepeated: false };
  }

  /**
   * Completes a task for one user action (e.g. a queued widget tap) at most
   * once: a replay of the same action must not advance a repeating task twice.
   */
  async completeAction(id: string, actionAt: Date, now: Date = new Date()) {
    const doc = await this.gateway.getDocument(`${userCollection(this.userId, 'tasks')}/${id}`);
    const lastCompletedAt = dateFromFirestore(doc?.data?.lastCompletedAt);
    if (lastCompletedAt && lastCompletedAt.getTime() >= actionAt.getTime() - 60_000) {
      return { wasRepeated: false, alreadyApplied: true };
    }
    return { ...(await this.setDone(id, true, now)), alreadyApplied: false };
  }

  setSyncEnabled(id: string, enabled: boolean) {
    return this.gateway.updateDocument(`${userCollection(this.userId, 'tasks')}/${id}`, {
      syncEnabled: enabled,
    });
  }
}
