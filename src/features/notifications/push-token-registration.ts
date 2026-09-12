import { AuthorizationStatus, deleteToken, getMessaging, getToken, onTokenRefresh, requestPermission } from '@react-native-firebase/messaging';
import { Platform } from 'react-native';
import type { DataGateway } from '../../core/data/data-gateway.ts';
import { ensureNotificationPermission } from '../reminders/reminder-scheduler.ts';

function tokenPath(userId: string, token: string) { return `users/${userId}/fcmTokens/${token}`; }
async function save(gateway: DataGateway, userId: string, token: string) { await gateway.setDocument(tokenPath(userId, token), { token, platform: Platform.OS, updatedAt: gateway.serverTimestamp() }, { merge: true }); }

export async function registerPushToken(gateway: DataGateway, userId: string) {
  const messaging = getMessaging();
  if (Platform.OS === 'android' && !await ensureNotificationPermission()) return () => undefined;
  if (Platform.OS === 'ios') { const status = await requestPermission(messaging, { alert: true, badge: true, sound: true }); if (status !== AuthorizationStatus.AUTHORIZED && status !== AuthorizationStatus.PROVISIONAL) return () => undefined; }
  const token = await getToken(messaging); await save(gateway, userId, token);
  return onTokenRefresh(messaging, (next) => void save(gateway, userId, next));
}

export async function unregisterPushToken(gateway: DataGateway, userId: string) {
  const messaging = getMessaging();
  const token = await getToken(messaging).catch(() => null);
  if (token) await gateway.deleteDocument(tokenPath(userId, token));
  await deleteToken(messaging).catch(() => undefined);
}
