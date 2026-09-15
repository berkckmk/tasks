import { useEffect, useMemo, useRef, useState } from 'react';
import { Platform } from 'react-native';
import { useAppData } from '../../core/data/app-data';
import { ReminderRepository } from '../reminders/reminder-repository';
import type { ReminderItem } from '../reminders/reminder';
import { TaskRepository } from '../tasks/task-repository';
import type { TaskItem } from '../tasks/task-item';
import {
  getWebNotificationPermission,
  isWebNotificationSupported,
  requestWebNotificationPermission,
  sendWebNotification,
} from './web-notification-service';
import { countTodayPendingItems } from './web-today-filter';
import { updateDockBadge } from './web-dock-badge-service';

export function WebNotificationsHost() {
  if (Platform.OS !== 'web') return null;

  const { gateway, userId, synthetic } = useAppData();
  const [reminders, setReminders] = useState<ReminderItem[]>([]);
  const [tasks, setTasks] = useState<TaskItem[]>([]);
  const firedReminders = useRef<Set<string>>(new Set());

  const repositories = useMemo(
    () => ({
      reminders: new ReminderRepository(gateway, userId),
      tasks: new TaskRepository(gateway, userId),
    }),
    [gateway, userId],
  );

  // 1. Register Firebase Messaging Service Worker for PWA, background push & notification click routing
  useEffect(() => {
    if (typeof window === 'undefined' || !('serviceWorker' in navigator)) return;
    navigator.serviceWorker
      .register('/firebase-messaging-sw.js')
      .catch((err) => console.warn('[SW_REGISTRATION_FAILED]', err));
  }, []);

  // 2. Proactively ask for notification permission on initial mount if not decided
  useEffect(() => {
    if (!isWebNotificationSupported()) return;
    if (getWebNotificationPermission() === 'default') {
      void requestWebNotificationPermission();
    }
  }, []);

  // 3. Watch reminders and tasks
  useEffect(() => {
    if (synthetic) return;
    const unsubReminders = repositories.reminders.watch(setReminders, () => undefined);
    const unsubTasks = repositories.tasks.watch(setTasks, () => undefined);

    return () => {
      unsubReminders();
      unsubTasks();
    };
  }, [repositories, synthetic]);

  // 4. Update macOS Dock Badge counter (Incomplete tasks + reminders dated today only)
  useEffect(() => {
    const syncBadge = () => {
      const totalTodayPending = countTodayPendingItems({ reminders, tasks });
      void updateDockBadge(totalTodayPending);
    };

    syncBadge();

    // Re-check periodically (every 60s) so midnight roll-over updates badge automatically
    const timer = setInterval(syncBadge, 60_000);
    return () => clearInterval(timer);
  }, [reminders, tasks]);

  // 5. Schedule in-memory notifications for due reminders
  useEffect(() => {
    const activeTimeouts: ReturnType<typeof setTimeout>[] = [];
    const now = Date.now();

    for (const reminder of reminders) {
      if (reminder.status === 'completed' || !reminder.dueAt) continue;
      const dueTime = reminder.dueAt.getTime();

      // If due within next 24 hours and not fired yet
      if (dueTime >= now && dueTime <= now + 86_400_000) {
        if (firedReminders.current.has(reminder.id)) continue;

        const delay = dueTime - now;
        const timer = setTimeout(() => {
          firedReminders.current.add(reminder.id);
          sendWebNotification(reminder.title || 'Hatırlatıcı', {
            body: reminder.message || 'Zamanı gelen hatırlatıcınız var.',
            tag: `reminder-${reminder.id}`,
            onClick: () => {
              if (typeof window !== 'undefined') {
                window.location.href = '/main/reminders';
              }
            },
          });
        }, delay);

        activeTimeouts.push(timer);
      }
    }

    return () => {
      activeTimeouts.forEach(clearTimeout);
    };
  }, [reminders]);

  return null;
}
