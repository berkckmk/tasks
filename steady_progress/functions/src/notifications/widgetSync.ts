import { getMessaging } from 'firebase-admin/messaging';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';

import { db } from '../lib/admin';

async function sendWidgetRefresh(uid: string): Promise<void> {
  const tokenSnapshot = await db.collection('users').doc(uid).collection('fcmTokens').get();
  if (tokenSnapshot.empty) return;
  const response = await getMessaging().sendEachForMulticast({
    tokens: tokenSnapshot.docs.map((doc) => doc.id),
    data: { type: 'widget_refresh', widgetRefresh: 'true' },
    android: { priority: 'high' },
    apns: { payload: { aps: { contentAvailable: true } } },
  });
  await Promise.all(response.responses.map((result, index) => {
    const code = result.error?.code;
    if (!result.success && (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token')) {
      return tokenSnapshot.docs[index]!.ref.delete();
    }
    return Promise.resolve();
  }));
}

export const syncWidgetOnHabitWrite = onDocumentWritten(
  'users/{uid}/habits/{documentId}',
  (event) => sendWidgetRefresh(event.params.uid),
);

export const syncWidgetOnHabitLogWrite = onDocumentWritten(
  'users/{uid}/habit_logs/{documentId}',
  (event) => sendWidgetRefresh(event.params.uid),
);

export const syncWidgetOnTaskWrite = onDocumentWritten(
  'users/{uid}/tasks/{documentId}',
  (event) => sendWidgetRefresh(event.params.uid),
);
