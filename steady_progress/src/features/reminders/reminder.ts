import { dateFromFirestore, enumValue, stringList } from '../../core/data/firestore-values.ts';

export const reminderStatuses = ['scheduled', 'completed', 'snoozed', 'missed'] as const;
export const reminderPriorities = ['low', 'normal', 'important'] as const;
export type ReminderStatus = typeof reminderStatuses[number];
export type ReminderPriority = typeof reminderPriorities[number];

export type ReminderItem = {
  id: string;
  title: string;
  message: string;
  dueAt: Date | null;
  status: ReminderStatus;
  priority: ReminderPriority;
  starred: boolean;
  earlyAlertMinutes: number | null;
  repeatRule: string | null;
  location: string | null;
  category: string;
  checklist: string[];
  lastCompletedAt?: Date | null;
  /** Day of month a monthly/yearly series is anchored on. */
  repeatAnchorDay?: number | null;
  /** Original time of an occurrence that is currently snoozed. */
  snoozedFromDueAt?: Date | null;
  /** Completed occurrences of a repeating reminder, oldest first. */
  completions?: ReminderCompletion[];
  /** Occurrences of a repeating reminder that passed undone, oldest first. */
  missedOccurrences?: Date[];
  /**
   * Set on list rows built for the Yapılanlar ("done") and Geçmiş ("missed")
   * sections: which section the row is for and how many days it stands for.
   */
  rowRole?: 'done' | 'missed';
  rowCount?: number;
};

export type ReminderCompletion = {
  occurrence: Date;
  completedAt: Date;
};

export function missedFromFirestore(value: unknown): Date[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((entry) => dateFromFirestore(entry))
    .filter((date): date is Date => date !== null)
    .sort((a, b) => a.getTime() - b.getTime());
}

export function completionsFromFirestore(value: unknown): ReminderCompletion[] {
  if (!Array.isArray(value)) return [];
  const result: ReminderCompletion[] = [];
  for (const entry of value) {
    if (!entry || typeof entry !== 'object') continue;
    const occurrence = dateFromFirestore((entry as Record<string, unknown>).occurrence);
    const completedAt = dateFromFirestore((entry as Record<string, unknown>).completedAt);
    if (occurrence && completedAt) result.push({ occurrence, completedAt });
  }
  return result.sort((a, b) => a.completedAt.getTime() - b.completedAt.getTime());
}

export {
  repeatRules,
  type RepeatRule,
  normalizeRepeatRule,
  calculateNextDueDate,
  calculatePreviousDueDate,
  formatDayOfWeekShort,
  getRecurrenceDayBadge,
} from './recurrence.ts';

const medicineWords = [
  'duxet', 'aubagio', 'folik', 'ilaç', 'ilac', 'hap', 'medicine', 'pill', 'vitamin', 'antibiyotik',
];

export function isMedicineReminder(title: string, message: string) {
  const searchable = `${title} ${message}`.toLocaleLowerCase('tr-TR');
  return medicineWords.some((word) => searchable.includes(word));
}

export function effectiveReminderPriority(
  title: string,
  message: string,
  priority: ReminderPriority | null | undefined,
): ReminderPriority {
  if (isMedicineReminder(title, message) && (!priority || priority === 'normal')) return 'important';
  return priority ?? 'normal';
}

export function reminderFromDocument(id: string, data: Record<string, unknown>): ReminderItem {
  const title = typeof data.title === 'string' ? data.title : '';
  const message = typeof data.message === 'string' ? data.message : '';
  const parsedPriority = enumValue(data.priority, reminderPriorities, 'normal');
  return {
    id,
    title,
    message,
    dueAt: dateFromFirestore(data.dueAt),
    status: enumValue(data.status, reminderStatuses, 'scheduled'),
    priority: effectiveReminderPriority(title, message, parsedPriority),
    starred: data.starred === true,
    earlyAlertMinutes: typeof data.earlyAlertMinutes === 'number'
      ? Math.trunc(data.earlyAlertMinutes)
      : null,
    repeatRule: typeof data.repeatRule === 'string' ? data.repeatRule : null,
    location: typeof data.location === 'string' ? data.location : null,
    category: typeof data.category === 'string' ? data.category : 'Hatırlatıcılarım',
    checklist: stringList(data.checklist),
    lastCompletedAt: dateFromFirestore(data.lastCompletedAt),
    repeatAnchorDay: typeof data.repeatAnchorDay === 'number' ? data.repeatAnchorDay : null,
    snoozedFromDueAt: dateFromFirestore(data.snoozedFromDueAt),
    completions: completionsFromFirestore(data.completions),
    missedOccurrences: missedFromFirestore(data.missedOccurrences),
  };
}

