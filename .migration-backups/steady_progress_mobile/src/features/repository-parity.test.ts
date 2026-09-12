import assert from 'node:assert/strict';
import test from 'node:test';
import type {
  DataGateway,
  DocumentData,
  DocumentRow,
  QuerySpec,
  Unsubscribe,
} from '../core/data/data-gateway.ts';
import { MemoryDataGateway } from '../core/data/memory-data-gateway.ts';
import { HabitRepository } from './habits/habit-repository.ts';
import { LearningRepository } from './learning/learning-repository.ts';
import { NotificationSettingsRepository } from './notifications/notification-settings-repository.ts';
import { ProfileRepository } from './profile/profile-repository.ts';
import type { UserProfile } from './profile/user-profile.ts';
import { ReminderRepository } from './reminders/reminder-repository.ts';
import type { ReminderItem } from './reminders/reminder.ts';
import { TaskRepository } from './tasks/task-repository.ts';
import type { TaskItem } from './tasks/task-item.ts';
import { RepositoryWidgetMutations } from './widget/repository-widget-mutations.ts';
import type { PendingAdd } from './widget/widget-contract.ts';

type Operation =
  | { kind: 'call'; name: string; data: DocumentData }
  | { kind: 'add'; path: string; data: DocumentData }
  | { kind: 'set'; path: string; data: DocumentData; merge: boolean }
  | { kind: 'update'; path: string; data: DocumentData }
  | { kind: 'delete'; path: string }
  | { kind: 'delete-many'; paths: string[] };

class FakeGateway implements DataGateway {
  readonly operations: Operation[] = [];
  rows: DocumentRow[] = [];
  functionResult: DocumentData = { id: 'server-id' };
  readonly timestamp = Symbol('server-timestamp');
  readonly deleted = Symbol('delete-field');

  watchCollection(
    _path: string,
    _query: QuerySpec,
    onData: (rows: DocumentRow[]) => void,
    _onError: (error: unknown) => void,
  ): Unsubscribe {
    onData(this.rows);
    return () => undefined;
  }

  watchDocument(
    path: string,
    onData: (row: DocumentRow | null) => void,
    _onError: (error: unknown) => void,
  ): Unsubscribe {
    const id = path.slice(path.lastIndexOf('/') + 1);
    const row = this.rows.find((r) => r.id === id);
    onData(row ?? null);
    return () => undefined;
  }

  async getDocument(path: string): Promise<DocumentRow | null> {
    const id = path.slice(path.lastIndexOf('/') + 1);
    const row = this.rows.find((r) => r.id === id);
    return row ?? null;
  }

  async getCollection(_path: string, _query: QuerySpec) {
    return this.rows;
  }

  async callFunction(name: string, data: DocumentData) {
    this.operations.push({ kind: 'call', name, data });
    return this.functionResult;
  }

  async addDocument(path: string, data: DocumentData) {
    this.operations.push({ kind: 'add', path, data });
    return { id: 'new-document' };
  }

  async setDocument(path: string, data: DocumentData, options?: { merge?: boolean }) {
    this.operations.push({ kind: 'set', path, data, merge: options?.merge === true });
  }

  async updateDocument(path: string, data: DocumentData) {
    this.operations.push({ kind: 'update', path, data });
  }

  async deleteDocument(path: string) {
    this.operations.push({ kind: 'delete', path });
  }

  async deleteDocuments(paths: string[]) {
    this.operations.push({ kind: 'delete-many', paths });
  }

  serverTimestamp() {
    return this.timestamp;
  }

  deleteField() {
    return this.deleted;
  }
}

test('new tasks use the callable, preserve widget idempotency, then patch date range fields', async () => {
  const gateway = new FakeGateway();
  gateway.functionResult = { taskId: 'task-7' };
  const repository = new TaskRepository(gateway, 'user-1');
  const start = new Date('2026-09-08T08:00:00.000Z');
  const due = new Date('2026-09-09T09:00:00.000Z');

  const id = await repository.save({
    title: 'Widget task',
    description: '',
    startDate: start,
    dueDate: due,
    allDay: false,
    priority: 'high',
    status: 'todo',
    relatedGoalId: null,
    clientMutationId: 'add:42',
  });

  assert.equal(id, 'task-7');
  assert.deepEqual(gateway.operations, [
    {
      kind: 'call',
      name: 'createTask',
      data: {
        title: 'Widget task',
        description: '',
        startDate: start.toISOString(),
        dueDate: due.toISOString(),
        allDay: false,
        priority: 'high',
        relatedGoalId: null,
        clientMutationId: 'add:42',
      },
    },
    {
      kind: 'set',
      path: 'users/user-1/tasks/task-7',
      data: { startDate: start, dueDate: due, allDay: false, updatedAt: gateway.timestamp },
      merge: true,
    },
  ]);
});

test('tasks support edit and delete while preserving the complete document shape', async () => {
  const gateway = new FakeGateway();
  const repository = new TaskRepository(gateway, 'user-1');
  const start = new Date('2026-09-09T00:00:00.000Z');
  const due = new Date('2026-09-09T15:30:00.000Z');

  await repository.save({
    id: 'task-1',
    title: 'Updated task',
    description: 'Updated details',
    startDate: start,
    dueDate: due,
    allDay: false,
    priority: 'high',
    status: 'inProgress',
    relatedGoalId: 'goal-1',
  });
  await repository.delete('task-1');

  assert.deepEqual(gateway.operations, [
    {
      kind: 'set',
      path: 'users/user-1/tasks/task-1',
      data: {
        title: 'Updated task',
        description: 'Updated details',
        startDate: start,
        dueDate: due,
        allDay: false,
        priority: 'high',
        status: 'inProgress',
        relatedGoalId: 'goal-1',
        updatedAt: gateway.timestamp,
      },
      merge: true,
    },
    { kind: 'delete', path: 'users/user-1/tasks/task-1' },
  ]);
});

test('habits support editing without losing category, frequency, color or reminder', async () => {
  const gateway = new FakeGateway();
  const repository = new HabitRepository(gateway, 'user-1');

  await repository.save({
    id: 'habit-1',
    name: 'Updated walk',
    category: 'health',
    frequencyLabel: 'Weekdays',
    colorValue: 0xff9184d9,
    reminderTimeLabel: '08:30',
  });

  assert.deepEqual(gateway.operations, [
    {
      kind: 'set',
      path: 'users/user-1/habits/habit-1',
      data: {
        name: 'Updated walk',
        category: 'health',
        frequencyLabel: 'Weekdays',
        colorValue: 0xff9184d9,
        reminderTimeLabel: '08:30',
        updatedAt: gateway.timestamp,
      },
      merge: true,
    },
  ]);
});

test('habit deletion removes matching logs before deleting the visible habit', async () => {
  const gateway = new FakeGateway();
  gateway.rows = [{ id: 'log-1', data: { habitId: 'habit-1' } }];
  const repository = new HabitRepository(gateway, 'user-1');

  await repository.delete('habit-1');

  assert.deepEqual(gateway.operations, [
    { kind: 'delete-many', paths: ['users/user-1/habit_logs/log-1'] },
    { kind: 'delete', path: 'users/user-1/habits/habit-1' },
  ]);
});

test('editing a medicine reminder upgrades normal priority and resets notification state', async () => {
  const gateway = new FakeGateway();
  const repository = new ReminderRepository(gateway, 'user-1');

  await repository.save({
    id: 'reminder-1',
    title: 'Vitamin',
    message: 'Akşam al',
    dueAt: new Date('2026-09-08T18:00:00.000Z'),
    status: 'scheduled',
    priority: 'normal',
  });

  const operation = gateway.operations[0];
  assert.equal(operation.kind, 'set');
  if (operation.kind !== 'set') return;
  assert.equal(operation.data.priority, 'important');
  assert.equal(operation.data.notifiedAt, gateway.deleted);
  assert.equal(operation.merge, true);
});

test('reminder edits preserve scheduling metadata and deletion targets the same record', async () => {
  const gateway = new FakeGateway();
  const repository = new ReminderRepository(gateway, 'user-1');
  const dueAt = new Date('2026-09-10T08:30:00.000Z');
  await repository.save({
    id: 'reminder-2', title: 'Appointment', message: 'Clinic', dueAt,
    status: 'snoozed', priority: 'important', starred: true,
    earlyAlertMinutes: 30, repeatRule: 'Her hafta', location: 'Hospital',
    category: 'Sağlık', checklist: ['Bring report'],
  });
  await repository.delete('reminder-2');
  const edit = gateway.operations[0];
  assert.equal(edit.kind, 'set');
  if (edit.kind === 'set') {
    assert.equal(edit.data.dueAt, dueAt);
    assert.equal(edit.data.status, 'snoozed');
    assert.equal(edit.data.earlyAlertMinutes, 30);
    assert.deepEqual(edit.data.checklist, ['Bring report']);
    assert.equal(edit.data.notifiedAt, gateway.deleted);
  }
  assert.deepEqual(gateway.operations[1], { kind: 'delete', path: 'users/user-1/reminders/reminder-2' });
});

test('new learning items bound ratings and carry server create/update timestamps', async () => {
  const gateway = new FakeGateway();
  const repository = new LearningRepository(gateway, 'user-1');

  const id = await repository.save({
    title: 'Course',
    type: 'course',
    status: 'planned',
    rating: 12.8,
    notes: '',
    keyTakeaways: [],
  });

  assert.equal(id, 'new-document');
  const operation = gateway.operations[0];
  assert.equal(operation.kind, 'add');
  if (operation.kind !== 'add') return;
  assert.equal(operation.data.rating, 5);
  assert.equal(operation.data.createdAt, gateway.timestamp);
  assert.equal(operation.data.updatedAt, gateway.timestamp);
});

test('learning items support complete edit and delete operations', async () => {
  const gateway = new FakeGateway();
  const repository = new LearningRepository(gateway, 'user-1');

  const id = await repository.save({
    id: 'learning-1',
    title: 'Updated course',
    type: 'course',
    status: 'completed',
    rating: 4,
    notes: 'Finished',
    keyTakeaways: ['Practice'],
  });
  await repository.delete(id);

  assert.deepEqual(gateway.operations, [
    {
      kind: 'set',
      path: 'users/user-1/learning_items/learning-1',
      data: {
        title: 'Updated course',
        type: 'course',
        status: 'completed',
        rating: 4,
        notes: 'Finished',
        keyTakeaways: ['Practice'],
        updatedAt: gateway.timestamp,
      },
      merge: true,
    },
    { kind: 'delete', path: 'users/user-1/learning_items/learning-1' },
  ]);
});

test('widget reminder creation uses a deterministic document and fallback next hour', async () => {
  const gateway = new FakeGateway();
  const mutations = new RepositoryWidgetMutations(gateway, {
    now: () => new Date(2026, 8, 8, 10, 47),
  });
  const entry: PendingAdd = {
    id: 'add:42',
    kind: 'reminder',
    label: 'Call',
    startAt: 0,
    endAt: 0,
    allDay: true,
    at: 42,
  };

  const first = await mutations.createFromWidget('user-1', entry);
  const second = await mutations.createFromWidget('user-1', entry);

  assert.deepEqual(first, { itemId: 'widget_add%3A42' });
  assert.deepEqual(second, first);
  assert.equal(gateway.operations.length, 2);
  for (const operation of gateway.operations) {
    assert.equal(operation.kind, 'set');
    if (operation.kind !== 'set') continue;
    assert.equal(operation.path, 'users/user-1/reminders/widget_add%3A42');
    assert.deepEqual(operation.data.dueAt, new Date(2026, 8, 8, 11, 0));
  }
});

test('widget mutations preserve task dates, habit display time, and resolved toggle ids', async () => {
  const gateway = new FakeGateway();
  gateway.functionResult = { id: 'server-task' };
  const mutations = new RepositoryWidgetMutations(gateway, {
    formatHabitTime: () => '9:05 AM',
  });
  const taskAt = new Date(2026, 8, 8, 14, 30);

  await mutations.createFromWidget('user-1', {
    id: 'add:task', kind: 'task', label: 'Plan',
    startAt: taskAt.getTime(), endAt: 0, allDay: false, at: 1,
  });
  await mutations.createFromWidget('user-1', {
    id: 'add:habit', kind: 'habit', label: 'Walk',
    startAt: taskAt.getTime(), endAt: 0, allDay: false, at: 2,
  });
  await mutations.setDoneFromWidget(
    'user-1',
    { id: 'add:task', kind: 'task', done: true, at: 3 },
    'server-task',
  );

  const taskCall = gateway.operations[0];
  assert.equal(taskCall.kind, 'call');
  if (taskCall.kind === 'call') {
    assert.equal(taskCall.data.startDate, new Date(2026, 8, 8).toISOString());
    assert.equal(taskCall.data.dueDate, taskAt.toISOString());
    assert.equal(taskCall.data.clientMutationId, 'add:task');
  }
  const habitCall = gateway.operations[2];
  assert.equal(habitCall.kind, 'call');
  if (habitCall.kind === 'call') assert.equal(habitCall.data.reminderTimeLabel, '9:05 AM');
  const lastOp = gateway.operations.at(-1);
  assert.equal(lastOp?.kind, 'update');
  assert.equal(lastOp?.path, 'users/user-1/tasks/server-task');
  assert.equal((lastOp?.data as Record<string, unknown>).status, 'done');
  assert.equal((lastOp?.data as Record<string, unknown>).updatedAt, gateway.timestamp);
  assert.ok((lastOp?.data as Record<string, unknown>).lastCompletedAt);
});

test('synthetic gateway exercises the real task repository without Firebase access', async () => {
  const gateway = new MemoryDataGateway('preview-user');
  const repository = new TaskRepository(gateway, 'preview-user');
  let visible: TaskItem[] = [];
  const stop = repository.watch(
    (items) => { visible = items; },
    (error) => assert.fail(String(error)),
  );

  const id = await repository.save({
    title: 'Offline preview',
    description: '',
    startDate: null,
    dueDate: null,
    allDay: true,
    priority: 'medium',
    status: 'todo',
    relatedGoalId: null,
  });

  assert.equal(id, 'task-1');
  assert.equal(visible.length, 1);
  assert.equal(visible[0].title, 'Offline preview');
  await repository.setDone(id, true);
  assert.equal(visible[0].status, 'done');
  stop();
});

test('profile and notification settings watch single user document and react to updates', async () => {
  const gateway = new MemoryDataGateway('user-42');
  const profileRepo = new ProfileRepository(gateway, 'user-42');
  const notifRepo = new NotificationSettingsRepository(gateway, 'user-42');

  let currentProfile: UserProfile | null = null;
  const stopProfile = profileRepo.watch((p) => { currentProfile = p; }, (err) => assert.fail(String(err)));

  let masterNotifEnabled = false;
  const stopNotif = notifRepo.watch((s) => { masterNotifEnabled = s.masterEnabled; }, (err) => assert.fail(String(err)));

  assert.equal(currentProfile as UserProfile | null, null);
  assert.equal(masterNotifEnabled, true);

  await profileRepo.createInitialProfile({ displayName: 'Test User', email: 'test@example.com' });
  assert.equal((currentProfile as UserProfile | null)?.displayName, 'Test User');
  assert.equal((currentProfile as UserProfile | null)?.email, 'test@example.com');

  await notifRepo.save({ masterEnabled: false, disabledChannels: new Set(), taskDigestHour: 9 });
  assert.equal(masterNotifEnabled, false);

  stopProfile();
  stopNotif();
});

test('ReminderRepository.setDone advances dueAt to next occurrence for repeating reminder', async () => {
  const gateway = new MemoryDataGateway('user-rep');
  const repository = new ReminderRepository(gateway, 'user-rep');
  const initialDue = new Date(2026, 8, 11, 9, 0, 0);

  let reminders: ReminderItem[] = [];
  const stop = repository.watch((r) => { reminders = r; }, () => {});

  const id = await repository.save({
    title: 'Daily Vitamin',
    message: '',
    dueAt: initialDue,
    status: 'scheduled',
    repeatRule: 'Her gün',
  });

  assert.equal(reminders.length, 1);
  assert.equal(reminders[0].dueAt?.getDate(), 11);

  const completedAt = new Date(2026, 8, 11, 10, 0, 0);
  const res = await repository.setDone(id, true, completedAt);
  assert.equal(res.wasRepeated, true);
  assert.ok(res.nextDueAt);
  assert.equal(res.nextDueAt.getDate(), 12);
  assert.equal(res.nextDueAt.getHours(), 9);

  assert.equal(reminders[0].dueAt?.getDate(), 12);
  assert.equal(reminders[0].status, 'scheduled');
  assert.ok(reminders[0].lastCompletedAt);

  stop();
});

test('TaskRepository.setDone advances dueDate to next occurrence for repeating task', async () => {
  const gateway = new MemoryDataGateway('user-task-rep');
  const repository = new TaskRepository(gateway, 'user-task-rep');
  const initialDue = new Date(2026, 8, 11, 14, 0, 0);

  let tasks: TaskItem[] = [];
  const stop = repository.watch((t) => { tasks = t; }, () => {});

  const id = await repository.save({
    title: 'Weekly Review',
    description: '',
    startDate: null,
    dueDate: initialDue,
    allDay: false,
    priority: 'medium',
    status: 'todo',
    relatedGoalId: null,
    repeatRule: 'Her hafta',
  });

  assert.equal(tasks.length, 1);
  assert.equal(tasks[0].dueDate?.getDate(), 11);

  const res = await repository.setDone(id, true);
  assert.equal(res.wasRepeated, true);
  assert.ok(res.nextDueDate);
  assert.equal(res.nextDueDate.getDate(), 18);
  assert.equal(tasks[0].status, 'todo');
  assert.equal(tasks[0].dueDate?.getDate(), 18);

  stop();
});


