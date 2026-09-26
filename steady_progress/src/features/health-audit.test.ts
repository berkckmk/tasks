// Functional audit of the vital flows. Every test states the CORRECT
// behavior. Tests marked `todo` currently fail: each one is an open finding
// and should drop the marker once fixed.
import assert from 'node:assert/strict';
import test from 'node:test';
import { MemoryDataGateway } from '../core/data/memory-data-gateway.ts';
import { isCompletedToday } from '../core/data/firestore-values.ts';
import { calculateNextDueDate, calculatePreviousDueDate } from './reminders/recurrence.ts';
import { ReminderRepository } from './reminders/reminder-repository.ts';
import type { ReminderItem } from './reminders/reminder.ts';
import { TaskRepository } from './tasks/task-repository.ts';
import type { TaskItem } from './tasks/task-item.ts';
import { mergeHabitsWithLogs, type Habit, type HabitLog } from './habits/habit.ts';
import { buildTodayEntries } from './dashboard/today.ts';
import { buildWidgetSnapshot } from './widget/widget-snapshot.ts';
import { WidgetSyncCoordinator, type WidgetBridgePort } from './widget/widget-sync.ts';
import { RepositoryWidgetMutations } from './widget/repository-widget-mutations.ts';

const d = (y: number, m: number, day: number, h = 0, min = 0) => new Date(y, m - 1, day, h, min);

function reminder(p: Partial<ReminderItem>): ReminderItem {
  return {
    id: 'r1', title: 'duxet', message: '', dueAt: null, status: 'scheduled', priority: 'important',
    starred: false, earlyAlertMinutes: null, repeatRule: null, location: null, category: 'Sağlık',
    checklist: [], lastCompletedAt: null, ...p,
  };
}
function habit(p: Partial<Habit>): Habit {
  return {
    id: 'h1', name: 'Yürüyüş', category: 'health', frequencyLabel: 'Daily', streak: 0,
    isCompletedToday: false, colorValue: 0, reminderTimeLabel: null, syncEnabled: false,
    googleCalendarReminderEventId: null, lastSyncedAt: null, ...p,
  };
}
const log = (habitId: string, date: string): HabitLog => ({ id: `${habitId}_${date}`, habitId, date, completed: true, completedAt: null });

// ───────────── 1. Tekrar hesaplama ─────────────

test('1a Her ay: 31 Ocak -> 28 Şub -> 31 Mart (ay sonuna sabitlenmeli, 28e kaymamalı)', { todo: 'açık bulgu' }, () => {
  const feb = calculateNextDueDate(d(2026, 1, 31, 9), 'Her ay', d(2026, 1, 31, 10))!;
  assert.equal(feb.getDate(), 28);
  const mar = calculateNextDueDate(feb, 'Her ay', d(2026, 2, 28, 10))!;
  assert.equal(mar.getDate(), 31, `Mart ${mar.getDate()} oldu`);
});

test('1b Her ay geri alma: 31 Ocak tamamla -> geri al -> yine 31 Ocak', { todo: 'açık bulgu' }, () => {
  const next = calculateNextDueDate(d(2026, 1, 31, 9), 'Her ay', d(2026, 1, 31, 10))!;
  const back = calculatePreviousDueDate(next, 'Her ay')!;
  assert.equal(back.getDate(), 31, `geri alınca ${back.getDate()} Ocak oldu`);
});

test('1c Hafta içi: Cuma tamamlanınca Pazartesi', () => {
  const next = calculateNextDueDate(d(2026, 9, 25, 9), 'Hafta içi (Pzt-Cum)', d(2026, 9, 25, 10))!;
  assert.equal(next.getDay(), 1);
  assert.equal(next.getDate(), 28);
});

test('1d Her gün saat korunur (yaz saati geçişi dahil sistem TZ)', () => {
  const next = calculateNextDueDate(d(2026, 3, 28, 9), 'Her gün', d(2026, 3, 28, 10))!;
  assert.equal(next.getHours(), 9);
});

// ───────────── 2. Hatırlatıcılar ─────────────

test('2a Yıllık hatırlatıcı: geçen yıl bugün tamamlanan, bu yıl "bugün tamamlandı" sayılmamalı', { todo: 'açık bulgu' }, () => {
  assert.equal(isCompletedToday(d(2025, 9, 26, 9), d(2026, 9, 26, 8)), false);
});

test('2b Kaçırılan günlük ilaç: dün tamamlanmadıysa bugünün listesinde görünmeli', { todo: 'açık bulgu' }, () => {
  const now = d(2026, 9, 26, 8);
  const entries = buildTodayEntries({
    habits: [], tasks: [],
    reminders: [reminder({ dueAt: d(2026, 9, 25, 9, 20), repeatRule: 'Her gün' })],
    now,
  });
  assert.equal(entries.length, 1, 'kaçırılan günlük ilaç Bugün ekranında hiç yok');
});

test('2c Geç tamamlanan tekrarlı hatırlatıcı geri alınınca eski tarihine dönmeli', { todo: 'açık bulgu' }, async () => {
  const gw = new MemoryDataGateway('u');
  const repo = new ReminderRepository(gw, 'u');
  const id = await repo.save({ title: 'Methotrexat', message: '', dueAt: d(2026, 9, 1, 6), status: 'scheduled', repeatRule: 'Her hafta' });
  await repo.setDone(id, true, d(2026, 9, 26, 10)); // 3+ hafta geç
  await repo.setDone(id, false);
  const item = await repo.getById(id);
  assert.equal(item?.dueAt?.getDate(), 1, `geri alınca ${item?.dueAt?.toDateString()} oldu`);
});

test('2d Tekrarlamayan hatırlatıcı tamamla/geri al durumu doğru', async () => {
  const gw = new MemoryDataGateway('u');
  const repo = new ReminderRepository(gw, 'u');
  const id = await repo.save({ title: 'Fatura', message: '', dueAt: d(2026, 9, 26, 12), status: 'scheduled' });
  await repo.setDone(id, true);
  assert.equal((await repo.getById(id))?.status, 'completed');
  await repo.setDone(id, false);
  assert.equal((await repo.getById(id))?.status, 'scheduled');
});

// ───────────── 3. Görevler ─────────────

test('3b Tekrarlı görev tamamlanınca Bugün ekranında tamamlandı görünür', () => {
  const now = d(2026, 9, 26, 12);
  const task = { id: 't', title: 'Rapor', description: '', startDate: null, dueDate: d(2026, 9, 27, 18), allDay: false, priority: 'medium', status: 'todo', relatedGoalId: null, repeatRule: 'Her gün', lastCompletedAt: d(2026, 9, 26, 11) } as unknown as TaskItem;
  const entries = buildTodayEntries({ habits: [], tasks: [task], reminders: [], now });
  assert.equal(entries[0]?.done, true);
});

// ───────────── 4. Alışkanlıklar ─────────────

test('4a Günlük seri: 3 gün üst üste = 3', () => {
  const [h] = mergeHabitsWithLogs([habit({})], [log('h1', '2026-09-24'), log('h1', '2026-09-25'), log('h1', '2026-09-26')], d(2026, 9, 26, 20));
  assert.equal(h.streak, 3);
});

test('4b Hafta içi alışkanlık: Pzt sabahı, Cuma yapıldıysa seri hafta sonu yüzünden sıfırlanmamalı', { todo: 'açık bulgu' }, () => {
  const [h] = mergeHabitsWithLogs(
    [habit({ frequencyLabel: 'Weekdays' })],
    [log('h1', '2026-09-24'), log('h1', '2026-09-25')], // Per, Cum
    d(2026, 9, 28, 8), // Pzt
  );
  assert.equal(h.streak, 2, `seri ${h.streak}`);
});

test('4c Widget en iyi seri: widget sadece bugünün kayıtlarını okuyor, seri 1e düşmemeli', { todo: 'açık bulgu' }, () => {
  // widget-data-sync.tsx / background-widget-sync.ts cutoff = bugün
  const onlyToday = [log('h1', '2026-09-26')];
  const [h] = mergeHabitsWithLogs([habit({})], onlyToday, d(2026, 9, 26, 20));
  const snap = buildWidgetSnapshot({ habits: [h], tasks: [], reminders: [], now: d(2026, 9, 26, 20) });
  assert.equal(snap.bestStreak, 30, `widget best streak ${snap.bestStreak} (gerçekte 30 günlük seri)`);
});

// ───────────── 5. Widget ─────────────

test('5a Widget: sadece bugünün görevleri sayılmalı', { todo: 'açık bulgu' }, () => {
  const now = d(2026, 9, 26, 12);
  const mk = (id: string, due: Date, status = 'todo') => ({ id, title: id, description: '', startDate: null, dueDate: due, allDay: false, priority: 'medium', status, relatedGoalId: null, repeatRule: null, lastCompletedAt: null }) as unknown as TaskItem;
  const snap = buildWidgetSnapshot({
    habits: [], reminders: [], now,
    tasks: [mk('bugün', d(2026, 9, 26, 15)), mk('geçen ay', d(2026, 8, 1, 9), 'done'), mk('gelecek ay', d(2026, 10, 20, 9))],
  });
  assert.equal(snap.tasksTotal, 1, `widget tasksTotal=${snap.tasksTotal}`);
});

test('5b Widget: tekrarlı hatırlatıcı bugün tamamlanınca widgetta tamamlandı görünmeli', { todo: 'açık bulgu' }, () => {
  const now = d(2026, 9, 26, 12);
  const snap = buildWidgetSnapshot({
    habits: [], tasks: [], now,
    reminders: [reminder({ dueAt: d(2026, 9, 27, 9), repeatRule: 'Her gün', lastCompletedAt: d(2026, 9, 26, 9, 5) })],
  });
  const items = JSON.parse(snap.items);
  assert.equal(items.reminders.length, 1, 'bugün tamamlanan ilaç widgettan kayboluyor');
});

test('5c Widget kuyruğu onaylanamazsa (ack hatası) tekrarlı hatırlatıcı iki kez ilerlememeli', { todo: 'açık bulgu' }, async () => {
  const gw = new MemoryDataGateway('u');
  const repo = new ReminderRepository(gw, 'u');
  const id = await repo.save({ title: 'aubagio', message: '', dueAt: d(2026, 9, 26, 13), status: 'scheduled', repeatRule: 'Her gün' });
  const toggles = JSON.stringify([{ id, kind: 'reminder', done: true, at: d(2026, 9, 26, 13, 1).getTime() }]);
  let ackOk = false;
  const bridge: WidgetBridgePort = {
    readPendingAdds: async () => '[]',
    readPendingToggles: async () => (ackOk ? '[]' : toggles),
    acknowledgePendingAdds: async () => true,
    acknowledgePendingToggles: async () => false, // ör. uygulama arka plana atıldı / yazma başarısız
  };
  const coordinator = new WidgetSyncCoordinator(bridge, new RepositoryWidgetMutations(gw, { now: () => d(2026, 9, 26, 13, 2) }));
  await coordinator.drain('u');
  await coordinator.drain('u'); // aynı kuyruk tekrar okunur
  const item = await repo.getById(id);
  assert.equal(item?.dueAt?.getDate(), 27, `ilaç ${item?.dueAt?.toDateString()} tarihine atladı`);
});
