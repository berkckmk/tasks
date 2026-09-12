import type { DataGateway, Unsubscribe } from '../../core/data/data-gateway.ts';
import {
  clientMutationDocumentId,
  userCollection,
} from '../../core/data/data-gateway.ts';
import { dateFromFirestore } from '../../core/data/firestore-values.ts';
import {
  calculateNextDueDate,
  calculatePreviousDueDate,
  effectiveReminderPriority,
  reminderFromDocument,
  type ReminderItem,
  type ReminderPriority,
  type ReminderStatus,
} from './reminder.ts';

export type SetDoneResult = {
  wasRepeated: boolean;
  nextDueAt?: Date;
  title?: string;
};

export type SaveReminderInput = {
  id?: string;
  title: string;
  message: string;
  dueAt: Date | null;
  status: ReminderStatus;
  priority?: ReminderPriority;
  starred?: boolean;
  earlyAlertMinutes?: number | null;
  repeatRule?: string | null;
  location?: string | null;
  category?: string;
  checklist?: string[];
  clientMutationId?: string;
  lastCompletedAt?: Date | null;
};


export class ReminderRepository {
  private readonly gateway: DataGateway;
  private readonly userId: string;

  constructor(gateway: DataGateway, userId: string) {
    this.gateway = gateway;
    this.userId = userId;
  }

  watch(onData: (items: ReminderItem[]) => void, onError: (error: unknown) => void): Unsubscribe {
    return this.gateway.watchCollection(
      userCollection(this.userId, 'reminders'),
      { orderBy: { field: 'dueAt' } },
      (rows) => onData(rows.map((row) => reminderFromDocument(row.id, row.data))),
      onError,
    );
  }

  async save(input: SaveReminderInput): Promise<string> {
    const collection = userCollection(this.userId, 'reminders');
    const data = {
      title: input.title,
      message: input.message,
      dueAt: input.dueAt,
      status: input.status,
      priority: effectiveReminderPriority(input.title, input.message, input.priority),
      starred: input.starred ?? false,
      earlyAlertMinutes: input.earlyAlertMinutes ?? null,
      repeatRule: input.repeatRule ?? null,
      location: input.location ?? null,
      category: input.category ?? 'Hatırlatıcılarım',
      checklist: input.checklist ?? [],
      ...(input.clientMutationId ? { clientMutationId: input.clientMutationId } : {}),
      updatedAt: this.gateway.serverTimestamp(),
    };
    if (!input.id) {
      if (input.clientMutationId) {
        const id = clientMutationDocumentId(input.clientMutationId);
        await this.gateway.setDocument(`${collection}/${id}`, {
          ...data,
          createdAt: this.gateway.serverTimestamp(),
        }, { merge: true });
        return id;
      }
      const created = await this.gateway.addDocument(collection, {
        ...data,
        createdAt: this.gateway.serverTimestamp(),
      });
      return created.id;
    }
    await this.gateway.setDocument(`${collection}/${input.id}`, {
      ...data,
      notifiedAt: this.gateway.deleteField(),
    }, { merge: true });
    return input.id;
  }

  delete(id: string) {
    return this.gateway.deleteDocument(`${userCollection(this.userId, 'reminders')}/${id}`);
  }

  async setDone(id: string, done: boolean, now: Date = new Date()): Promise<SetDoneResult> {
    const docPath = `${userCollection(this.userId, 'reminders')}/${id}`;
    if (done) {
      const doc = await this.gateway.getDocument(docPath);
      const data = doc?.data;
      const repeatRule = typeof data?.repeatRule === 'string' ? data.repeatRule : null;
      const rawDue = data?.dueAt;
      const dueAt = dateFromFirestore(rawDue);

      if (repeatRule && repeatRule !== 'Tekrarlama' && dueAt) {
        const nextDueAt = calculateNextDueDate(dueAt, repeatRule, now);
        if (nextDueAt) {
          const completedAt = now;
          await this.gateway.updateDocument(docPath, {
            dueAt: nextDueAt,
            status: 'scheduled',
            notifiedAt: this.gateway.deleteField(),
            lastCompletedAt: completedAt,
            updatedAt: this.gateway.serverTimestamp(),
          });
          return { wasRepeated: true, nextDueAt, title: typeof data?.title === 'string' ? data.title : undefined };
        }
      }
    } else {
      const doc = await this.gateway.getDocument(docPath);
      const data = doc?.data;
      const repeatRule = typeof data?.repeatRule === 'string' ? data.repeatRule : null;
      const rawDue = data?.dueAt;
      const dueAt = dateFromFirestore(rawDue);
      const hasCompletedToday = data?.lastCompletedAt != null;

      if (repeatRule && repeatRule !== 'Tekrarlama' && dueAt && hasCompletedToday) {
        const prevDueAt = calculatePreviousDueDate(dueAt, repeatRule);
        if (prevDueAt) {
          await this.gateway.updateDocument(docPath, {
            dueAt: prevDueAt,
            status: 'scheduled',
            lastCompletedAt: this.gateway.deleteField(),
            notifiedAt: this.gateway.deleteField(),
            updatedAt: this.gateway.serverTimestamp(),
          });
          return { wasRepeated: false };
        }
      }
    }

    await this.gateway.updateDocument(docPath, {
      status: done ? 'completed' : 'scheduled',
      ...(done ? { lastCompletedAt: now } : { lastCompletedAt: this.gateway.deleteField() }),
      notifiedAt: this.gateway.deleteField(),
      updatedAt: this.gateway.serverTimestamp(),
    });
    return { wasRepeated: false };
  }


  /**
   * Snooze-specific update: only patches dueAt and status.
   * Does NOT touch title, message, priority, starred, category, checklist, etc.
   */
  snoozeTo(id: string, newDueAt: Date) {
    return this.gateway.updateDocument(`${userCollection(this.userId, 'reminders')}/${id}`, {
      dueAt: newDueAt,
      status: 'snoozed',
      notifiedAt: this.gateway.deleteField(),
      updatedAt: this.gateway.serverTimestamp(),
    });
  }
}
