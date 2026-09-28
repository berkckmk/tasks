// Functional audit of the vital flows: each test states the correct
// behavior of a finding from the reliability review.
import assert from 'node:assert/strict';
import test from 'node:test';
import { MemoryDataGateway } from '../core/data/memory-data-gateway.ts';
import { isCompletedToday } from '../core/data/firestore-values.ts';
import { calculateNextDueDate, calculatePreviousDueDate } from './reminders/recurrence.ts';
import { ReminderRepository } from './reminders/reminder-repository.ts';
import type { ReminderItem } from './reminders/reminder.ts';
import { TaskRepository } from './tasks/task-repository.ts';
import type { TaskItem } from './tasks/task-item.ts';
import { addCalendarDays, formatLogDate, HABIT_STREAK_LOG_DAYS, mergeHabitsWithLogs, type Habit, type HabitLog } from './habits/habit.ts';
import { alarmsToCancel, planAlarms } from './reminders/alarm-plan.ts';
import { groupReminders } from './reminders/reminder-sections.ts';
import { ImportantAlarmService } from './reminders/important-alarm-service.ts';
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

test('1a Her ay: 31 Ocak -> 28 Şub -> 31 Mart (ay sonuna sabitlenmeli, 28e kaymamalı)', () => {
  const feb = calculateNextDueDate(d(2026, 1, 31, 9), 'Her ay', d(2026, 1, 31, 10), 31)!;
  assert.equal(feb.getDate(), 28);
  const mar = calculateNextDueDate(feb, 'Her ay', d(2026, 2, 28, 10), 31)!;
  assert.equal(mar.getDate(), 31, `Mart ${mar.getDate()} oldu`);
});

test('1b Her ay geri alma: 31 Ocak tamamla -> geri al -> yine 31 Ocak', () => {
  const next = calculateNextDueDate(d(2026, 1, 31, 9), 'Her ay', d(2026, 1, 31, 10), 31)!;
  const back = calculatePreviousDueDate(next, 'Her ay', 31)!;
  assert.equal(back.getDate(), 31, `geri alınca ${back.getDate()} Ocak oldu`);
});

test('1e Aylık hatırlatıcı depoda da ay sonuna sabit kalır', async () => {
  const gw = new MemoryDataGateway('u');
  const repo = new ReminderRepository(gw, 'u');
  const id = await repo.save({ title: 'Kira', message: '', dueAt: d(2026, 1, 31, 9), status: 'scheduled', repeatRule: 'Her ay' });
  await repo.setDone(id, true, d(2026, 1, 31, 10));
  assert.equal((await repo.getById(id))?.dueAt?.getDate(), 28);
  await repo.setDone(id, true, d(2026, 2, 28, 10));
  assert.equal((await repo.getById(id))?.dueAt?.getDate(), 31);
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

test('2a Yıllık hatırlatıcı: geçen yıl bugün tamamlanan, bu yıl "bugün tamamlandı" sayılmamalı', () => {
  assert.equal(isCompletedToday(d(2025, 9, 26, 9), d(2026, 9, 26, 8)), false);
});

test('2b Kaçırılan günlük ilaç: dün tamamlanmadıysa bugünün listesinde görünmeli', () => {
  const now = d(2026, 9, 26, 8);
  const entries = buildTodayEntries({
    habits: [], tasks: [],
    reminders: [reminder({ dueAt: d(2026, 9, 25, 9, 20), repeatRule: 'Her gün' })],
    now,
  });
  assert.equal(entries.length, 1, 'kaçırılan günlük ilaç Bugün ekranında hiç yok');
});

test('2c Geç tamamlanan tekrarlı hatırlatıcı geri alınınca eski tarihine dönmeli', async () => {
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

test('4b Hafta içi alışkanlık: Pzt sabahı, Cuma yapıldıysa seri hafta sonu yüzünden sıfırlanmamalı', () => {
  const [h] = mergeHabitsWithLogs(
    [habit({ frequencyLabel: 'Weekdays' })],
    [log('h1', '2026-09-24'), log('h1', '2026-09-25')], // Per, Cum
    d(2026, 9, 28, 8), // Pzt
  );
  assert.equal(h.streak, 2, `seri ${h.streak}`);
});

test('4c Widget en iyi seri: widget en az 60 günlük kayıt okur, 30 günlük seri doğru görünür', () => {
  const now = d(2026, 9, 26, 20);
  const cutoff = addCalendarDays(now, -HABIT_STREAK_LOG_DAYS);
  const logs: HabitLog[] = [];
  for (let i = 0; i < 30; i += 1) {
    const day = addCalendarDays(now, -i);
    if (day >= cutoff) logs.push(log('h1', formatLogDate(day)));
  }
  const [h] = mergeHabitsWithLogs([habit({})], logs, now);
  const snap = buildWidgetSnapshot({ habits: [h], tasks: [], reminders: [], now });
  assert.equal(snap.bestStreak, 30);
});

// ───────────── 5. Widget ─────────────

test('5a Widget: sadece bugünün görevleri sayılmalı', () => {
  const now = d(2026, 9, 26, 12);
  const mk = (id: string, due: Date, status = 'todo') => ({ id, title: id, description: '', startDate: null, dueDate: due, allDay: false, priority: 'medium', status, relatedGoalId: null, repeatRule: null, lastCompletedAt: null }) as unknown as TaskItem;
  const snap = buildWidgetSnapshot({
    habits: [], reminders: [], now,
    tasks: [mk('bugün', d(2026, 9, 26, 15)), mk('geçen ay', d(2026, 8, 1, 9), 'done'), mk('gelecek ay', d(2026, 10, 20, 9))],
  });
  assert.equal(snap.tasksTotal, 1, `widget tasksTotal=${snap.tasksTotal}`);
});

test('5b Widget: tekrarlı hatırlatıcı bugün tamamlanınca widgetta tamamlandı görünmeli', () => {
  const now = d(2026, 9, 26, 12);
  const snap = buildWidgetSnapshot({
    habits: [], tasks: [], now,
    reminders: [reminder({ dueAt: d(2026, 9, 27, 9), repeatRule: 'Her gün', lastCompletedAt: d(2026, 9, 26, 9, 5) })],
  });
  const items = JSON.parse(snap.items);
  assert.equal(items.reminders.length, 1, 'bugün tamamlanan ilaç widgettan kayboluyor');
});

test('5c Widget kuyruğu onaylanamazsa (ack hatası) tekrarlı hatırlatıcı iki kez ilerlememeli', async () => {
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

// ───────────── 6. Alarm planı ─────────────

test('6a Kaçırılan günlük ilaç depoda bugüne taşınır', async () => {
  const gw = new MemoryDataGateway('u');
  const repo = new ReminderRepository(gw, 'u');
  const id = await repo.save({ title: 'duxet', message: '', dueAt: d(2026, 9, 23, 9, 0), status: 'scheduled', repeatRule: 'Her gün' });
  const moved = await repo.rollForwardMissed([(await repo.getById(id))!], d(2026, 9, 26, 8));
  assert.deepEqual(moved, [id]);
  const item = await repo.getById(id);
  assert.equal(item?.dueAt?.getDate(), 26);
  assert.equal(item?.dueAt?.getHours(), 9);
});

test('6b Kaçırılan haftalık ilaç bir sonraki haftanın gününe taşınır, saat korunur', async () => {
  const gw = new MemoryDataGateway('u');
  const repo = new ReminderRepository(gw, 'u');
  const id = await repo.save({ title: 'Methotrexat', message: '', dueAt: d(2026, 9, 22, 6), status: 'scheduled', repeatRule: 'Her hafta' });
  await repo.rollForwardMissed([(await repo.getById(id))!], d(2026, 9, 26, 8));
  const item = await repo.getById(id);
  assert.equal(item?.dueAt?.getDate(), 29);
  assert.equal(item?.dueAt?.getHours(), 6);
});

test('6c Geçmiş saatteki tekrarlı ilaç için bir sonraki alarm kurulur, tek seferlik için kurulmaz', () => {
  const now = d(2026, 9, 26, 10);
  const plan = planAlarms([
    reminder({ id: 'daily', dueAt: d(2026, 9, 26, 9, 20), repeatRule: 'Her gün' }),
    reminder({ id: 'once', dueAt: d(2026, 9, 26, 9, 0) }),
    reminder({ id: 'future', dueAt: d(2026, 9, 26, 13) }),
    reminder({ id: 'done', dueAt: d(2026, 9, 27, 13), status: 'completed' }),
  ], now);
  assert.equal(new Date(plan.get('daily')!.timestampMs).getDate(), 27);
  assert.equal(new Date(plan.get('daily')!.timestampMs).getMinutes(), 20);
  assert.equal(plan.has('once'), false);
  assert.equal(new Date(plan.get('future')!.timestampMs).getHours(), 13);
  assert.equal(plan.has('done'), false);
});

test('6d Ertelenmiş tekrarlı ilaçın sonraki alarmı asıl saatte kurulur', () => {
  const plan = planAlarms([
    reminder({ id: 'r', dueAt: d(2026, 9, 26, 9, 10), snoozedFromDueAt: d(2026, 9, 26, 9, 0), status: 'snoozed', repeatRule: 'Her gün' }),
  ], d(2026, 9, 26, 9, 15));
  assert.equal(new Date(plan.get('r')!.timestampMs).getMinutes(), 0);
  assert.equal(new Date(plan.get('r')!.timestampMs).getDate(), 27);
});

test('6e Silinen veya tamamlanan hatırlatıcının alarmı iptal edilir, sadece geciken iptal edilmez', () => {
  const items = [
    reminder({ id: 'overdue', dueAt: d(2026, 9, 26, 9) }),
    reminder({ id: 'completed', dueAt: d(2026, 9, 26, 9), status: 'completed' }),
  ];
  assert.deepEqual(alarmsToCancel(['overdue', 'completed', 'deleted'], items).sort(), ['completed', 'deleted']);
});

test('6f Yıl sonu: 31 Aralık günlük ilaç 1 Ocak a geçer', () => {
  const next = calculateNextDueDate(d(2026, 12, 31, 9), 'Her gün', d(2026, 12, 31, 10))!;
  assert.equal(next.getFullYear(), 2027);
  assert.equal(next.getDate(), 1);
});

// ───────────── 7. Hatırlatıcı ekranı bölümleri ─────────────

test('7a Bugün tamamlanan günlük ilaç Geçmişte VE yarınki tekrarı Yaklaşanda görünür', () => {
  const now = d(2026, 9, 26, 16);
  const sections = groupReminders([
    reminder({ id: 'duxet', dueAt: d(2026, 9, 27, 9, 20), repeatRule: 'Her gün', lastCompletedAt: d(2026, 9, 26, 9, 25) }),
  ], now);
  assert.deepEqual(sections.pastItems.map((r) => r.id), ['duxet']);
  assert.equal(sections.pastItems[0].status, 'completed');
  assert.deepEqual(sections.upcomingItems.map((r) => r.id), ['duxet']);
  assert.equal(sections.upcomingItems[0].dueAt?.getDate(), 27);
});

test('7b Tek seferlik tamamlanan hatırlatıcı sadece Geçmişte', () => {
  const sections = groupReminders([
    reminder({ id: 'fatura', dueAt: d(2026, 9, 26, 12), status: 'completed', lastCompletedAt: d(2026, 9, 26, 12, 5) }),
  ], d(2026, 9, 26, 16));
  assert.equal(sections.pastItems.length, 1);
  assert.equal(sections.todayItems.length + sections.upcomingItems.length, 0);
});

test('7c Kaçırılan günlük ilaç Bugün bölümünde', () => {
  const sections = groupReminders([
    reminder({ id: 'aubagio', dueAt: d(2026, 9, 25, 13), repeatRule: 'Her gün' }),
  ], d(2026, 9, 26, 8));
  assert.deepEqual(sections.todayItems.map((r) => r.id), ['aubagio']);
});

// ───────────── 8. Erteleme ve peş peşe tamamlama ─────────────

async function dailyDuxet() {
  const gw = new MemoryDataGateway('u');
  const repo = new ReminderRepository(gw, 'u');
  const id = await repo.save({ title: 'duxet', message: '', dueAt: d(2026, 9, 28, 9, 0), status: 'scheduled', repeatRule: 'Her gün', priority: 'important' });
  return { repo, id };
}

test('8a +10dk ertelenen ilaç tamamlanınca ertesi gün asıl saatte (09:00)', async () => {
  const { repo, id } = await dailyDuxet();
  await ImportantAlarmService.snooze(id, 10, repo, (await repo.getById(id))!.dueAt);
  assert.equal((await repo.getById(id))!.dueAt?.getMinutes(), 10);
  await repo.setDone(id, true, d(2026, 9, 28, 9, 11));
  const next = (await repo.getById(id))!.dueAt!;
  assert.equal(next.getDate(), 29);
  assert.equal(next.getHours(), 9);
  assert.equal(next.getMinutes(), 0);
});

test('8b Alarm ekranından ertele + tamamla: ertesi gün asıl saatte', async () => {
  const { repo, id } = await dailyDuxet();
  await ImportantAlarmService.applyAlarmAction(repo, { action: 'snooze', reminderId: id, timestampMs: d(2026, 9, 28, 9, 1).getTime(), snoozedUntilMs: d(2026, 9, 28, 9, 10).getTime() });
  await ImportantAlarmService.applyAlarmAction(repo, { action: 'complete', reminderId: id, timestampMs: Date.now() });
  const next = (await repo.getById(id))!.dueAt!;
  assert.equal(next.getHours(), 9);
  assert.equal(next.getMinutes(), 0);
});

test('8c Ertelendikten sonra not düzenlenip kaydedilirse saat 09:10 a kaymaz', async () => {
  const { repo, id } = await dailyDuxet();
  await ImportantAlarmService.snooze(id, 10, repo, (await repo.getById(id))!.dueAt);
  const item = (await repo.getById(id))!;
  // Editor saved without touching the time -> keepSnooze.
  await repo.save({ id, title: item.title, message: 'not', dueAt: item.dueAt, status: 'snoozed', repeatRule: item.repeatRule, priority: item.priority, keepSnooze: true });
  assert.equal((await repo.getById(id))!.status, 'snoozed');
  await repo.setDone(id, true, d(2026, 9, 28, 9, 11));
  assert.equal((await repo.getById(id))!.dueAt?.getMinutes(), 0);
});

test('8d Saati bilerek değiştirilen düzenleme yeni saati kalıcı yapar', async () => {
  const { repo, id } = await dailyDuxet();
  await ImportantAlarmService.snooze(id, 10, repo, (await repo.getById(id))!.dueAt);
  const item = (await repo.getById(id))!;
  await repo.save({ id, title: item.title, message: '', dueAt: d(2026, 9, 28, 8, 30), status: 'scheduled', repeatRule: item.repeatRule, priority: item.priority });
  await repo.setDone(id, true, d(2026, 9, 28, 8, 31));
  const next = (await repo.getById(id))!.dueAt!;
  assert.equal(next.getHours(), 8);
  assert.equal(next.getMinutes(), 30);
});

test('8e Peş peşe 28-29-30-1 tamamlanınca Geçmiş te 4 ayrı satır olur', async () => {
  const { repo, id } = await dailyDuxet();
  for (let i = 0; i < 4; i += 1) await repo.setDone(id, true, d(2026, 9, 28, 10, i));
  const item = (await repo.getById(id))!;
  assert.equal(item.dueAt?.getDate(), 2); // 2 Ekim
  const sections = groupReminders([item], d(2026, 9, 28, 12));
  assert.deepEqual(sections.pastItems.map((r) => r.historyOccurrence?.getDate()), [1, 30, 29, 28]);
  assert.deepEqual(sections.upcomingItems.map((r) => r.dueAt?.getDate()), [2]);
});

test('8f Ortadaki günün (29) tiki kaldırılınca sadece 29 geri gelir, diğerleri Geçmiş te kalır', async () => {
  const { repo, id } = await dailyDuxet();
  for (let i = 0; i < 4; i += 1) await repo.setDone(id, true, d(2026, 9, 28, 10, i));
  const res = await repo.setDone(id, false, d(2026, 9, 28, 11), { occurrence: d(2026, 9, 29, 9, 0) });
  assert.equal(res.restoredDueAt?.getDate(), 29);
  const item = (await repo.getById(id))!;
  assert.equal(item.dueAt?.getDate(), 29);
  const sections = groupReminders([item], d(2026, 9, 28, 12));
  assert.deepEqual(sections.pastItems.map((r) => r.historyOccurrence?.getDate()), [1, 30, 28]);
  // 29 tekrar tamamlanınca zaten tamamlanmış 30 ve 1 atlanır.
  await repo.setDone(id, true, d(2026, 9, 28, 13));
  assert.equal((await repo.getById(id))!.dueAt?.getDate(), 2);
});

test('8g Tüm günlerin tiki tek tek kaldırılınca seri ilk güne (28) döner', async () => {
  const { repo, id } = await dailyDuxet();
  for (let i = 0; i < 4; i += 1) await repo.setDone(id, true, d(2026, 9, 28, 10, i));
  for (const day of [[10, 1], [9, 30], [9, 29], [9, 28]]) {
    await repo.setDone(id, false, d(2026, 9, 28, 11), { occurrence: d(2026, day[0], day[1], 9, 0) });
  }
  const item = (await repo.getById(id))!;
  assert.equal(item.dueAt?.getDate(), 28);
  assert.equal(item.lastCompletedAt, null);
  assert.equal(groupReminders([item], d(2026, 9, 28, 12)).pastItems.length, 0);
});

test('8h Hangi gün belirtilmeden tik kaldırılırsa en son tamamlanan geri alınır', async () => {
  const { repo, id } = await dailyDuxet();
  await repo.setDone(id, true, d(2026, 9, 28, 10));
  await repo.setDone(id, true, d(2026, 9, 28, 10, 1));
  await repo.setDone(id, false, d(2026, 9, 28, 11));
  const item = (await repo.getById(id))!;
  assert.equal(item.dueAt?.getDate(), 29);
  assert.equal(groupReminders([item], d(2026, 9, 28, 12)).pastItems.length, 1);
});

test('8i Önceden tamamlanan gün için alarm kurulmaz', () => {
  const plan = planAlarms([
    reminder({ id: 'r', dueAt: d(2026, 9, 28, 9), repeatRule: 'Her gün', completions: [{ occurrence: d(2026, 9, 29, 9), completedAt: d(2026, 9, 28, 8) }] }),
  ], d(2026, 9, 28, 10));
  assert.equal(new Date(plan.get('r')!.timestampMs).getDate(), 30);
});
