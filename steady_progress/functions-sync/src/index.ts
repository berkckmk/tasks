import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { setGlobalOptions } from 'firebase-functions/v2';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';

if (getApps().length === 0) initializeApp();
const db = getFirestore();

setGlobalOptions({
  region: 'us-central1',
  maxInstances: 10,
  memory: '256MiB',
  timeoutSeconds: 60,
});

function isUnregisteredError(code: string | undefined): boolean {
  return code === 'messaging/registration-token-not-registered'
    || code === 'messaging/invalid-registration-token';
}

async function sendData(uid: string, data: Record<string, string>): Promise<void> {
  const tokenSnapshot = await db.collection('users').doc(uid).collection('fcmTokens').get();
  if (tokenSnapshot.empty) return;

  const response = await getMessaging().sendEachForMulticast({
    tokens: tokenSnapshot.docs.map((doc) => doc.id),
    data,
    android: { priority: 'high' },
    apns: { payload: { aps: { contentAvailable: true } } },
  });

  await Promise.all(response.responses.map((result, index) => {
    if (!result.success && isUnregisteredError(result.error?.code)) {
      return tokenSnapshot.docs[index]!.ref.delete();
    }
    return Promise.resolve();
  }));
}

export const syncReminderScheduleToDevices = onDocumentWritten(
  'users/{uid}/reminders/{reminderId}',
  async (event) => {
    const value = event.data?.after.exists ? event.data.after.data() : undefined;
    const timestampMs = value?.dueAt?.toMillis?.();
    const scheduled = value?.status === 'scheduled' || value?.status === 'snoozed';
    const operation = scheduled && Number.isSafeInteger(timestampMs) ? 'schedule' : 'cancel';

    await sendData(event.params.uid, {
      type: 'reminder_schedule_sync',
      widgetRefresh: 'true',
      operation,
      reminderId: event.params.reminderId,
      timestampMs: operation === 'schedule' ? String(timestampMs) : '0',
      title: typeof value?.title === 'string' ? value.title : 'Hatırlatıcı',
      message: typeof value?.message === 'string' ? value.message : '',
      priority: value?.priority === 'important' || value?.priority === 'low'
        ? value.priority
        : 'normal',
    });
  },
);

async function refreshWidget(uid: string): Promise<void> {
  await sendData(uid, { type: 'widget_refresh', widgetRefresh: 'true' });
}

export const syncWidgetOnHabitWrite = onDocumentWritten(
  'users/{uid}/habits/{documentId}',
  (event) => refreshWidget(event.params.uid),
);

export const syncWidgetOnHabitLogWrite = onDocumentWritten(
  'users/{uid}/habit_logs/{documentId}',
  (event) => refreshWidget(event.params.uid),
);

export const syncWidgetOnTaskWrite = onDocumentWritten(
  'users/{uid}/tasks/{documentId}',
  (event) => refreshWidget(event.params.uid),
);
