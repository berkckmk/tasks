/** Wire format of the existing Kotlin widget. Keep field names unchanged. */
export type WidgetKind = 'habit' | 'task' | 'reminder';
export type WidgetRow = {
  id: string;
  kind: WidgetKind;
  label: string;
  done?: boolean;
  time?: string;
};
export type WidgetItems = {
  habits: WidgetRow[];
  tasks: WidgetRow[];
  reminders: WidgetRow[];
};
export type WidgetSnapshot = {
  habitsDone: number;
  habitsTotal: number;
  tasksDone: number;
  tasksTotal: number;
  bestStreak: number;
  /** Nested lists remain JSON text, as expected by WidgetDataStore. */
  items: string;
};
export type PendingToggle = {
  id: string;
  kind: WidgetKind;
  done: boolean;
  at: number;
};
export type PendingAdd = {
  id: string;
  kind: WidgetKind;
  label: string;
  startAt: number;
  endAt: number;
  allDay: boolean;
  at: number;
  description?: string;
  priority?: string;
  repeatRule?: string;
  isImportant?: boolean;
  category?: string;
  frequency?: string;
  color?: number;
};

function record(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('Widget record must be an object');
  }
  return value as Record<string, unknown>;
}
function text(value: unknown, field: string): string {
  if (typeof value !== 'string' || !value.trim()) throw new Error(`Invalid ${field}`);
  return value;
}
function kind(value: unknown): WidgetKind {
  if (value !== 'habit' && value !== 'task' && value !== 'reminder') {
    throw new Error('Unknown widget item kind');
  }
  return value;
}
function timestamp(value: unknown, field: string): number {
  if (!Number.isSafeInteger(value) || (value as number) < 0) {
    throw new Error(`Invalid ${field}`);
  }
  return value as number;
}
function boolean(value: unknown, field: string): boolean {
  if (typeof value !== 'boolean') throw new Error(`Invalid ${field}`);
  return value;
}
function array(raw: string): unknown[] {
  const parsed: unknown = JSON.parse(raw);
  if (!Array.isArray(parsed)) throw new Error('Widget queue must be an array');
  return parsed;
}

// Fail the read visibly rather than acknowledging a partially parsed queue.
export function parsePendingToggles(raw: string): PendingToggle[] {
  return array(raw).map((value) => {
    const row = record(value);
    return {
      id: text(row.id, 'id'), kind: kind(row.kind),
      done: boolean(row.done, 'done'), at: timestamp(row.at, 'at'),
    };
  });
}
export function parsePendingAdds(raw: string): PendingAdd[] {
  return array(raw).map((value) => {
    const row = record(value);
    return {
      id: text(row.id, 'id'), kind: kind(row.kind), label: text(row.label, 'label'),
      // Older installed versions did not store schedule fields.
      startAt: timestamp(row.startAt ?? 0, 'startAt'),
      endAt: timestamp(row.endAt ?? 0, 'endAt'),
      allDay: boolean(row.allDay ?? true, 'allDay'),
      at: timestamp(row.at, 'at'),
      ...(typeof row.description === 'string' ? { description: row.description } : {}),
      ...(typeof row.priority === 'string' ? { priority: row.priority } : {}),
      ...(typeof row.repeatRule === 'string' ? { repeatRule: row.repeatRule } : {}),
      ...(typeof row.isImportant === 'boolean' ? { isImportant: row.isImportant } : {}),
      ...(typeof row.category === 'string' ? { category: row.category } : {}),
      ...(typeof row.frequency === 'string' ? { frequency: row.frequency } : {}),
      ...(typeof row.color === 'number' ? { color: row.color } : {}),
    };
  });
}

export function parseWidgetRoute(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const cleaned = raw.trim();
  const path = cleaned.startsWith('/') ? cleaned : `/${cleaned}`;
  return /^\/(tasks?|habits?|reminders?)(?:\/[^/?#]+(?:\/edit)?)?$/.test(path) ? path : null;
}

/** Synthetic only: never use account data in this independent prototype. */
export const previewSnapshot: WidgetSnapshot = {
  habitsDone: 1, habitsTotal: 2, tasksDone: 0, tasksTotal: 2, bestStreak: 7,
  items: JSON.stringify({
    habits: [
      { id: 'preview-habit-1', kind: 'habit', label: 'Morning run', time: '7:30 AM' },
      { id: 'preview-habit-2', kind: 'habit', label: 'Read ten pages', done: true },
    ],
    tasks: [
      { id: 'preview-task-1', kind: 'task', label: 'Plan the week', time: '9:00 AM' },
      { id: 'preview-task-2', kind: 'task', label: 'Review project notes' },
    ],
    reminders: [
      { id: 'preview-reminder-1', kind: 'reminder', label: 'Morning planning', time: '8:00 AM' },
    ],
  } satisfies WidgetItems),
};
