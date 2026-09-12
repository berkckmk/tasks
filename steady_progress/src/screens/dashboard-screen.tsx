import { useEffect, useMemo, useState } from 'react';
import { router, type Href } from 'expo-router';
import { ActivityIndicator, Alert, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppButton, AppCard, AppIcon, AppScreen, AppText, AppTextField, CheckCircle, EmptyState, Kicker, ListItemRow, PageHeaderGradient } from '@/components/ui';
import { useAppData } from '@/core/data/app-data';
import { buildTodayEntries, type TodayEntry } from '@/features/dashboard/today';
import { HabitRepository } from '@/features/habits/habit-repository';
import { addCalendarDays, formatLogDate, mergeHabitsWithLogs, type Habit, type HabitLog } from '@/features/habits/habit';
import { cancelReminder, ImportantAlarmService } from '@/features/reminders/reminder-scheduler';
import { ReminderRepository } from '@/features/reminders/reminder-repository';
import type { ReminderItem } from '@/features/reminders/reminder';
import { TaskRepository } from '@/features/tasks/task-repository';
import type { TaskItem } from '@/features/tasks/task-item';
import { colors, radius, spacing, typography } from '@/theme';


const kindLabels = { reminder: 'Reminder', task: 'Task', habit: 'Habit' } as const;

export function DashboardScreen() {
  const insets = useSafeAreaInsets();
  const { gateway, userId } = useAppData();
  const repositories = useMemo(() => ({
    habits: new HabitRepository(gateway, userId),
    tasks: new TaskRepository(gateway, userId),
    reminders: new ReminderRepository(gateway, userId),
  }), [gateway, userId]);

  const [habits, setHabits] = useState<Habit[]>([]);
  const [logs, setLogs] = useState<HabitLog[]>([]);
  const [tasks, setTasks] = useState<TaskItem[]>([]);
  const [reminders, setReminders] = useState<ReminderItem[]>([]);
  const [capture, setCapture] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Multi-selection state for today's planned activities
  const [isSelectionMode, setIsSelectionMode] = useState(false);
  const [selectedKeys, setSelectedKeys] = useState<Set<string>>(new Set());

  const mergedHabits = useMemo(() => mergeHabitsWithLogs(habits, logs), [habits, logs]);
  const entries = useMemo(() => buildTodayEntries({ habits: mergedHabits, tasks, reminders }), [mergedHabits, tasks, reminders]);
  const done = entries.filter((entry) => entry.done).length;

  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;
    setLoading(true);
    const onError = (reason: unknown) => {
      if (active) setError(String(reason));
      setLoading(false);
    };
    const cutoff = formatLogDate(addCalendarDays(new Date(), -60));
    let pending = 4;
    const markLoaded = () => {
      if (--pending <= 0 && active) {
        setLoading(false);
      }
    };
    const stops = [
      repositories.habits.watch((data) => { setHabits(data); markLoaded(); }, onError),
      repositories.habits.watchRecentLogs((data) => { setLogs(data); markLoaded(); }, onError, cutoff),
      repositories.tasks.watch((data) => { setTasks(data); markLoaded(); }, onError),
      repositories.reminders.watch((data) => { setReminders(data); markLoaded(); }, onError),
    ];
    return () => {
      active = false;
      stops.forEach((stop) => stop());
    };
  }, [repositories]);

  async function quickCapture() {
    const title = capture.trim();
    if (!title || saving) return;
    setSaving(true);
    try {
      await repositories.reminders.save({ title, message: '', dueAt: null, status: 'scheduled' });
      setCapture('');
      setError(null);
    } catch (reason) {
      setError(String(reason));
    } finally {
      setSaving(false);
    }
  }

  async function setDone(entry: TodayEntry) {
    try {
      if (entry.kind === 'habit') await repositories.habits.setCompletionToday(entry.id, !entry.done);
      if (entry.kind === 'task') await repositories.tasks.setDone(entry.id, !entry.done);
      if (entry.kind === 'reminder') {
        const res = await repositories.reminders.setDone(entry.id, !entry.done);
        if (res.wasRepeated && res.nextDueAt) {
          const reminder = reminders.find((r) => r.id === entry.id);
          if (reminder) {
            await ImportantAlarmService.schedule({
              id: reminder.id,
              timestampMs: res.nextDueAt.getTime(),
              title: reminder.title,
              message: reminder.message,
              priority: reminder.priority,
            });
          }
        } else if (!entry.done) {
          await ImportantAlarmService.complete(entry.id);
        }
      }
    } catch (reason) {
      setError(String(reason));
    }
  }


  function startSelection(key: string) {
    setIsSelectionMode(true);
    setSelectedKeys(new Set([key]));
  }

  function toggleSelect(key: string) {
    setSelectedKeys((prev) => {
      const next = new Set(prev);
      if (next.has(key)) {
        next.delete(key);
        if (next.size === 0) setIsSelectionMode(false);
      } else {
        next.add(key);
      }
      return next;
    });
  }

  function selectAll() {
    if (selectedKeys.size === entries.length) {
      setSelectedKeys(new Set());
      setIsSelectionMode(false);
    } else {
      setSelectedKeys(new Set(entries.map((e) => `${e.kind}:${e.id}`)));
    }
  }

  function deleteSelected() {
    if (selectedKeys.size === 0) return;
    const count = selectedKeys.size;
    Alert.alert(
      `Seçilen ${count} planlanmış etkinlik silinsin mi?`,
      'Bu işlem geri alınamaz.',
      [
        { text: 'İptal', style: 'cancel' },
        {
          text: 'Sil',
          style: 'destructive',
          onPress: async () => {
            try {
              await Promise.all(
                [...selectedKeys].map(async (key) => {
                  const [kind, id] = key.split(':');
                  if (kind === 'reminder') {
                    await cancelReminder(id);
                    await repositories.reminders.delete(id);
                  } else if (kind === 'task') {
                    await repositories.tasks.delete(id);
                  } else if (kind === 'habit') {
                    await repositories.habits.delete(id);
                  }
                }),
              );
              setSelectedKeys(new Set());
              setIsSelectionMode(false);
            } catch (reason) {
              Alert.alert('Hata', `Etkinlikler silinemedi: ${reason}`);
            }
          },
        },
      ],
    );
  }

  return (
    <View style={{ flex: 1 }}>
      <AppScreen tab="today" contentStyle={{ paddingBottom: insets.bottom + (isSelectionMode ? 80 : spacing.xxl) }}>
        <PageHeaderGradient tab="today">
          <View style={{ gap: spacing.xs }}>
            <Kicker>{new Intl.DateTimeFormat('tr-TR', { weekday: 'short', day: 'numeric', month: 'long' }).format(new Date())}</Kicker>
            <AppText variant="h2">Today</AppText>
            <AppText tone="muted">{entries.length ? `${done} / ${entries.length} tamamlandı` : 'Bugünün ortak akışı'}</AppText>
          </View>
        </PageHeaderGradient>

        {!isSelectionMode ? (
          <AppCard style={{ padding: spacing.md, gap: spacing.sm }}>
            <Kicker>Quick capture</Kicker>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm }}>
              <View style={{ flex: 1 }}>
                <AppTextField
                  placeholder="Bana şunu hatırlat…"
                  value={capture}
                  onChangeText={setCapture}
                  returnKeyType="done"
                  onSubmitEditing={() => void quickCapture()}
                />
              </View>
              <AppButton
                label={saving ? '…' : 'Kaydet'}
                size="md"
                variant="secondary"
                loading={saving}
                disabled={!capture.trim()}
                onPress={() => void quickCapture()}
              />
            </View>
          </AppCard>
        ) : null}

        {error ? <AppText accessibilityRole="alert" tone="error">{error}</AppText> : null}

        {loading ? (
          <View style={{ paddingVertical: spacing.xxl, alignItems: 'center', justifyContent: 'center' }}>
            <ActivityIndicator size="large" color={colors.tabToday} />
          </View>
        ) : entries.length === 0 ? (
          <EmptyState title="Bugün planlanmış bir şey yok" message="Tarihli bir task, reminder veya bugüne planlı habit burada görünür." />
        ) : (
          <View style={{ gap: spacing.sm }}>
            {entries.map((entry, index) => {
              const key = `${entry.kind}:${entry.id}`;
              const isSelected = selectedKeys.has(key);
              return (
                <TodayCard
                  key={key}
                  entry={entry}
                  next={index === 0 && !entry.done && Boolean(entry.time)}
                  isSelected={isSelected}
                  isSelectionMode={isSelectionMode}
                  onDone={() => void setDone(entry)}
                  onPress={isSelectionMode ? () => toggleSelect(key) : undefined}
                  onLongPress={isSelectionMode ? () => toggleSelect(key) : () => startSelection(key)}
                />
              );
            })}
          </View>
        )}
      </AppScreen>

      {isSelectionMode ? (
        <View
          style={{
            position: 'absolute',
            bottom: insets.bottom + spacing.sm,
            left: spacing.screenH,
            right: spacing.screenH,
            backgroundColor: colors.surface,
            borderColor: colors.tabToday,
            borderWidth: 1,
            borderRadius: radius.md,
            paddingHorizontal: spacing.md,
            paddingVertical: spacing.sm,
            zIndex: 99,
          }}
        >
          <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', width: '100%' }}>
            <AppText variant="title" tone="accent">{selectedKeys.size} seçildi</AppText>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.xs }}>
              <AppButton
                label={selectedKeys.size === entries.length ? 'Bırak' : 'Tümünü seç'}
                variant="text"
                size="sm"
                onPress={selectAll}
              />
              <AppButton
                label={`Sil (${selectedKeys.size})`}
                variant="destructive"
                size="sm"
                onPress={deleteSelected}
              />
              <AppButton
                label="Vazgeç"
                variant="text"
                size="sm"
                onPress={() => { setIsSelectionMode(false); setSelectedKeys(new Set()); }}
              />
            </View>
          </View>
        </View>
      ) : null}
    </View>
  );
}

function TodayCard({
  entry,
  next,
  isSelected,
  isSelectionMode,
  onDone,
  onPress,
  onLongPress,
}: {
  entry: TodayEntry;
  next: boolean;
  isSelected: boolean;
  isSelectionMode: boolean;
  onDone: () => void;
  onPress?: () => void;
  onLongPress?: () => void;
}) {
  const route = `/${entry.kind === 'task' ? 'tasks' : entry.kind === 'habit' ? 'habits' : 'reminders'}/${entry.id}/edit` as Href;
  const timeStr = entry.time
    ? new Intl.DateTimeFormat('tr-TR', { hour: '2-digit', minute: '2-digit' }).format(entry.time)
    : 'Gün içinde';
  const meta = `${next ? 'Sıradaki · ' : ''}${kindLabels[entry.kind]}${entry.time ? ` · ${timeStr}` : ''}`;

  return (
    <ListItemRow
      title={entry.title}
      subtitle={meta}
      note={entry.note || null}
      completed={entry.done}
      isSelected={isSelected}
      onPress={onPress ?? (() => router.push(route))}
      onLongPress={onLongPress}
      leading={
        isSelectionMode ? (
          <AppIcon
            name={isSelected ? 'checkCircle' : 'circle'}
            filled={isSelected}
            size={20}
            tone={isSelected ? 'accent' : 'muted'}
          />
        ) : (
          <CheckCircle
            checked={entry.done}
            accessibilityLabel={entry.title}
            color={colors.tabToday}
            onToggle={onDone}
          />
        )
      }
      trailing={
        entry.time ? (
          <Text style={{ ...typography.meta, color: colors.muted }}>{timeStr}</Text>
        ) : null
      }
    />
  );
}
