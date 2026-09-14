import { useEffect, useMemo, useRef } from 'react';
import SteadyWidget from '../../../modules/steady-widget';
import { useAppData } from '../../core/data/app-data.tsx';
import { HabitRepository } from '../habits/habit-repository.ts';
import { formatLogDate, mergeHabitsWithLogs, type Habit, type HabitLog } from '../habits/habit.ts';
import { ReminderRepository } from '../reminders/reminder-repository.ts';
import type { ReminderItem } from '../reminders/reminder.ts';
import { TaskRepository } from '../tasks/task-repository.ts';
import type { TaskItem } from '../tasks/task-item.ts';
import { buildWidgetSnapshot } from './widget-snapshot.ts';

/** Pushes a snapshot only for the authenticated, non-synthetic application host. */
export function WidgetDataSync() {
  const { gateway, userId, synthetic } = useAppData();
  const lastSnapshot = useRef('');
  const repositories = useMemo(() => ({
    habits: new HabitRepository(gateway, userId),
    tasks: new TaskRepository(gateway, userId),
    reminders: new ReminderRepository(gateway, userId),
  }), [gateway, userId]);

  useEffect(() => {
    if (!SteadyWidget) return;
    const bridge = SteadyWidget;
    let rawHabits: Habit[] | null = null;
    let habitLogs: HabitLog[] = [];
    let tasks: TaskItem[] | null = null;
    let reminders: ReminderItem[] | null = null;
    const push = () => {
      if (!rawHabits || !tasks || !reminders) return;
      const habits = mergeHabitsWithLogs(rawHabits, habitLogs);
      const snapshot = buildWidgetSnapshot({ habits, tasks, reminders });
      const serialized = JSON.stringify(snapshot);
      if (serialized === lastSnapshot.current) return;
      lastSnapshot.current = serialized;
      void bridge.updateWidget(snapshot).catch(() => {
        lastSnapshot.current = '';
      });
    };
    const onError = () => undefined;
    const cutoff = formatLogDate(new Date());
    const stops = [
      repositories.habits.watch((value) => { rawHabits = value; push(); }, onError),
      repositories.habits.watchRecentLogs((value) => { habitLogs = value; push(); }, onError, cutoff),
      repositories.tasks.watch((value) => { tasks = value; push(); }, onError),
      repositories.reminders.watch((value) => { reminders = value; push(); }, onError),
    ];
    const now = new Date();
    const nextMidnight = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 5);
    const msUntilMidnight = Math.max(1000, nextMidnight.getTime() - now.getTime());
    const midnightTimer = setTimeout(() => {
      push();
    }, msUntilMidnight);

    return () => {
      clearTimeout(midnightTimer);
      stops.forEach((stop) => stop());
    };
  }, [repositories, synthetic]);
  return null;
}

