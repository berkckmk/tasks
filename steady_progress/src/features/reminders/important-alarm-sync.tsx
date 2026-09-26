import { useEffect, useMemo } from 'react';
import { AppState, type AppStateStatus } from 'react-native';
import { useAppData } from '@/core/data/app-data';
import { ReminderRepository } from './reminder-repository';
import { ImportantAlarmService } from './important-alarm-service';
import { alarmsToCancel, planAlarms } from './alarm-plan';
import type { ReminderItem } from './reminder';

export function ImportantAlarmSync() {
  const { gateway, userId } = useAppData();
  const repository = useMemo(() => new ReminderRepository(gateway, userId), [gateway, userId]);

  useEffect(() => {
    // 1. Initial drain of any pending actions from when the app was closed
    void ImportantAlarmService.syncPendingActions(repository);

    // 2. Listen for real-time actions from native UI (lockscreen activity or notification buttons)
    const unsubscribe = ImportantAlarmService.subscribeToActions((event) => {
      void ImportantAlarmService.applyAlarmAction(repository, event).catch(() => {});
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
    // Alarms this session has asked the native side to hold, by reminder id.
    const planned = new Map<string, number>();
    let latest: ReminderItem[] = [];

    const reconcile = (reminders: ReminderItem[]) => {
      latest = reminders;
      const now = new Date();
      // Missed repeating reminders come back to today (fire and forget; the
      // write re-enters here through the watch).
      void repository.rollForwardMissed(reminders, now).catch(() => {});

      for (const id of alarmsToCancel(planned.keys(), reminders)) {
        planned.delete(id);
        void ImportantAlarmService.cancel(id).catch(() => {});
      }
      for (const alarm of planAlarms(reminders, now).values()) {
        if (planned.get(alarm.id) === alarm.timestampMs) continue;
        planned.set(alarm.id, alarm.timestampMs);
        void ImportantAlarmService.schedule(alarm).catch(() => {});
      }
    };

    const unsubscribe = repository.watch(reconcile, () => {});
    // The watch only fires on data changes; a new day must also roll missed
    // reminders forward, so re-check whenever the app comes back.
    const appStateSub = AppState.addEventListener('change', (state) => {
      if (state === 'active') reconcile(latest);
    });

    return () => {
      unsubscribe();
      appStateSub.remove();
    };
  }, [repository]);

  return null;
}
