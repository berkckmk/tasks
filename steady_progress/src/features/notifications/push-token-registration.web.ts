import { getToken, deleteToken, onMessage, type Unsubscribe } from 'firebase/messaging';
import { Platform } from 'react-native';
import type { DataGateway } from '../../core/data/data-gateway';
import {
  FCM_VAPID_KEY,
  getFirebaseWebMessaging,
} from '../../core/firebase/firebase-web-config';
import { sendWebNotification } from './web-notification-service';

function tokenPath(userId: string, token: string) {
  return `users/${userId}/fcmTokens/${token}`;
}

async function save(gateway: DataGateway, userId: string, token: string) {
  await gateway.setDocument(
    tokenPath(userId, token),
    { token, platform: 'web', updatedAt: gateway.serverTimestamp() },
    { merge: true },
  );
}

/**
 * Register the browser for Firebase Cloud Messaging web push.
 *
 * 1. Registers `firebase-messaging-sw.js` service worker.
 * 2. Requests notification permission.
 * 3. Obtains an FCM push token via the VAPID key.
 * 4. Persists the token to Firestore so Cloud Functions can send to it.
 * 5. Listens for foreground messages and shows browser notifications.
 *
 * Returns a cleanup function that unsubscribes from the foreground listener.
 */
export async function registerPushToken(
  gateway: DataGateway,
  userId: string,
): Promise<() => void> {
  if (typeof window === 'undefined' || !('serviceWorker' in navigator)) {
    return () => undefined;
  }

  // Skip if VAPID key is not configured yet.
  if (!FCM_VAPID_KEY || FCM_VAPID_KEY === 'VAPID_KEY_PLACEHOLDER') {
    console.warn('[WEB_PUSH] VAPID key not configured — skipping FCM registration.');
    return () => undefined;
  }

  try {
    // 1. Register the Firebase Messaging service worker
    const swRegistration = await navigator.serviceWorker.register(
      '/firebase-messaging-sw.js',
      { scope: '/' },
    );

    // 2. Request notification permission
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') {
      console.warn('[WEB_PUSH] Notification permission denied.');
      return () => undefined;
    }

    // 3. Get FCM token
    const messaging = getFirebaseWebMessaging();
    const token = await getToken(messaging, {
      vapidKey: FCM_VAPID_KEY,
      serviceWorkerRegistration: swRegistration,
    });

    if (!token) {
      console.warn('[WEB_PUSH] No FCM token received.');
      return () => undefined;
    }

    // 4. Save token to Firestore
    await save(gateway, userId, token);
    console.log('[WEB_PUSH] FCM token registered successfully.');

    // 5. Listen for foreground push messages and show as browser notifications.
    //    (Background messages are handled by firebase-messaging-sw.js.)
    const unsubscribe: Unsubscribe = onMessage(messaging, (payload) => {
      console.log('[WEB_PUSH] Foreground message:', payload);

      const notification = payload.notification;
      const data = payload.data || {};
      const title = notification?.title || data.title || 'Steady Progress';
      const body = notification?.body || data.body || data.message || '';

      let targetUrl = '/';
      if (data.type === 'reminder') targetUrl = '/main/reminders';
      else if (data.type === 'habit') targetUrl = '/main/habits';
      else if (data.type === 'digest') targetUrl = '/main/tasks';

      sendWebNotification(title, {
        body,
        tag: `fcm-${data.type || 'generic'}-${data.reminderId || data.habitId || ''}`,
        onClick: () => {
          if (typeof window !== 'undefined') {
            window.location.href = targetUrl;
          }
        },
      });
    });

    return unsubscribe;
  } catch (err) {
    console.error('[WEB_PUSH] Registration failed:', err);
    return () => undefined;
  }
}

export async function unregisterPushToken(
  gateway: DataGateway,
  userId: string,
): Promise<void> {
  if (typeof window === 'undefined') return;
  if (!FCM_VAPID_KEY || FCM_VAPID_KEY === 'VAPID_KEY_PLACEHOLDER') return;

  try {
    const messaging = getFirebaseWebMessaging();
    const token = await getToken(messaging, { vapidKey: FCM_VAPID_KEY }).catch(
      () => null,
    );
    if (token) {
      await gateway.deleteDocument(tokenPath(userId, token));
      await deleteToken(messaging).catch(() => undefined);
    }
  } catch {
    // Best-effort cleanup
  }
}
