import type { NativeModule } from 'expo';

export type ReminderPriority = 'low' | 'normal' | 'important';

export type ReminderSchedule = {
  id: string;
  timestampMs: number;
  title: string;
  message: string;
  priority: ReminderPriority;
};

export type ImportantChannelStatus = {
  channelId: string;
  created: boolean;
  importance?: number;
  sound?: string;
  audioUsage?: number;
};

export type PermissionStatus = {
  notifications: boolean;
  exactAlarm: boolean;
  fullScreenAlarm: boolean;
};

export type Capabilities = {
  notifications: boolean;
  exactAlarm: boolean;
  fullScreenAlarm: boolean;
  canOpenExactAlarmSettings: boolean;
  canOpenFullScreenSettings: boolean;
  canOpenNotificationSettings: boolean;
  canOpenBatterySettings: boolean;
};

export type PendingAlarmAction = {
  action: 'complete' | 'snooze';
  reminderId: string;
  timestampMs: number;
  snoozedUntilMs?: number;
};

export type AlarmActionEvent = {
  action: 'complete' | 'snooze';
  reminderId: string;
  timestampMs: number;
  snoozedUntilMs?: number;
};

export type AlarmTriggeredEvent = {
  reminderId: string;
  title: string;
  triggeredAt: number;
};

export type ReminderEvents = {
  onAlarmAction: (event: AlarmActionEvent) => void;
  onAlarmTriggered: (event: AlarmTriggeredEvent) => void;
};

declare class SteadyRemindersModule extends NativeModule<ReminderEvents> {
  ensureChannels(): Promise<boolean>;
  schedule(id: string, timestampMs: number, title: string, message: string, priority: ReminderPriority): Promise<boolean>;
  cancel(id: string): Promise<boolean>;
  snooze(id: string, minutes?: number): Promise<{ id: string; snoozedUntilMs: number }>;
  complete(id: string): Promise<boolean>;
  stopActiveAlarm(id?: string): Promise<boolean>;
  importantChannelStatus(): Promise<ImportantChannelStatus>;
  getPermissionStatus(): Promise<PermissionStatus>;
  getCapabilities(): Promise<Capabilities>;
  canScheduleExactAlarms(): Promise<boolean>;
  openExactAlarmSettings(): Promise<boolean>;
  openFullScreenAlarmSettings(): Promise<boolean>;
  openNotificationSettings(): Promise<boolean>;
  openBatterySettings(): Promise<boolean>;
  getPendingActions(): Promise<PendingAlarmAction[]>;
  clearPendingActions(): Promise<boolean>;
  removePendingAction(reminderId: string): Promise<boolean>;
}

function resolveNativeModule(): SteadyRemindersModule | null {
  try {
    // In React Native / Expo execution environment
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const expo = require('expo');
    if (typeof expo.requireOptionalNativeModule === 'function') {
      return expo.requireOptionalNativeModule('SteadyReminders');
    }
  } catch {
    // Running under Node test runner without React Native environment
  }
  return null;
}

export default resolveNativeModule();
