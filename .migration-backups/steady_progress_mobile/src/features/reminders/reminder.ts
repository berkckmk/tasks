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
};

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
  };
}

