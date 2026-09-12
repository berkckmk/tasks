import { PermissionsAndroid, Platform } from 'react-native';
import {
  ImportantAlarmService,
  type ImportantChannelStatus,
  type PermissionStatus,
  type Capabilities,
  type ReminderSchedule,
} from './important-alarm-service.ts';

export type { ImportantChannelStatus, PermissionStatus, Capabilities, ReminderSchedule };

export async function prepareReminderChannels(): Promise<boolean> {
  return ImportantAlarmService.prepareChannels();
}

export async function scheduleReminder(reminder: ReminderSchedule): Promise<boolean> {
  if (!await ensureNotificationPermission()) return false;
  return ImportantAlarmService.schedule(reminder);
}

export async function ensureNotificationPermission(): Promise<boolean> {
  if (Platform.OS !== 'android' || Number(Platform.Version) < 33) return true;
  const permission = PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS;
  if (await PermissionsAndroid.check(permission)) return true;
  return (await PermissionsAndroid.request(permission)) === PermissionsAndroid.RESULTS.GRANTED;
}

export async function cancelReminder(id: string): Promise<boolean> {
  return ImportantAlarmService.cancel(id);
}

export async function readImportantChannelStatus(): Promise<ImportantChannelStatus | null> {
  return ImportantAlarmService.readImportantChannelStatus();
}

export async function canScheduleExactAlarms(): Promise<boolean> {
  const permissions = await ImportantAlarmService.getPermissionStatus();
  return permissions.exactAlarm;
}

export async function openExactAlarmSettings(): Promise<boolean> {
  return ImportantAlarmService.openExactAlarmSettings();
}

export async function openFullScreenAlarmSettings(): Promise<boolean> {
  return ImportantAlarmService.openFullScreenAlarmSettings();
}

export async function openBatteryOptimizationSettings(): Promise<boolean> {
  return ImportantAlarmService.openBatteryOptimizationSettings();
}

export { ImportantAlarmService };
