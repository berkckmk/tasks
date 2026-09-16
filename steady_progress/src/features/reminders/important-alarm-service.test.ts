import assert from 'node:assert/strict';
import test from 'node:test';
import { ImportantAlarmService, type AlarmLogEntry } from './important-alarm-service.ts';
import { ReminderRepository } from './reminder-repository.ts';
import { MemoryDataGateway } from '../../core/data/memory-data-gateway.ts';
import type { ReminderItem } from './reminder.ts';

test('ImportantAlarmService permission status returns expected structure', async () => {
  const status = await ImportantAlarmService.getPermissionStatus();
  assert.equal(typeof status.notifications, 'boolean');
  assert.equal(typeof status.exactAlarm, 'boolean');
  assert.equal(typeof status.fullScreenAlarm, 'boolean');
});

test('ImportantAlarmService capabilities return valid settings targets', async () => {
  const caps = await ImportantAlarmService.getCapabilities();
  assert.equal(typeof caps.notifications, 'boolean');
  assert.equal(typeof caps.exactAlarm, 'boolean');
  assert.equal(typeof caps.fullScreenAlarm, 'boolean');
  assert.equal(typeof caps.canOpenExactAlarmSettings, 'boolean');
  assert.equal(typeof caps.canOpenFullScreenSettings, 'boolean');
  assert.equal(typeof caps.canOpenNotificationSettings, 'boolean');
  assert.equal(typeof caps.canOpenBatterySettings, 'boolean');
});

test('ImportantAlarmService rejects past schedules and logs future schedules', async () => {
  ImportantAlarmService.clearLogs();

  // Past reminder: should return false immediately
  const pastResult = await ImportantAlarmService.schedule({
    id: 'past-rem-1',
    title: 'Past Alert',
    message: 'Too late',
    dueAt: new Date(Date.now() - 60_000),
    priority: 'important',
    status: 'scheduled',
    starred: false,
    earlyAlertMinutes: null,
    repeatRule: null,
    location: null,
    category: 'Hatırlatıcılarım',
    checklist: [],
  });
  assert.equal(pastResult, false);
  assert.equal(ImportantAlarmService.getLogs().length, 0);

  // Future reminder: schedules and records structured log
  const futureDue = new Date(Date.now() + 3600_000);
  const futureItem: ReminderItem = {
    id: 'future-rem-1',
    title: 'Acil İlaç Hatırlatıcısı',
    message: 'Duxet 60mg almayı unutma',
    dueAt: futureDue,
    priority: 'important',
    status: 'scheduled',
    starred: true,
    earlyAlertMinutes: null,
    repeatRule: null,
    location: null,
    category: 'Sağlık',
    checklist: [],
  };

  await ImportantAlarmService.schedule(futureItem);
  const logs = ImportantAlarmService.getLogs();
  assert.ok(logs.length >= 1);
  const latestLog = logs[0];
  assert.equal(latestLog.reminderId, 'future-rem-1');
  assert.equal(latestLog.action, 'schedule');
  assert.equal(latestLog.expectedTriggerAt, futureDue.getTime());
  assert.ok(latestLog.scheduledAt > 0);
  assert.equal(typeof latestLog.permissionState.notifications, 'boolean');
  assert.equal(typeof latestLog.permissionState.exactAlarm, 'boolean');
  assert.equal(typeof latestLog.permissionState.fullScreenAlarm, 'boolean');
});

test('ImportantAlarmService cancel logs cancellation', async () => {
  ImportantAlarmService.clearLogs();
  await ImportantAlarmService.cancel('rem-to-cancel');

  const logs = ImportantAlarmService.getLogs();
  assert.equal(logs.length, 1);
  assert.equal(logs[0].reminderId, 'rem-to-cancel');
  assert.equal(logs[0].action, 'cancel');
});

test('ImportantAlarmService complete is idempotent and synchronizes repository state', async () => {
  const gateway = new MemoryDataGateway();
  const repo = new ReminderRepository(gateway, 'user-123');

  const id = await repo.save({
    title: 'Önemli Toplantı',
    message: 'Yıllık genel kurul',
    dueAt: new Date(Date.now() + 10_000),
    status: 'scheduled',
    priority: 'important',
  });

  // First complete call
  const firstResult = await ImportantAlarmService.complete(id, repo);
  assert.equal(firstResult, true);

  let updatedItem: ReminderItem | undefined;
  repo.watch((items) => {
    updatedItem = items.find((i) => i.id === id);
  }, () => {});
  assert.ok(updatedItem);
  assert.equal(updatedItem?.status, 'completed');

  // Second complete call (idempotent verification)
  const secondResult = await ImportantAlarmService.complete(id, repo);
  assert.equal(secondResult, true);
  assert.equal(updatedItem?.status, 'completed');
});

test('ImportantAlarmService snooze updates dueAt to +10 minutes and marks status snoozed', async () => {
  const gateway = new MemoryDataGateway();
  const repo = new ReminderRepository(gateway, 'user-123');

  const originalDue = new Date(Date.now() + 60_000);
  const id = await repo.save({
    title: 'Önemli Fatura',
    message: 'Elektrik faturası son gün',
    dueAt: originalDue,
    status: 'scheduled',
    priority: 'important',
  });

  const snoozeResult = await ImportantAlarmService.snooze(id, 10, repo, originalDue);
  assert.ok(snoozeResult);
  assert.equal(snoozeResult?.id, id);

  // snoozedUntilMs must be originalDue + 10min, NOT now + 10min
  const expectedMs = originalDue.getTime() + 10 * 60_000;
  assert.ok(Math.abs(snoozeResult!.snoozedUntilMs - expectedMs) < 1000);

  let updatedItem: ReminderItem | undefined;
  repo.watch((items) => {
    updatedItem = items.find((i) => i.id === id);
  }, () => {});

  assert.ok(updatedItem);
  assert.equal(updatedItem?.status, 'snoozed');
  assert.ok(Math.abs(updatedItem!.dueAt!.getTime() - expectedMs) < 1000);

  // Title, message, and priority must be preserved — not overwritten with defaults
  assert.equal(updatedItem?.title, 'Önemli Fatura');
  assert.equal(updatedItem?.message, 'Elektrik faturası son gün');
  assert.equal(updatedItem?.priority, 'important');
});

test('ImportantAlarmService snooze fetches dueAt from repository when currentDueAt is omitted and adds +10 minutes to plan time', async () => {
  const gateway = new MemoryDataGateway();
  const repo = new ReminderRepository(gateway, 'user-123');

  const planDate = new Date('2026-09-13T15:00:00.000Z');
  const id = await repo.save({
    title: 'Toplantı',
    message: 'Proje değerlendirmesi',
    dueAt: planDate,
    status: 'scheduled',
    priority: 'important',
  });

  // Call snooze without passing currentDueAt
  const snoozeResult = await ImportantAlarmService.snooze(id, 10, repo);
  assert.ok(snoozeResult);

  const expectedMs = planDate.getTime() + 10 * 60_000;
  assert.equal(snoozeResult!.snoozedUntilMs, expectedMs);

  const updatedItem = await repo.getById(id);
  assert.ok(updatedItem);
  assert.equal(updatedItem?.status, 'snoozed');
  assert.equal(updatedItem?.dueAt?.getTime(), expectedMs);
});

test('ImportantAlarmService log storage enforces max capacity', () => {
  ImportantAlarmService.clearLogs();
  for (let i = 0; i < 150; i++) {
    ImportantAlarmService.recordLog({
      reminderId: `rem-${i}`,
      scheduledAt: i,
      expectedTriggerAt: i + 1000,
      action: 'schedule',
      permissionState: {
        notifications: true,
        exactAlarm: true,
        fullScreenAlarm: true,
        dndAccess: true,
        alarmVolume: true,
        batteryOptimizationIgnored: true,
      },
    });
  }

  const logs = ImportantAlarmService.getLogs();
  assert.equal(logs.length, 100);
  assert.equal(logs[0].reminderId, 'rem-149');
  assert.equal(logs[99].reminderId, 'rem-50');
});
