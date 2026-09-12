import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import DateTimePicker from '@expo/ui/community/datetime-picker';
import { useRouter, usePathname } from 'expo-router';
import { Alert, Pressable, Text, View } from 'react-native';
import {
  AppButton,
  AppCard,
  AppIcon,
  AppText,
  AppTextField,
  CheckCircle,
  EmptyState,
  Kicker,
  ListEditorSheet,
  ListScreenShell,
  ListItemRow,
} from '@/components/ui';
import { useAppData } from '@/core/data/app-data';
import { HabitRepository } from '@/features/habits/habit-repository';
import {
  addCalendarDays,
  formatHabitTime,
  formatLogDate,
  habitCategories,
  habitFrequencies,
  mergeHabitsWithLogs,
  parseHabitTime,
  type Habit,
  type HabitCategory,
  type HabitLog,
} from '@/features/habits/habit';
import { colors, radius, spacing, typography } from '@/theme';
import { canCreateAtLimit, resolvePlan } from '@/features/subscription/plans';

const defaultHabitColor = 0xff86e6b0;
const categoryLabels: Record<HabitCategory, string> = {
  morning: 'Morning',
  evening: 'Evening',
  health: 'Health',
  work: 'Work',
};
const habitColors = [
  { value: 0xff86e6b0, label: 'Yeşil', color: colors.tabHabits },
  { value: 0xff86dbff, label: 'Mavi', color: colors.tabMore },
  { value: 0xffffb986, label: 'Şeftali', color: colors.tabToday },
  { value: 0xffff86ec, label: 'Pembe', color: colors.tabTasks },
  { value: 0xff9e86ff, label: 'Mor', color: colors.tabReminders },
] as const;

export function HabitsScreen({ initialEditId, onBack }: { initialEditId?: string; onBack?: () => void } = {}) {
  const router = useRouter();
  const pathname = usePathname();
  const isStackRoute = pathname === '/habits' || (pathname.endsWith('/habits') && !pathname.includes('/main'));
  const { gateway, userId } = useAppData();
  const repository = useMemo(() => new HabitRepository(gateway, userId), [gateway, userId]);
  const [habits, setHabits] = useState<Habit[]>([]);
  const [logs, setLogs] = useState<HabitLog[]>([]);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [name, setName] = useState('');
  const [category, setCategory] = useState<HabitCategory>('morning');
  const [frequency, setFrequency] = useState<string>('Daily');
  const [colorValue, setColorValue] = useState(defaultHabitColor);
  const [reminderTimeLabel, setReminderTimeLabel] = useState<string | null>(null);
  const [timePickerOpen, setTimePickerOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [nameError, setNameError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [historyHabitId, setHistoryHabitId] = useState<string | null>(null);
  const handledInitialId = useRef<string | null>(null);
  const isSavingRef = useRef(false);
  const clientMutationIdRef = useRef('');
  const initialSnapshotRef = useRef<{
    name: string;
    category: HabitCategory;
    frequency: string;
    colorValue: number;
    reminderTimeLabel: string | null;
  } | null>(null);

  const merged = useMemo(() => mergeHabitsWithLogs(habits, logs), [habits, logs]);

  // Multi-selection state — matching Flutter's HabitsScreen
  const [isSelectionMode, setIsSelectionMode] = useState(false);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());

  function startSelection(id: string) {
    setIsSelectionMode(true);
    setSelectedIds(new Set([id]));
  }

  function toggleSelect(id: string) {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
        if (next.size === 0) setIsSelectionMode(false);
      } else {
        next.add(id);
      }
      return next;
    });
  }

  function selectAll() {
    if (selectedIds.size === merged.length) {
      setSelectedIds(new Set());
      setIsSelectionMode(false);
    } else {
      setSelectedIds(new Set(merged.map((h) => h.id)));
    }
  }

  function deleteSelected() {
    if (selectedIds.size === 0) return;
    const count = selectedIds.size;
    Alert.alert(
      `Seçilen ${count} alışkanlık silinsin mi?`,
      'Bu işlem geri alınamaz.',
      [
        { text: 'İptal', style: 'cancel' },
        {
          text: 'Sil',
          style: 'destructive',
          onPress: async () => {
            try {
              await Promise.all([...selectedIds].map((id) => repository.delete(id)));
              setSelectedIds(new Set());
              setIsSelectionMode(false);
            } catch (reason) {
              Alert.alert('Hata', `Alışkanlıklar silinemedi: ${reason}`);
            }
          },
        },
      ],
    );
  }

  useEffect(() => {
    const onError = (reason: unknown) => setError(String(reason));
    const stopHabits = repository.watch(setHabits, onError);
    const cutoff = formatLogDate(addCalendarDays(new Date(), -60));
    const stopLogs = repository.watchRecentLogs(setLogs, onError, cutoff);
    return () => {
      stopHabits();
      stopLogs();
    };
  }, [repository]);

  useEffect(() => {
    if (!initialEditId || handledInitialId.current === initialEditId) return;
    const habit = habits.find((item) => item.id === initialEditId);
    if (!habit) return;
    handledInitialId.current = initialEditId;
    openEdit(habit);
  }, [initialEditId, habits]);

  function resetForm() {
    setEditingId(null);
    setName('');
    setCategory('morning');
    setFrequency('Daily');
    setColorValue(defaultHabitColor);
    setReminderTimeLabel(null);
    setTimePickerOpen(false);
    setError(null);
    setNameError(null);
    isSavingRef.current = false;
    setSaving(false);
    initialSnapshotRef.current = null;
  }

  function openCreate() {
    const plan = resolvePlan(null);
    if (!canCreateAtLimit(plan.maxActiveHabits, habits.length)) {
      Alert.alert('Habit limiti doldu', `${plan.name} planı en fazla ${plan.maxActiveHabits} aktif habit içerir. Growth planında sınır yoktur.`);
      return;
    }
    resetForm();
    clientMutationIdRef.current = `habit_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
    setSheetOpen(true);
  }

  function openEdit(habit: Habit) {
    setEditingId(habit.id);
    setName(habit.name);
    setCategory(habit.category);
    setFrequency(habit.frequencyLabel);
    setColorValue(habit.colorValue);
    setReminderTimeLabel(habit.reminderTimeLabel);
    setTimePickerOpen(false);
    setError(null);
    setNameError(null);
    clientMutationIdRef.current = `habit_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
    initialSnapshotRef.current = {
      name: habit.name,
      category: habit.category,
      frequency: habit.frequencyLabel,
      colorValue: habit.colorValue,
      reminderTimeLabel: habit.reminderTimeLabel,
    };
    isSavingRef.current = false;
    setSaving(false);
    setSheetOpen(true);
  }

  function close() {
    setSheetOpen(false);
    resetForm();
    setSaving(false);
  }

  const isDirty = useMemo(() => {
    if (!sheetOpen) return false;
    if (editingId) {
      if (!initialSnapshotRef.current) return false;
      return (
        name !== initialSnapshotRef.current.name ||
        category !== initialSnapshotRef.current.category ||
        frequency !== initialSnapshotRef.current.frequency ||
        colorValue !== initialSnapshotRef.current.colorValue ||
        reminderTimeLabel !== initialSnapshotRef.current.reminderTimeLabel
      );
    }
    return (
      name.trim().length > 0 ||
      category !== 'morning' ||
      frequency !== 'Daily' ||
      colorValue !== defaultHabitColor ||
      reminderTimeLabel !== null
    );
  }, [sheetOpen, editingId, name, category, frequency, colorValue, reminderTimeLabel]);

  async function save() {
    if (isSavingRef.current || saving) return;
    const trimmed = name.trim();
    if (!trimmed) {
      setNameError('Alışkanlık adı gerekli.');
      return;
    }

    isSavingRef.current = true;
    setSaving(true);
    setError(null);
    try {
      const existing = editingId ? habits.find((habit) => habit.id === editingId) : null;
      if (editingId && !existing) throw new Error('Bu alışkanlık artık mevcut değil.');
      await repository.save({
        id: existing?.id,
        name: trimmed,
        category,
        frequencyLabel: frequency,
        colorValue,
        reminderTimeLabel,
        clientMutationId: clientMutationIdRef.current,
      });
      close();
    } catch (reason) {
      setError(String(reason));
      isSavingRef.current = false;
    } finally {
      setSaving(false);
    }
  }

  async function remove() {
    if (!editingId) return;
    setSaving(true);
    try {
      await repository.delete(editingId);
      close();
    } catch (reason) {
      setError(String(reason));
    } finally {
      setSaving(false);
    }
  }

  function confirmRemove() {
    Alert.alert(
      'Alışkanlık silinsin mi?',
      'Tamamlanma geçmişi de silinecektir. Bu işlem geri alınamaz.',
      [
        { text: 'İptal', style: 'cancel' },
        { text: 'Sil', style: 'destructive', onPress: () => void remove() },
      ],
    );
  }

  return (
    <>
      <ListScreenShell
        title={isStackRoute ? 'Alışkanlıklar' : 'Habits'}
        subtitle="Düzenli tekrarlarını ve serilerini takip et."
        onBack={onBack ?? (isStackRoute ? () => router.back() : undefined)}
        hideFab={isStackRoute}
        onAdd={isSelectionMode ? () => {} : openCreate}
        addLabel="Alışkanlık ekle"
        selectionBar={isSelectionMode ? (
          <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', width: '100%' }}>
            <AppText variant="title" tone="accent">{selectedIds.size} seçildi</AppText>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.xs }}>
              <AppButton
                label={selectedIds.size === merged.length ? 'Bırak' : 'Tümünü seç'}
                variant="text"
                size="sm"
                onPress={selectAll}
              />
              <AppButton
                label={`Sil (${selectedIds.size})`}
                variant="destructive"
                size="sm"
                onPress={deleteSelected}
              />
              <AppButton
                label="Vazgeç"
                variant="text"
                size="sm"
                onPress={() => { setIsSelectionMode(false); setSelectedIds(new Set()); }}
              />
            </View>
          </View>
        ) : undefined}
      >
        {isStackRoute ? (
          <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: spacing.sm }}>
            <AppText variant="h3">Alışkanlıklar</AppText>
            <AppButton
              label="+ Yeni Alışkanlık"
              size="sm"
              color={colors.tabHabits}
              onPress={openCreate}
            />
          </View>
        ) : null}
        {merged.length === 0 ? (
          <EmptyState title="Henüz alışkanlık yok" message="İlk alışkanlığını sağ alttaki + ile ekleyebilirsin." />
        ) : (
          <View style={{ gap: spacing.sm }}>
            {merged.map((habit) => {
              const isSelected = selectedIds.has(habit.id);
              const metaParts = [
                categoryLabels[habit.category],
                habit.frequencyLabel,
                habit.reminderTimeLabel,
              ].filter(Boolean).join(' · ');

              return (
                <ListItemRow
                  key={habit.id}
                  title={habit.name}
                  subtitle={metaParts}
                  completed={habit.isCompletedToday}
                  isSelected={isSelected}
                  onPress={isSelectionMode ? () => toggleSelect(habit.id) : () => openEdit(habit)}
                  onLongPress={isSelectionMode ? () => toggleSelect(habit.id) : () => startSelection(habit.id)}
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
                        checked={habit.isCompletedToday}
                        accessibilityLabel={habit.name}
                        color={colors.tabHabits}
                        onToggle={() => void repository.setCompletionToday(habit.id, !habit.isCompletedToday)}
                      />
                    )
                  }
                  trailing={
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
                      {habit.streak > 0 ? (
                        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 2, paddingHorizontal: 6, paddingVertical: 2, borderRadius: radius.sm, backgroundColor: colors.surfaceMuted }}>
                          <AppIcon name="flame" filled size={12} color={colors.tabToday} />
                          <Text style={{ ...typography.metaSmall, color: colors.text }}>{habit.streak}g</Text>
                        </View>
                      ) : null}
                      {!isSelectionMode ? (
                        <Pressable
                          hitSlop={8}
                          onPress={(e) => {
                            e.stopPropagation?.();
                            setHistoryHabitId((current) => current === habit.id ? null : habit.id);
                          }}
                          style={{ padding: 4 }}
                        >
                          <AppIcon name={historyHabitId === habit.id ? 'caretUp' : 'chartLine'} size={15} tone="muted" />
                        </Pressable>
                      ) : null}
                    </View>
                  }
                >
                  {historyHabitId === habit.id ? <HabitHistory habit={habit} logs={logs} /> : null}
                </ListItemRow>
              );
            })}
          </View>
        )}
      </ListScreenShell>
      <ListEditorSheet
        presented={sheetOpen}
        title={editingId ? 'Alışkanlığı düzenle' : 'Alışkanlık ekle'}
        accentColor={colors.tabHabits}
        isDirty={isDirty}
        error={error}
        saving={saving}
        onDismiss={close}
        onSave={() => void save()}
        deleteLabel={editingId ? 'Alışkanlığı sil' : undefined}
        onDelete={editingId ? confirmRemove : undefined}
      >
        <AppTextField
          autoFocus
          label="Alışkanlık adı"
          placeholder="Alışkanlık adı"
          value={name}
          error={nameError}
          focusedColor={colors.tabHabits}
          onChangeText={(text) => {
            setName(text);
            if (nameError) setNameError(null);
          }}
          returnKeyType="done"
          onSubmitEditing={() => void save()}
        />
        <ChoiceGroup label="Kategori">
          {habitCategories.map((value) => (
            <AppButton
              key={value}
              label={categoryLabels[value]}
              size="sm"
              color={colors.tabHabits}
              selected={category === value}
              variant={category === value ? 'primary' : 'text'}
              onPress={() => setCategory(value)}
            />
          ))}
        </ChoiceGroup>
        <ChoiceGroup label="Sıklık">
          {habitFrequencies.map((value) => (
            <AppButton
              key={value}
              label={value}
              size="sm"
              color={colors.tabHabits}
              selected={frequency === value}
              variant={frequency === value ? 'primary' : 'text'}
              onPress={() => setFrequency(value)}
            />
          ))}
        </ChoiceGroup>
        <ChoiceGroup label="Renk">
          {habitColors.map((option) => (
            <AppButton
              key={option.value}
              label={option.label}
              size="sm"
              color={colors.tabHabits}
              selected={colorValue === option.value}
              variant={colorValue === option.value ? 'primary' : 'text'}
              icon={
                <View
                  style={{
                    width: spacing.md,
                    height: spacing.md,
                    borderRadius: radius.pill,
                    backgroundColor: option.color,
                    ...(colorValue === option.value ? { borderWidth: 2, borderColor: colors.text } : null),
                  }}
                />
              }
              onPress={() => setColorValue(option.value)}
            />
          ))}
        </ChoiceGroup>
        <View style={{ gap: spacing.sm }}>
          <Kicker>Hatırlatma saati</Kicker>
          <AppButton
            label={reminderTimeLabel ? `Hatırlatıcı · ${reminderTimeLabel}` : 'Saat seç (isteğe bağlı)'}
            variant="secondary"
            color={colors.tabHabits}
            selected={Boolean(reminderTimeLabel)}
            icon={<AppIcon name="clock" size={16} tone="accent" />}
            onPress={() => setTimePickerOpen(true)}
          />
          {reminderTimeLabel ? (
            <AppButton
              label="Hatırlatma saatini kaldır"
              variant="text"
              size="sm"
              onPress={() => setReminderTimeLabel(null)}
            />
          ) : null}
        </View>
      </ListEditorSheet>
      {timePickerOpen ? (
        <DateTimePicker
          value={parseHabitTime(reminderTimeLabel) ?? new Date()}
          mode="time"
          accentColor={colors.tabHabits}
          themeVariant="light"
          positiveButton={{ label: 'Ayarla' }}
          negativeButton={{ label: 'İptal' }}
          onValueChange={(_event, value) => {
            setReminderTimeLabel(formatHabitTime(value));
            setTimePickerOpen(false);
          }}
          onDismiss={() => setTimePickerOpen(false)}
        />
      ) : null}
    </>
  );
}

function HabitHistory({ habit, logs }: { habit: Habit; logs: HabitLog[] }) {
  const completed = logs
    .filter((log) => log.habitId === habit.id && log.completed)
    .sort((left, right) => right.date.localeCompare(left.date));
  const recentDates = completed.slice(0, 14);
  return (
    <View style={{ gap: spacing.xs }}>
      <Kicker>Son 60 gün</Kicker>
      <AppText tone="muted">{completed.length} tamamlama · Güncel seri {habit.streak} gün</AppText>
      {recentDates.length === 0 ? (
        <AppText tone="muted">Henüz tamamlanma kaydı yok.</AppText>
      ) : recentDates.map((log) => (
        <AppText key={log.id} tone="muted">✓ {formatHistoryDate(log.date)}</AppText>
      ))}
      {completed.length > recentDates.length ? (
        <AppText tone="muted">+{completed.length - recentDates.length} eski kayıt</AppText>
      ) : null}
    </View>
  );
}

function formatHistoryDate(value: string) {
  const [year, month, day] = value.split('-').map(Number);
  if (!year || !month || !day) return value;
  return new Intl.DateTimeFormat('tr-TR', { day: 'numeric', month: 'long', weekday: 'short' })
    .format(new Date(year, month - 1, day));
}

function ChoiceGroup({ label, children }: { label: string; children: ReactNode }) {
  return (
    <View style={{ gap: spacing.sm }}>
      <Kicker>{label}</Kicker>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm }}>{children}</View>
    </View>
  );
}
