import SteadyReminders, {
  type AlarmActionEvent,
  type AlarmTriggeredEvent,
  type Capabilities,
  type ImportantChannelStatus,
  type PendingAlarmAction,
  type PermissionStatus,
  type ReminderPriority,
  type ReminderSchedule,
} from '../../../modules/steady-reminders/src/SteadyRemindersModule.ts';
import type { ReminderItem } from './reminder.ts';
import type { ReminderRepository } from './reminder-repository.ts';

export type {
  AlarmActionEvent,
  AlarmTriggeredEvent,
  Capabilities,
  ImportantChannelStatus,
  PendingAlarmAction,
  PermissionStatus,
  ReminderPriority,
  ReminderSchedule,
};

export type AlarmLogEntry = {
  reminderId: string;
  scheduledAt: number;
  expectedTriggerAt: number;
  actualTriggerAt?: number;
  action: 'schedule' | 'cancel' | 'snooze' | 'complete' | 'trigger';
  permissionState: PermissionStatus;
};

const MAX_LOGS = 100;
const inMemoryLogs: AlarmLogEntry[] = [];

function isAndroidPlatform(): boolean {
  try {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const rn = require('react-native');
    return rn.Platform?.OS === 'android';
  } catch {
    return false;
  }
}

export class ImportantAlarmService {
  /**
   * Dedicated channel status and channel creation.
   */
  static async prepareChannels(): Promise<boolean> {
    if (!SteadyReminders) return false;
    return SteadyReminders.ensureChannels();
  }

  static async readImportantChannelStatus(): Promise<ImportantChannelStatus | null> {
    if (!SteadyReminders) return null;
    return SteadyReminders.importantChannelStatus();
  }

  /**
   * Runtime permissions check for notifications, exact alarms, and full-screen intents.
   */
  static async getPermissionStatus(): Promise<PermissionStatus> {
    if (!isAndroidPlatform() || !SteadyReminders) {
      return {
        notifications: true,
        exactAlarm: true,
        fullScreenAlarm: true,
        dndAccess: true,
        alarmVolume: true,
        batteryOptimizationIgnored: true,
      };
    }
    return SteadyReminders.getPermissionStatus();
  }

  /**
   * Full capability status including deep link availability for system settings.
   */
  static async getCapabilities(): Promise<Capabilities> {
    if (!isAndroidPlatform() || !SteadyReminders) {
      return {
        notifications: true,
        exactAlarm: true,
        fullScreenAlarm: true,
        canOpenExactAlarmSettings: false,
        canOpenFullScreenSettings: false,
        canOpenNotificationSettings: false,
        canOpenBatterySettings: false,
      };
    }
    return SteadyReminders.getCapabilities();
  }

  /**
   * Schedule an exact alarm for IMPORTANT reminders, or standard notification for normal ones.
   */
  static async schedule(item: ReminderSchedule | ReminderItem): Promise<boolean> {
    const timestampMs = 'timestampMs' in item
      ? item.timestampMs
      : (item.dueAt ? item.dueAt.getTime() : 0);

    if (timestampMs <= Date.now()) return false;

    const id = item.id;
    const title = item.title;
    const message = item.message;
    const priority = item.priority;

    const permissions = await this.getPermissionStatus();

    // If important and notifications are disabled, record log and report false
    if (priority === 'important' && !permissions.notifications) {
      this.recordLog({
        reminderId: id,
        scheduledAt: Date.now(),
        expectedTriggerAt: timestampMs,
        action: 'schedule',
        permissionState: permissions,
      });
      return false;
    }

    if (!SteadyReminders) {
      this.recordLog({
        reminderId: id,
        scheduledAt: Date.now(),
        expectedTriggerAt: timestampMs,
        action: 'schedule',
        permissionState: permissions,
      });
      return true;
    }

    const scheduled = await SteadyReminders.schedule(
      id,
      timestampMs,
      title,
      message,
      priority,
    );

    this.recordLog({
      reminderId: id,
      scheduledAt: Date.now(),
      expectedTriggerAt: timestampMs,
      action: 'schedule',
      permissionState: permissions,
    });

    return scheduled;
  }

  /**
   * Cancel an alarm and stop any active alarm playback / notification session.
   */
  static async cancel(id: string): Promise<boolean> {
    const permissions = await this.getPermissionStatus();
    let cancelled = true;
    if (SteadyReminders) {
      cancelled = await SteadyReminders.cancel(id);
    }

    this.recordLog({
      reminderId: id,
      scheduledAt: Date.now(),
      expectedTriggerAt: 0,
      action: 'cancel',
      permissionState: permissions,
    });

    return cancelled;
  }

  /**
   * Snooze an alarm by 10 minutes (or custom minutes).
   * Stops active sound/vibration, registers new exact alarm, and updates repository if provided.
   */
  static async snooze(
    id: string,
    minutes: number = 10,
    repository?: ReminderRepository,
    currentDueAt?: Date | null,
  ): Promise<{ id: string; snoozedUntilMs: number } | null> {
    const permissions = await this.getPermissionStatus();
    let resolvedDueAt = currentDueAt;
    if (!resolvedDueAt && repository) {
      try {
        const item = await repository.getById(id);
        resolvedDueAt = item?.dueAt ?? null;
      } catch {
        // Fallback to null
      }
    }
    const baseTime = resolvedDueAt ? resolvedDueAt.getTime() : Date.now();
    const snoozedUntilMs = baseTime + minutes * 60_000;

    let result = { id, snoozedUntilMs };
    if (SteadyReminders) {
      result = await SteadyReminders.snooze(id, minutes, baseTime);
    }

    if (repository) {
      const snoozedDate = new Date(result.snoozedUntilMs);
      await repository.snoozeTo(id, snoozedDate);
    }

    this.recordLog({
      reminderId: id,
      scheduledAt: Date.now(),
      expectedTriggerAt: result.snoozedUntilMs,
      action: 'snooze',
      permissionState: permissions,
    });

    return result;
  }

  /**
   * Mark an alarm completed.
   * Stops active sound/vibration, removes notification/pending alarm, and marks completed in repository.
   * Idempotent: safe to invoke repeatedly.
   */
  static async complete(id: string, repository?: ReminderRepository): Promise<boolean> {
    if (SteadyReminders) {
      await SteadyReminders.complete(id);
    }

    if (repository) {
      const res = await repository.setDone(id, true);
      if (res.wasRepeated && res.nextDueAt) {
        await this.schedule({
          id,
          timestampMs: res.nextDueAt.getTime(),
          title: 'Hatırlatıcı',
          message: '',
          priority: 'important',
        });
      }
    }

    const permissions = await this.getPermissionStatus();
    this.recordLog({
      reminderId: id,
      scheduledAt: Date.now(),
      expectedTriggerAt: 0,
      action: 'complete',
      permissionState: permissions,
    });


    return true;
  }

  /**
   * Stop currently ringing alarm without modifying data state.
   */
  static async stopActiveAlarm(id?: string): Promise<boolean> {
    if (!SteadyReminders) return false;
    return SteadyReminders.stopActiveAlarm(id);
  }

  /**
   * Settings navigations.
   */
  static async openExactAlarmSettings(): Promise<boolean> {
    return SteadyReminders?.openExactAlarmSettings() ?? false;
  }

  static async openFullScreenAlarmSettings(): Promise<boolean> {
    return SteadyReminders?.openFullScreenAlarmSettings() ?? false;
  }

  static async openNotificationSettings(): Promise<boolean> {
    return SteadyReminders?.openNotificationSettings() ?? false;
  }

  static async openDndSettings(): Promise<boolean> {
    return SteadyReminders?.openDndSettings() ?? false;
  }

  static async openBatteryOptimizationSettings(): Promise<boolean> {
    return SteadyReminders?.openBatterySettings() ?? false;
  }

  /**
   * Drain any pending alarm actions recorded while app was closed or backgrounded.
   */
  static async syncPendingActions(repository: ReminderRepository): Promise<number> {
    if (!SteadyReminders) return 0;
    let pending: PendingAlarmAction[] = [];
    try {
      pending = await SteadyReminders.getPendingActions();
    } catch {
      return 0;
    }

    if (!pending || pending.length === 0) return 0;

    let processedCount = 0;
    for (const item of pending) {
      try {
        if (item.action === 'complete') {
          const res = await repository.setDone(item.reminderId, true);
          if (res.wasRepeated && res.nextDueAt) {
            await this.schedule({
              id: item.reminderId,
              timestampMs: res.nextDueAt.getTime(),
              title: res.title || 'Hatırlatıcı',
              message: '',
              priority: 'important',
            });
          }
          processedCount++;
        } else if (item.action === 'snooze') {

          const snoozedMs = item.snoozedUntilMs ?? (Date.now() + 10 * 60_000);
          await repository.snoozeTo(item.reminderId, new Date(snoozedMs));
          processedCount++;
        }
        await SteadyReminders.removePendingAction(item.reminderId);
      } catch (err) {
        androidLog(`Failed to process pending alarm action: ${err}`);
      }
    }

    return processedCount;
  }

  /**
   * Event subscriptions for real-time alarm actions (snooze / complete) from native UI.
   */
  static subscribeToActions(listener: (event: AlarmActionEvent) => void): () => void {
    if (!SteadyReminders) return () => {};
    const subscription = SteadyReminders.addListener('onAlarmAction', listener);
    return () => {
      subscription.remove();
    };
  }

  /**
   * Event subscriptions for real-time alarm triggers.
   */
  static subscribeToTriggered(listener: (event: AlarmTriggeredEvent) => void): () => void {
    if (!SteadyReminders) return () => {};
    const subscription = SteadyReminders.addListener('onAlarmTriggered', (event) => {
      this.recordLog({
        reminderId: event.reminderId,
        scheduledAt: 0,
        expectedTriggerAt: event.triggeredAt,
        actualTriggerAt: event.triggeredAt,
        action: 'trigger',
        permissionState: {
          notifications: true,
          exactAlarm: true,
          fullScreenAlarm: true,
          dndAccess: true,
          alarmVolume: true,
          batteryOptimizationIgnored: true,
        },
      });
      listener(event);
    });
    return () => {
      subscription.remove();
    };
  }

  /**
   * Diagnostic and reliability logging.
   */
  static recordLog(entry: AlarmLogEntry): void {
    inMemoryLogs.unshift(entry);
    if (inMemoryLogs.length > MAX_LOGS) {
      inMemoryLogs.length = MAX_LOGS;
    }
  }

  static getLogs(): AlarmLogEntry[] {
    return [...inMemoryLogs];
  }

  static clearLogs(): void {
    inMemoryLogs.length = 0;
  }
}

function androidLog(msg: string) {
  if (__DEV__) {
    console.warn(`[ImportantAlarmService] ${msg}`);
  }
}
