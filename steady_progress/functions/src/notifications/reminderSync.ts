import { getMessaging } from 'firebase-admin/messaging';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';

import { db } from '../lib/admin';

function isUnregisteredError(code: string | undefined): boolean {
  return code === 'messaging/registration-token-not-registered'
    || code === 'messaging/invalid-registration-token';
}

/**
 * Pushes schedule changes immediately to Android. The message is data-only:
 * it does not show a notification when a reminder is edited; the background
 * handler updates the native AlarmManager entry instead.
 */
export const syncReminderScheduleToDevices = onDocumentWritten(
  'users/{uid}/reminders/{reminderId}',
  async (event) => {
    const uid = event.params.uid;
    const reminderId = event.params.reminderId;
    const after = event.data?.after;
    const value = after?.exists ? after.data() : undefined;
    const dueAt = value?.dueAt;
    const scheduled = value?.status === 'scheduled' || value?.status === 'snoozed';
    const timestampMs = dueAt?.toMillis?.();
    const operation = scheduled && Number.isSafeInteger(timestampMs) ? 'schedule' : 'cancel';

    const tokenSnapshot = await db.collection('users').doc(uid).collection('fcmTokens').get();
    if (tokenSnapshot.empty) return;

    const response = await getMessaging().sendEachForMulticast({
      tokens: tokenSnapshot.docs.map((doc) => doc.id),
      data: {
        type: 'reminder_schedule_sync',
        widgetRefresh: 'true',
        operation,
        reminderId,
        timestampMs: operation === 'schedule' ? String(timestampMs) : '0',
        title: typeof value?.title === 'string' ? value.title : 'Hatırlatıcı',
        message: typeof value?.message === 'string' ? value.message : '',
        priority: value?.priority === 'important' || value?.priority === 'low'
          ? value.priority
          : 'normal',
      },
      android: { priority: 'high' },
      apns: { payload: { aps: { contentAvailable: true } } },
    });

    await Promise.all(response.responses.map((result, index) => {
      if (!result.success && isUnregisteredError(result.error?.code)) {
        return tokenSnapshot.docs[index]!.ref.delete();
      }
      return Promise.resolve();
    }));
  },
);
