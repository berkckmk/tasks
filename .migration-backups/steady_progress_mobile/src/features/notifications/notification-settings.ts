export const notificationChannels = [
  { key: 'notifyHabitReminders', label: 'Habit hatırlatmaları', description: 'Her alışkanlık için ayarlanan saatte.' },
  { key: 'notifyTaskDigest', label: 'Günlük task özeti', description: 'Bugün süresi dolan taskların tek özeti.' },
  { key: 'notifyReminderAlerts', label: 'Reminder uyarıları', description: 'Ayarladığın reminder zamanı geldiğinde.' },
] as const;
export type NotificationChannelKey = typeof notificationChannels[number]['key'];
export type NotificationSettings = { masterEnabled: boolean; disabledChannels: Set<NotificationChannelKey>; taskDigestHour: number };
export const defaultNotificationSettings: NotificationSettings = { masterEnabled: true, disabledChannels: new Set(), taskDigestHour: 8 };

export function notificationSettingsFromPreferences(raw: unknown): NotificationSettings {
  const prefs = raw && typeof raw === 'object' && !Array.isArray(raw) ? raw as Record<string, unknown> : {};
  const hour = typeof prefs.taskDigestHour === 'number' && Number.isInteger(prefs.taskDigestHour) && prefs.taskDigestHour >= 0 && prefs.taskDigestHour <= 23 ? prefs.taskDigestHour : 8;
  return { masterEnabled: prefs.notificationsEnabled !== false, disabledChannels: new Set(notificationChannels.filter((channel) => prefs[channel.key] === false).map((channel) => channel.key)), taskDigestHour: hour };
}
export function settingsToPreferences(settings: NotificationSettings, existing: Record<string, unknown> = {}) {
  return { ...existing, notificationsEnabled: settings.masterEnabled, ...Object.fromEntries(notificationChannels.map((channel) => [channel.key, !settings.disabledChannels.has(channel.key)])), taskDigestHour: settings.taskDigestHour };
}
export function withNotificationChannel(settings: NotificationSettings, key: NotificationChannelKey, enabled: boolean): NotificationSettings { const disabledChannels = new Set(settings.disabledChannels); if (enabled) disabledChannels.delete(key); else disabledChannels.add(key); return { ...settings, disabledChannels }; }
