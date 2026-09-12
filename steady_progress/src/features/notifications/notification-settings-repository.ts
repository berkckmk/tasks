import type { DataGateway, Unsubscribe } from '../../core/data/data-gateway.ts';
import { notificationSettingsFromPreferences, settingsToPreferences, type NotificationSettings } from './notification-settings.ts';

export class NotificationSettingsRepository {
  private preferences: Record<string, unknown> = {};
  private readonly gateway: DataGateway;
  private readonly userId: string;
  constructor(gateway: DataGateway, userId: string) { this.gateway = gateway; this.userId = userId; }
  watch(onData: (settings: NotificationSettings) => void, onError: (error: unknown) => void): Unsubscribe {
    return this.gateway.watchDocument(`users/${this.userId}`, (row) => { const data = row?.data ?? {}; this.preferences = data.appPreferences && typeof data.appPreferences === 'object' && !Array.isArray(data.appPreferences) ? data.appPreferences as Record<string, unknown> : {}; onData(notificationSettingsFromPreferences(this.preferences)); }, onError);
  }
  save(settings: NotificationSettings) { this.preferences = settingsToPreferences(settings, this.preferences); return this.gateway.setDocument(`users/${this.userId}`, { appPreferences: this.preferences }, { merge: true }); }
}
