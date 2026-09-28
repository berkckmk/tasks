import type { DataGateway, Unsubscribe } from '../../core/data/data-gateway.ts';
import {
  clientMutationDocumentId,
  userCollection,
} from '../../core/data/data-gateway.ts';
import { dateFromFirestore } from '../../core/data/firestore-values.ts';
import {
  isRepeating,
  repeatAnchorDayFor,
  rollForwardToDay,
  skipCompletedOccurrences,
} from './recurrence.ts';
import {
  calculateNextDueDate,
  calculatePreviousDueDate,
  completionsFromFirestore,
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
  message?: string;
  priority?: ReminderPriority;
  /** After an undo: the occurrence the series is due at again. */
  restoredDueAt?: Date;
};

/** Completed occurrences kept per reminder (for Geçmiş and undo). */
const MAX_COMPLETIONS = 100;

export type AlarmActionResult = SetDoneResult & {
  /** True when this alarm action was already applied and was skipped. */
  alreadyApplied: boolean;
};

/**
 * An alarm action is delivered twice on Android: once as a live event and once
 * through the pending-action store drained when the app becomes active. The
 * native timestamps of the two copies differ slightly, so treat any completion
 * recorded shortly before the action (or after it) as the same action.
 */
const ALARM_ACTION_DEDUPE_WINDOW_MS = 60_000;

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
  /**
   * The edit kept the snoozed time as is (only text or options changed):
   * stay snoozed and keep the original occurrence time, so saving a note on
   * a snoozed reminder does not turn 09:10 into the series' new time.
   */
  keepSnooze?: boolean;
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
      repeatAnchorDay: repeatAnchorDayFor(input.dueAt, input.repeatRule),
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
      ...(input.keepSnooze ? { status: 'snoozed' } : {}),
      notifiedAt: this.gateway.deleteField(),
      // An edited dueAt is the new schedule; forget any snoozed occurrence.
      ...(input.keepSnooze ? {} : { snoozedFromDueAt: this.gateway.deleteField() }),
      previousDueAt: this.gateway.deleteField(),
    }, { merge: true });
    return input.id;
  }

  async getById(id: string): Promise<ReminderItem | null> {
    const doc = await this.gateway.getDocument(`${userCollection(this.userId, 'reminders')}/${id}`);
    if (!doc || !doc.data) return null;
    return reminderFromDocument(doc.id, doc.data);
  }

  delete(id: string) {
    return this.gateway.deleteDocument(`${userCollection(this.userId, 'reminders')}/${id}`);
  }

  /**
   * Ticks or unticks a reminder. For a repeating reminder every tick records
   * the occurrence it completed, so several days ticked in a row each show in
   * Geçmiş and each can be unticked on its own. `options.occurrence` names the
   * occurrence to untick; without it the most recent tick is undone.
   */
  async setDone(
    id: string,
    done: boolean,
    now: Date = new Date(),
    options: { occurrence?: Date | null } = {},
  ): Promise<SetDoneResult> {
    const docPath = `${userCollection(this.userId, 'reminders')}/${id}`;
    const doc = await this.gateway.getDocument(docPath);
    const data = doc?.data;
    const repeatRule = typeof data?.repeatRule === 'string' ? data.repeatRule : null;
    const dueAt = dateFromFirestore(data?.dueAt);
    const anchorDay = typeof data?.repeatAnchorDay === 'number' ? data.repeatAnchorDay : null;
    const completions = completionsFromFirestore(data?.completions);

    if (done && isRepeating(repeatRule) && dueAt) {
      // A snoozed occurrence keeps its original time, so the series does not
      // drift by the snooze length every time it is snoozed then completed.
      const occurrenceDueAt = dateFromFirestore(data?.snoozedFromDueAt) ?? dueAt;
      const nextCandidate = calculateNextDueDate(occurrenceDueAt, repeatRule, now, anchorDay);
      if (nextCandidate) {
        const nextCompletions = [...completions, { occurrence: occurrenceDueAt, completedAt: now }]
          .slice(-MAX_COMPLETIONS);
        // Days already ticked off ahead of time are not due again.
        const nextDueAt = skipCompletedOccurrences(
          nextCandidate,
          repeatRule,
          new Set(nextCompletions.map((entry) => entry.occurrence.getTime())),
          anchorDay,
        );
        await this.gateway.updateDocument(docPath, {
          dueAt: nextDueAt,
          completions: nextCompletions,
          previousDueAt: this.gateway.deleteField(),
          status: 'scheduled',
          notifiedAt: this.gateway.deleteField(),
          snoozedFromDueAt: this.gateway.deleteField(),
          lastCompletedAt: now,
          updatedAt: this.gateway.serverTimestamp(),
        });
        // Returned so the next native alarm keeps the reminder's own text and
        // priority instead of a generic "important" alarm.
        return {
          wasRepeated: true,
          nextDueAt,
          title: typeof data?.title === 'string' ? data.title : undefined,
          message: typeof data?.message === 'string' ? data.message : undefined,
          priority: data?.priority === 'low' || data?.priority === 'normal' || data?.priority === 'important'
            ? data.priority
            : undefined,
        };
      }
    }

    if (!done && isRepeating(repeatRule) && dueAt && completions.length > 0) {
      const wanted = options.occurrence?.getTime();
      let index = wanted === undefined
        ? completions.length - 1
        : completions.findIndex((entry) => entry.occurrence.getTime() === wanted);
      if (index < 0) index = completions.length - 1;
      const undone = completions[index];
      const remaining = completions.filter((_, i) => i !== index);
      // The unticked day is due again unless the series is already earlier
      // (then the current, possibly snoozed, occurrence stays as it is).
      const movesBack = undone.occurrence < (dateFromFirestore(data?.snoozedFromDueAt) ?? dueAt);
      const restoredDueAt = movesBack ? undone.occurrence : dueAt;
      const lastCompleted = remaining.reduce<Date | null>(
        (latest, entry) => (!latest || entry.completedAt > latest ? entry.completedAt : latest),
        null,
      );
      await this.gateway.updateDocument(docPath, {
        completions: remaining,
        lastCompletedAt: lastCompleted ?? this.gateway.deleteField(),
        previousDueAt: this.gateway.deleteField(),
        ...(movesBack ? {
          dueAt: restoredDueAt,
          status: 'scheduled',
          snoozedFromDueAt: this.gateway.deleteField(),
          notifiedAt: this.gateway.deleteField(),
        } : {}),
        updatedAt: this.gateway.serverTimestamp(),
      });
      return { wasRepeated: false, restoredDueAt };
    }

    // Reminders completed before completions were recorded: one-step undo.
    if (!done && isRepeating(repeatRule) && dueAt && data?.lastCompletedAt != null) {
      const prevDueAt = dateFromFirestore(data?.previousDueAt)
        ?? calculatePreviousDueDate(dueAt, repeatRule, anchorDay);
      if (prevDueAt) {
        await this.gateway.updateDocument(docPath, {
          dueAt: prevDueAt,
          status: 'scheduled',
          lastCompletedAt: this.gateway.deleteField(),
          previousDueAt: this.gateway.deleteField(),
          notifiedAt: this.gateway.deleteField(),
          updatedAt: this.gateway.serverTimestamp(),
        });
        return { wasRepeated: false, restoredDueAt: prevDueAt };
      }
    }

    await this.gateway.updateDocument(docPath, {
      status: done ? 'completed' : 'scheduled',
      ...(done ? { lastCompletedAt: now } : { lastCompletedAt: this.gateway.deleteField() }),
      notifiedAt: this.gateway.deleteField(),
      updatedAt: this.gateway.serverTimestamp(),
    });
    return { wasRepeated: false, ...(!done && dueAt ? { restoredDueAt: dueAt } : {}) };
  }

  /**
   * Brings missed repeating reminders back to today. A repeating reminder
   * whose occurrence passed on an earlier day without being completed would
   * otherwise stay in the past forever: it drops out of "Bugün" and no future
   * alarm is scheduled for it. Returns the ids that were moved.
   */
  async rollForwardMissed(items: ReminderItem[], now: Date = new Date()): Promise<string[]> {
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const moved: string[] = [];
    for (const item of items) {
      if (item.status === 'completed' || !item.dueAt || !isRepeating(item.repeatRule)) continue;
      if (item.dueAt.getTime() >= startOfToday.getTime()) continue;
      const doc = await this.gateway.getDocument(`${userCollection(this.userId, 'reminders')}/${item.id}`);
      const data = doc?.data;
      const anchorDay = typeof data?.repeatAnchorDay === 'number' ? data.repeatAnchorDay : null;
      const base = dateFromFirestore(data?.snoozedFromDueAt) ?? item.dueAt;
      const rolled = rollForwardToDay(base, item.repeatRule, startOfToday, anchorDay);
      if (!rolled) continue;
      const completed = new Set(completionsFromFirestore(data?.completions).map((entry) => entry.occurrence.getTime()));
      const next = skipCompletedOccurrences(rolled, item.repeatRule, completed, anchorDay);
      await this.gateway.updateDocument(`${userCollection(this.userId, 'reminders')}/${item.id}`, {
        dueAt: next,
        status: 'scheduled',
        snoozedFromDueAt: this.gateway.deleteField(),
        notifiedAt: this.gateway.deleteField(),
        updatedAt: this.gateway.serverTimestamp(),
      });
      moved.push(item.id);
    }
    return moved;
  }

  /**
   * Applies a "complete" tapped on the native alarm screen, its notification
   * or the home screen widget.
   * Idempotent per action: if the reminder was already completed at or after
   * the moment the action was taken, nothing changes. Without this a repeating
   * reminder was advanced twice (e.g. a daily one skipped a whole day).
   */
  async completeAction(id: string, actionAt: Date, now: Date = new Date()): Promise<AlarmActionResult> {
    if (await this.completedSince(id, actionAt)) {
      return { wasRepeated: false, alreadyApplied: true };
    }
    const result = await this.setDone(id, true, now);
    return { ...result, alreadyApplied: false };
  }

  /**
   * Applies a "snooze" tapped on the native alarm screen or notification.
   * Skipped when the reminder was completed after the snooze, so a stale
   * snooze replayed from the pending queue cannot pull an already advanced
   * repeating reminder back to the snoozed time.
   */
  async snoozeFromAlarm(id: string, newDueAt: Date, actionAt: Date): Promise<boolean> {
    if (await this.completedSince(id, actionAt)) return false;
    await this.snoozeTo(id, newDueAt);
    return true;
  }

  private async completedSince(id: string, actionAt: Date): Promise<boolean> {
    const doc = await this.gateway.getDocument(`${userCollection(this.userId, 'reminders')}/${id}`);
    const lastCompletedAt = dateFromFirestore(doc?.data?.lastCompletedAt);
    if (!lastCompletedAt) return false;
    return lastCompletedAt.getTime() >= actionAt.getTime() - ALARM_ACTION_DEDUPE_WINDOW_MS;
  }

  /**
   * Snooze-specific update: only patches dueAt and status.
   * Does NOT touch title, message, priority, starred, category, checklist, etc.
   * For a repeating reminder the occurrence's original time is kept in
   * `snoozedFromDueAt` (only on the first snooze), so completing it later
   * schedules the next occurrence at the original time, not the snoozed one.
   */
  async snoozeTo(id: string, newDueAt: Date) {
    const docPath = `${userCollection(this.userId, 'reminders')}/${id}`;
    const doc = await this.gateway.getDocument(docPath);
    const data = doc?.data;
    const repeatRule = typeof data?.repeatRule === 'string' ? data.repeatRule : null;
    const currentDueAt = dateFromFirestore(data?.dueAt);
    const alreadySnoozedFrom = dateFromFirestore(data?.snoozedFromDueAt);
    const keepOriginal = repeatRule && repeatRule !== 'Tekrarlama' && currentDueAt && !alreadySnoozedFrom;

    return this.gateway.updateDocument(docPath, {
      dueAt: newDueAt,
      status: 'snoozed',
      ...(keepOriginal ? { snoozedFromDueAt: currentDueAt } : {}),
      notifiedAt: this.gateway.deleteField(),
      updatedAt: this.gateway.serverTimestamp(),
    });
  }
}
