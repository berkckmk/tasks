import { useEffect, useMemo } from 'react';
import { AppState, type AppStateStatus } from 'react-native';
import { useAppData } from '@/core/data/app-data';
import { ReminderRepository } from './reminder-repository';
import { ImportantAlarmService } from './important-alarm-service';

export function ImportantAlarmSync() {
  const { gateway, userId } = useAppData();
  const repository = useMemo(() => new ReminderRepository(gateway, userId), [gateway, userId]);

  useEffect(() => {
    // 1. Initial drain of any pending actions from when the app was closed
    void ImportantAlarmService.syncPendingActions(repository);

    // 2. Listen for real-time actions from native UI (lockscreen activity or notification buttons)
    const unsubscribe = ImportantAlarmService.subscribeToActions((event) => {
      if (event.action === 'complete') {
        void (async () => {
          const res = await repository.setDone(event.reminderId, true);
          if (res.wasRepeated && res.nextDueAt) {
            await ImportantAlarmService.schedule({
              id: event.reminderId,
              timestampMs: res.nextDueAt.getTime(),
              title: res.title || 'Hatırlatıcı',
              message: '',
              priority: 'important',
            });
          }
        })();
      } else if (event.action === 'snooze') {
        const snoozedMs = event.snoozedUntilMs ?? (Date.now() + 10 * 60_000);
        void repository.snoozeTo(event.reminderId, new Date(snoozedMs));
      }
    });


    // 3. Drain pending actions whenever the app returns to active/foreground state
    const handleAppStateChange = (state: AppStateStatus) => {
      if (state === 'active') {
        void ImportantAlarmService.syncPendingActions(repository);
      }
    };
    const appStateSub = AppState.addEventListener('change', handleAppStateChange);

    return () => {
      unsubscribe();
      appStateSub.remove();
    };
  }, [repository]);

  useEffect(() => {
    const unsubscribe = repository.watch((reminders) => {
      const nowMs = Date.now();
      for (const item of reminders) {
        if (item.status === 'scheduled' && item.dueAt && item.dueAt.getTime() > nowMs) {
          void ImportantAlarmService.schedule({
            id: item.id,
            timestampMs: item.dueAt.getTime(),
            title: item.title,
            message: item.message,
            priority: item.priority,
          });
        }
      }
    }, () => {});

    return () => unsubscribe();
  }, [repository]);

  return null;
}
