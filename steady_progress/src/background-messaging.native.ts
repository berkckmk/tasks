import { getMessaging, setBackgroundMessageHandler } from '@react-native-firebase/messaging';
import { Platform } from 'react-native';
import SteadyReminders from '../modules/steady-reminders/src/SteadyRemindersModule';
import { refreshWidgetInBackground } from './features/widget/background-widget-sync';

const REMINDER_SYNC_TYPE = 'reminder_schedule_sync';

/**
 * Receives data-only FCM invalidations while the app UI is backgrounded or
 * terminated. This keeps Android's native AlarmManager registry aligned with
 * reminder edits made on the web without requiring the user to open the app.
 */
if (Platform.OS === 'android') {
  setBackgroundMessageHandler(getMessaging(), async (message) => {
    const data = message.data;
    // Alarm registration is safety-critical and must not wait for a Firestore
    // widget refresh on a slow/cold connection.
    if (SteadyReminders && data?.type === REMINDER_SYNC_TYPE) {
      const id = typeof data.reminderId === 'string' ? data.reminderId : '';
      if (id) {
        if (data.operation === 'cancel') {
          await SteadyReminders.cancel(id);
        } else {
          const timestampMs = Number(typeof data.timestampMs === 'string' ? data.timestampMs : NaN);
          if (!Number.isSafeInteger(timestampMs) || timestampMs <= Date.now()) {
            await SteadyReminders.cancel(id);
          } else {
            const priority = data.priority === 'important' || data.priority === 'low'
              ? data.priority
              : 'normal';
            await SteadyReminders.ensureChannels();
            await SteadyReminders.schedule(
              id,
              timestampMs,
              typeof data.title === 'string' ? data.title : 'Hatırlatıcı',
              typeof data.message === 'string' ? data.message : '',
              priority,
            );
          }
        }
      }
    }

    if (data?.widgetRefresh === 'true') {
      await refreshWidgetInBackground().catch(() => false);
    }
  });
}

