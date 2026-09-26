import { dateFromFirestore, enumValue } from '../../core/data/firestore-values.ts';

export const habitCategories = ['morning', 'evening', 'health', 'work'] as const;
export const habitFrequencies = ['Daily', '3x / week', '5x / week', 'Weekdays', 'Weekly'] as const;
export type HabitCategory = typeof habitCategories[number];
export type HabitFrequency = typeof habitFrequencies[number];

export type Habit = {
  id: string;
  name: string;
  category: HabitCategory;
  frequencyLabel: string;
  streak: number;
  isCompletedToday: boolean;
  colorValue: number;
  reminderTimeLabel: string | null;
  syncEnabled: boolean;
  googleCalendarReminderEventId: string | null;
  lastSyncedAt: Date | null;
};

export type HabitLog = {
  id: string;
  habitId: string;
  date: string;
  completed: boolean;
  completedAt: Date | null;
};

export function habitFromDocument(id: string, data: Record<string, unknown>): Habit {
  return {
    id,
    name: typeof data.name === 'string' ? data.name : '',
    category: enumValue(data.category, habitCategories, 'morning'),
    frequencyLabel: typeof data.frequencyLabel === 'string' ? data.frequencyLabel : 'Daily',
    streak: 0,
    isCompletedToday: false,
    colorValue: typeof data.colorValue === 'number' ? data.colorValue : 0xff2f5233,
    reminderTimeLabel: typeof data.reminderTimeLabel === 'string' ? data.reminderTimeLabel : null,
    syncEnabled: data.syncEnabled === true,
    googleCalendarReminderEventId: typeof data.googleCalendarReminderEventId === 'string'
      ? data.googleCalendarReminderEventId
      : null,
    lastSyncedAt: dateFromFirestore(data.lastSyncedAt),
  };
}

export function habitLogFromDocument(id: string, data: Record<string, unknown>): HabitLog {
  return {
    id,
    habitId: typeof data.habitId === 'string' ? data.habitId : '',
    date: typeof data.date === 'string' ? data.date : '',
    completed: data.completed === true,
    completedAt: dateFromFirestore(data.completedAt),
  };
}

export function addCalendarDays(date: Date, days: number) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() + days);
}

export function formatLogDate(date: Date) {
  const year = String(date.getFullYear()).padStart(4, '0');
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function mergeHabitsWithLogs(habits: Habit[], logs: HabitLog[], today = new Date()): Habit[] {
  const datesByHabit = new Map<string, Set<string>>();
  for (const log of logs) {
    if (!log.completed) continue;
    const dates = datesByHabit.get(log.habitId) ?? new Set<string>();
    dates.add(log.date);
    datesByHabit.set(log.habitId, dates);
  }
  return habits.map((habit) => {
    const dates = datesByHabit.get(habit.id) ?? new Set<string>();
    return {
      ...habit,
      isCompletedToday: dates.has(formatLogDate(today)),
      streak: calculateStreak(dates, today, habit),
    };
  });
}

function calculateStreak(completedDates: Set<string>, today: Date, habit?: Habit) {
  // Days the habit is not scheduled on (weekends for a weekdays habit) neither
  // count nor break the streak.
  const scheduled = (date: Date) => !habit || habitIsScheduledOn(habit, date);
  let streak = 0;
  let cursor = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  // Today not done yet does not break the streak.
  if (!completedDates.has(formatLogDate(cursor))) cursor = addCalendarDays(cursor, -1);
  for (let guard = 0; guard < 3660; guard += 1) {
    if (!scheduled(cursor)) {
      cursor = addCalendarDays(cursor, -1);
      continue;
    }
    if (!completedDates.has(formatLogDate(cursor))) break;
    streak += 1;
    cursor = addCalendarDays(cursor, -1);
  }
  return streak;
}

/** Days of habit logs needed for streaks to be right (widget, dashboard). */
export const HABIT_STREAK_LOG_DAYS = 60;

export function isWeekdaysFrequency(frequencyLabel: string) {
  const f = frequencyLabel.trim().toLowerCase();
  return (
    f === 'weekdays' ||
    f === 'hafta içi' ||
    f === 'hafta ici' ||
    f.includes('hafta içi') ||
    f.includes('hafta ici') ||
    f === 'hafta içi (pzt-cum)'
  );
}

export function habitIsScheduledOn(habit: Habit, date: Date) {
  if (isWeekdaysFrequency(habit.frequencyLabel)) return date.getDay() >= 1 && date.getDay() <= 5;
  // Weekly/count-per-week values do not store chosen weekdays in the legacy
  // model. They remain available every day instead of inventing a schedule.
  return true;
}

export function habitHasFixedDays(habit: Habit) {
  return isWeekdaysFrequency(habit.frequencyLabel);
}


/** Parses legacy 12/24-hour display labels without guessing invalid values. */
export function parseHabitTime(label: string | null, day = new Date()) {
  if (!label?.trim()) return null;
  const normalized = label.trim().replaceAll('\u202f', ' ').replaceAll('\u00a0', ' ');
  const match = /^(\d{1,2})[:.](\d{2})\s*([ap]m)?$/i.exec(normalized);
  if (!match) return null;
  let hour = Number(match[1]);
  const minute = Number(match[2]);
  const meridiem = match[3]?.toLowerCase();
  if (meridiem === 'pm' && hour !== 12) hour += 12;
  if (meridiem === 'am' && hour === 12) hour = 0;
  if (hour > 23 || minute > 59) return null;
  return new Date(day.getFullYear(), day.getMonth(), day.getDate(), hour, minute);
}

export function formatHabitTime(date: Date) {
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}
