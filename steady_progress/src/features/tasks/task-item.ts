import { dateFromFirestore, enumValue } from '../../core/data/firestore-values.ts';

export const taskPriorities = ['low', 'medium', 'high'] as const;
export const taskStatuses = ['todo', 'inProgress', 'done'] as const;
export type TaskPriority = typeof taskPriorities[number];
export type TaskStatus = typeof taskStatuses[number];

export type TaskItem = {
  id: string;
  title: string;
  description: string;
  startDate: Date | null;
  dueDate: Date | null;
  allDay: boolean;
  priority: TaskPriority;
  status: TaskStatus;
  relatedGoalId: string | null;
  syncEnabled: boolean;
  googleCalendarEventId: string | null;
  lastSyncedAt: Date | null;
  repeatRule?: string | null;
  lastCompletedAt?: Date | null;
};

export function taskFromDocument(id: string, data: Record<string, unknown>): TaskItem {
  return {
    id,
    title: typeof data.title === 'string' ? data.title : '',
    description: typeof data.description === 'string' ? data.description : '',
    startDate: dateFromFirestore(data.startDate),
    dueDate: dateFromFirestore(data.dueDate),
    allDay: typeof data.allDay === 'boolean' ? data.allDay : true,
    priority: enumValue(data.priority, taskPriorities, 'medium'),
    status: enumValue(data.status, taskStatuses, 'todo'),
    relatedGoalId: typeof data.relatedGoalId === 'string' ? data.relatedGoalId : null,
    syncEnabled: data.syncEnabled === true,
    googleCalendarEventId: typeof data.googleCalendarEventId === 'string' ? data.googleCalendarEventId : null,
    lastSyncedAt: dateFromFirestore(data.lastSyncedAt),
    repeatRule: typeof data.repeatRule === 'string' ? data.repeatRule : null,
    lastCompletedAt: dateFromFirestore(data.lastCompletedAt),
  };
}


export function taskSpansDays(task: TaskItem) {
  if (!task.startDate || !task.dueDate) return false;
  return formatCalendarDate(task.startDate) !== formatCalendarDate(task.dueDate);
}

export function formatCalendarDate(date: Date) {
  const year = String(date.getFullYear()).padStart(4, '0');
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}
