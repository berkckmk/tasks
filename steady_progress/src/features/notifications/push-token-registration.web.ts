import type { DataGateway } from '../../core/data/data-gateway';

export async function registerPushToken(
  _gateway: DataGateway,
  _userId: string,
): Promise<() => void> {
  // Web push notification integration via Service Worker / VAPID can be bound here.
  // Returns safe cleanup no-op for now.
  return () => undefined;
}

export async function unregisterPushToken(
  _gateway: DataGateway,
  _userId: string,
): Promise<void> {
  // Safe no-op on web
}
