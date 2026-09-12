import type { DataGateway } from '../../core/data/data-gateway.ts';
import { HabitRepository } from '../habits/habit-repository.ts';
import { ReminderRepository } from '../reminders/reminder-repository.ts';
import { TaskRepository } from '../tasks/task-repository.ts';
import type { PendingAdd, PendingToggle } from './widget-contract.ts';
import type { WidgetMutationPort } from './widget-sync.ts';

const DEFAULT_HABIT_COLOR = 0xff9184d9;

export type WidgetMutationOptions = {
  now?: () => Date;
  formatHabitTime?: (date: Date) => string;
};

function dateFromMillis(value: number) {
  return value > 0 ? new Date(value) : null;
}

function localStartOfDay(date: Date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function nextWholeHour(now: Date) {
  const result = new Date(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours());
  result.setHours(result.getHours() + 1);
  return result;
}

function defaultHabitTime(date: Date) {
  return new Intl.DateTimeFormat('tr-TR', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
    timeZone: 'Europe/Istanbul',
  }).format(date);
}

/** Routes native widget actions through the same feature repositories as the app. */
export class RepositoryWidgetMutations implements WidgetMutationPort {
  private readonly gateway: DataGateway;
  private readonly now: () => Date;
  private readonly formatHabitTime: (date: Date) => string;

  constructor(gateway: DataGateway, options: WidgetMutationOptions = {}) {
    this.gateway = gateway;
    this.now = options.now ?? (() => new Date());
    this.formatHabitTime = options.formatHabitTime ?? defaultHabitTime;
  }

  async createFromWidget(userId: string, entry: PendingAdd): Promise<{ itemId: string }> {
    const startAt = dateFromMillis(entry.startAt);
    const endAt = dateFromMillis(entry.endAt);

    if (entry.kind === 'reminder') {
      const repository = new ReminderRepository(this.gateway, userId);
      const itemId = await repository.save({
        title: entry.label.trim(),
        message: entry.description?.trim() || '',
        dueAt: startAt ?? nextWholeHour(this.now()),
        status: 'scheduled',
        priority: entry.isImportant ? 'important' : 'normal',
        repeatRule: entry.repeatRule?.trim() || null,
        clientMutationId: entry.id,
      });
      return { itemId };
    }

    if (entry.kind === 'task') {
      const start = startAt ?? this.now();
      const repository = new TaskRepository(this.gateway, userId);
      const priority = entry.priority === 'low' || entry.priority === 'high' ? entry.priority : 'medium';
      const itemId = await repository.save({
        title: entry.label.trim(),
        description: entry.description?.trim() || '',
        startDate: localStartOfDay(start),
        dueDate: endAt ?? start,
        allDay: entry.allDay,
        priority,
        status: 'todo',
        repeatRule: entry.repeatRule?.trim() || null,
        relatedGoalId: null,
        clientMutationId: entry.id,
      });
      return { itemId };
    }

    const repository = new HabitRepository(this.gateway, userId);
    const category = entry.category === 'evening' || entry.category === 'health' || entry.category === 'work'
      ? entry.category
      : 'morning';
    const itemId = await repository.save({
      name: entry.label.trim(),
      category,
      frequencyLabel: entry.frequency?.trim() || 'Daily',
      colorValue: typeof entry.color === 'number' ? entry.color : DEFAULT_HABIT_COLOR,
      reminderTimeLabel: startAt && !entry.allDay ? this.formatHabitTime(startAt) : null,
      clientMutationId: entry.id,
    });
    return { itemId };
  }

  async setDoneFromWidget(userId: string, entry: PendingToggle, resolvedItemId?: string): Promise<void> {
    const id = resolvedItemId ?? entry.id;
    if (entry.kind === 'task') {
      await new TaskRepository(this.gateway, userId).setDone(id, entry.done);
      return;
    }
    if (entry.kind === 'habit') {
      await new HabitRepository(this.gateway, userId).setCompletionToday(id, entry.done);
      return;
    }
    await new ReminderRepository(this.gateway, userId).setDone(id, entry.done);
  }
}

