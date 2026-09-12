import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import DateTimePicker from '@expo/ui/community/datetime-picker';
import { Alert, Text, View } from 'react-native';
import { AppButton, AppIcon, AppText, AppTextField, CheckCircle, CollapsibleHistorySection, EmptyState, Kicker, ListEditorSheet, ListScreenShell, ListItemRow, SectionHeader } from '@/components/ui';
import { useAppData } from '@/core/data/app-data';
import { TaskRepository } from '@/features/tasks/task-repository';
import { GoalRepository } from '@/features/goals/goal-repository';
import type { Goal } from '@/features/goals/goal';
import { taskPriorities, taskStatuses, type TaskItem, type TaskPriority, type TaskStatus } from '@/features/tasks/task-item';
import { getRecurrenceDayBadge, repeatRules } from '@/features/reminders/recurrence';
import { isCompletedToday } from '@/core/data/firestore-values';
import { colors, spacing, typography } from '@/theme';
import { canCreateAtLimit, resolvePlan } from '@/features/subscription/plans';

type StatusFilter = 'all' | TaskStatus;
type SortMode = 'newest' | 'due';
const priorityLabels: Record<TaskPriority, string> = { low: 'Düşük', medium: 'Orta', high: 'Yüksek' };
const statusLabels: Record<TaskStatus, string> = { todo: 'Yapılacak', inProgress: 'Devam ediyor', done: 'Tamamlandı' };
function day(date: Date) { return new Date(date.getFullYear(), date.getMonth(), date.getDate()); }
function dateLabel(date: Date | null) { return date ? new Intl.DateTimeFormat(undefined, { year: 'numeric', month: 'short', day: 'numeric' }).format(date) : 'Tarih yok'; }
function timeLabel(date: Date | null) { return date ? `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}` : 'Saat seç'; }

function normalizePickerDate(d: Date): Date {
  return new Date(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
}

function mergeDateAndTime(datePart: Date, timePart: Date): Date {
  return new Date(
    datePart.getFullYear(),
    datePart.getMonth(),
    datePart.getDate(),
    timePart.getHours(),
    timePart.getMinutes(),
    0,
    0,
  );
}

export function TasksScreen({ initialEditId, onBack }: { initialEditId?: string; onBack?: () => void } = {}) {
  const { gateway, userId } = useAppData();
  const repository = useMemo(() => new TaskRepository(gateway, userId), [gateway, userId]);
  const goalRepository = useMemo(() => new GoalRepository(gateway, userId), [gateway, userId]);
  const [tasks, setTasks] = useState<TaskItem[]>([]);
  const [goals, setGoals] = useState<Goal[]>([]);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [startDate, setStartDate] = useState<Date | null>(null);
  const [dueDate, setDueDate] = useState<Date | null>(null);
  const [allDay, setAllDay] = useState(true);
  const [priority, setPriority] = useState<TaskPriority>('medium');
  const [status, setStatus] = useState<TaskStatus>('todo');
  const [repeatRule, setRepeatRule] = useState<string>('Tekrarlama');
  const [relatedGoalId, setRelatedGoalId] = useState<string | null>(null);
  const [picker, setPicker] = useState<'start' | 'due' | 'time' | null>(null);
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<StatusFilter>('all');
  const [sort, setSort] = useState<SortMode>('newest');
  const [error, setError] = useState<string | null>(null);
  const [titleError, setTitleError] = useState<string | null>(null);
  const [dateError, setDateError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const handledInitialId = useRef<string | null>(null);
  const isSavingRef = useRef(false);
  const clientMutationIdRef = useRef('');
  const initialSnapshotRef = useRef<{
    title: string;
    description: string;
    allDay: boolean;
    priority: TaskPriority;
    status: TaskStatus;
    repeatRule: string;
    relatedGoalId: string | null;
  } | null>(null);


  // Multi-selection state — matching Flutter's TasksScreen
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

  function selectAllVisible() {
    if (selectedIds.size === visible.length) {
      setSelectedIds(new Set());
      setIsSelectionMode(false);
    } else {
      setSelectedIds(new Set(visible.map((t) => t.id)));
    }
  }

  function deleteSelected() {
    if (selectedIds.size === 0) return;
    const count = selectedIds.size;
    Alert.alert(
      `Seçilen ${count} görev silinsin mi?`,
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
              Alert.alert('Hata', `Görevler silinemedi: ${reason}`);
            }
          },
        },
      ],
    );
  }

  useEffect(() => repository.watch(setTasks, (reason) => setError(String(reason))), [repository]);
  useEffect(() => goalRepository.watch(setGoals, (reason) => setError(String(reason))), [goalRepository]);
  useEffect(() => {
    if (!initialEditId || handledInitialId.current === initialEditId) return;
    const task = tasks.find((item) => item.id === initialEditId);
    if (!task) return;
    handledInitialId.current = initialEditId;
    if (task.status === 'done') {
      setHistoryOpen(true);
    }
    openEdit(task);
  }, [initialEditId, tasks]);

  function isTaskCompletedToday(task: TaskItem) {
    return isCompletedToday(task.lastCompletedAt);
  }

  function isTaskDone(task: TaskItem) {
    return task.status === 'done' || isTaskCompletedToday(task);
  }

  const visible = useMemo(() => tasks.filter((task) => {
    const needle = query.trim().toLocaleLowerCase('tr-TR');
    const isDone = isTaskDone(task);
    const matchesFilter =
      filter === 'all'
        ? true
        : filter === 'done'
          ? isDone
          : !isDone && (filter === 'todo' ? task.status === 'todo' : task.status === filter);

    return matchesFilter && (!needle || `${task.title} ${task.description}`.toLocaleLowerCase('tr-TR').includes(needle));
  }).sort((a, b) => sort === 'due' ? (a.dueDate?.getTime() ?? Number.MAX_SAFE_INTEGER) - (b.dueDate?.getTime() ?? Number.MAX_SAFE_INTEGER) : 0), [tasks, query, filter, sort]);

  const [historyOpen, setHistoryOpen] = useState(false);

  const { todayTasks, upcomingTasks, pastTasks } = useMemo(() => {
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const endOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999).getTime();

    const todayList: TaskItem[] = [];
    const upcomingList: TaskItem[] = [];
    const pastList: TaskItem[] = [];

    for (const task of visible) {
      const wasCompletedToday = isTaskCompletedToday(task);
      const isExplicitlyDone = task.status === 'done';

      // Any explicitly completed task goes to Geçmiş
      if (isExplicitlyDone) {
        pastList.push(task);
        continue;
      }

      // Any repeating task ticked today MUST fall into Geçmiş
      if (wasCompletedToday) {
        pastList.push({
          ...task,
          status: 'done',
          dueDate: task.lastCompletedAt ?? task.dueDate,
        });
      }

      // Zamansız (all day) görevler tiklenmedikçe geçmişe düşmez, bugün başlığında görünür
      if (task.allDay) {
        if (task.dueDate && task.dueDate.getTime() > endOfToday) {
          if (task.startDate && task.startDate.getTime() <= endOfToday) {
            todayList.push(task);
          } else {
            upcomingList.push(task);
          }
        } else {
          todayList.push(task);
        }
        continue;
      }

      if (!task.dueDate) {
        if (!wasCompletedToday) todayList.push(task);
        continue;
      }

      const dueTime = task.dueDate.getTime();
      if (dueTime < startOfToday) {
        if (!wasCompletedToday) pastList.push(task);
      } else if (dueTime <= endOfToday) {
        todayList.push(task);
      } else {
        upcomingList.push(task);
      }
    }

    return {
      todayTasks: todayList,
      upcomingTasks: upcomingList,
      pastTasks: pastList,
    };
  }, [visible]);

  function resetForm() {
    setEditingId(null);
    setTitle('');
    setDescription('');
    setStartDate(day(new Date()));
    setDueDate(new Date());
    setAllDay(true);
    setPriority('medium');
    setStatus('todo');
    setRepeatRule('Tekrarlama');
    setRelatedGoalId(null);
    setPicker(null);
    setError(null);
    setTitleError(null);
    setDateError(null);
    isSavingRef.current = false;
    setSaving(false);
    initialSnapshotRef.current = null;
  }

  function openCreate() {
    const plan = resolvePlan(null);
    const activeCount = tasks.filter((task) => task.status !== 'done').length;
    if (!canCreateAtLimit(plan.maxActiveTasks, activeCount)) {
      Alert.alert('Task limiti doldu', `${plan.name} planı en fazla ${plan.maxActiveTasks} aktif task içerir. Growth planında sınır yoktur.`);
      return;
    }
    resetForm();
    clientMutationIdRef.current = `task_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
    setSheetOpen(true);
  }

  function openEdit(task: TaskItem) {
    setEditingId(task.id);
    setTitle(task.title);
    setDescription(task.description);
    setStartDate(task.startDate ?? task.dueDate);
    setDueDate(task.dueDate);
    setAllDay(task.allDay);
    setPriority(task.priority);
    setStatus(task.status);
    setRepeatRule(task.repeatRule ?? 'Tekrarlama');
    setRelatedGoalId(task.relatedGoalId);
    setPicker(null);
    setError(null);
    setTitleError(null);
    setDateError(null);
    clientMutationIdRef.current = `task_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
    initialSnapshotRef.current = {
      title: task.title,
      description: task.description,
      allDay: task.allDay,
      priority: task.priority,
      status: task.status,
      repeatRule: task.repeatRule ?? 'Tekrarlama',
      relatedGoalId: task.relatedGoalId,
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
        title !== initialSnapshotRef.current.title ||
        description !== initialSnapshotRef.current.description ||
        allDay !== initialSnapshotRef.current.allDay ||
        priority !== initialSnapshotRef.current.priority ||
        status !== initialSnapshotRef.current.status ||
        repeatRule !== initialSnapshotRef.current.repeatRule ||
        relatedGoalId !== initialSnapshotRef.current.relatedGoalId
      );
    }
    return (
      title.trim().length > 0 ||
      description.trim().length > 0 ||
      !allDay ||
      priority !== 'medium' ||
      status !== 'todo' ||
      repeatRule !== 'Tekrarlama' ||
      relatedGoalId !== null
    );
  }, [sheetOpen, editingId, title, description, allDay, priority, status, repeatRule, relatedGoalId]);

  async function save() {
    if (isSavingRef.current || saving) return;
    const trimmed = title.trim();
    if (!trimmed) {
      setTitleError('Görev adı gerekli.');
      return;
    }
    if (startDate && dueDate && day(startDate).getTime() > day(dueDate).getTime()) {
      setDateError('Başlangıç tarihi bitiş tarihinden sonra olamaz.');
      return;
    }

    isSavingRef.current = true;
    setSaving(true);
    setError(null);
    try {
      const existing = editingId ? tasks.find((task) => task.id === editingId) : null;
      if (editingId && !existing) throw new Error('Bu görev artık mevcut değil.');
      await repository.save({
        id: existing?.id,
        title: trimmed,
        description: description.trim(),
        startDate,
        dueDate,
        allDay,
        priority,
        status,
        repeatRule: repeatRule === 'Tekrarlama' ? null : repeatRule,
        relatedGoalId,
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
    Alert.alert('Görev silinsin mi?', 'Bu işlem geri alınamaz.', [
      { text: 'İptal', style: 'cancel' },
      { text: 'Sil', style: 'destructive', onPress: () => void remove() },
    ]);
  }

  function renderTaskRow(task: TaskItem, inHistorySection = false) {
    const isSelected = selectedIds.has(task.id);
    const isDone = inHistorySection ? (task.status === 'done' || isTaskCompletedToday(task)) : false;
    const displayDate = isDone && task.lastCompletedAt ? task.lastCompletedAt : task.dueDate;
    const recurrenceDayBadge = getRecurrenceDayBadge(task.repeatRule, displayDate);
    const dateText = task.startDate && displayDate && day(task.startDate).getTime() !== day(displayDate).getTime()
      ? `${dateLabel(task.startDate)} → ${dateLabel(displayDate)}`
      : dateLabel(displayDate);
    const metaParts = [
      priorityLabels[task.priority],
      statusLabels[task.status],
      task.repeatRule && task.repeatRule !== 'Tekrarlama' ? task.repeatRule : null,
      recurrenceDayBadge,
      dateText,
      !task.allDay && displayDate ? timeLabel(displayDate) : 'Tüm gün',
      task.relatedGoalId ? `Goal: ${goals.find((g) => g.id === task.relatedGoalId)?.title ?? task.relatedGoalId}` : null,
    ].filter(Boolean).join(' · ');

    return (
      <ListItemRow
        key={inHistorySection ? `${task.id}_history` : task.id}
        title={task.title}
        subtitle={metaParts}
        note={task.description || null}
        completed={isDone}
        isSelected={isSelected}
        onPress={isSelectionMode ? () => toggleSelect(task.id) : () => openEdit(task)}
        onLongPress={isSelectionMode ? () => toggleSelect(task.id) : () => startSelection(task.id)}
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
              checked={isDone}
              accessibilityLabel={task.title}
              color={colors.tabTasks}
              onToggle={() => void repository.setDone(task.id, !isDone)}
            />
          )
        }
        badges={
          task.repeatRule && task.repeatRule !== 'Tekrarlama' ? (
            <AppIcon name="arrowsClockwise" size={13} color={colors.tabTasks} />
          ) : null
        }
        trailing={
          !task.allDay && displayDate ? (
            <Text style={{ ...typography.meta, color: colors.muted }}>{timeLabel(displayDate)}</Text>
          ) : null
        }
      />
    );
  }

  return (
    <>
      <ListScreenShell
        title="Tasks"
        subtitle="Zaman ve odak gerektiren işlerini listele."
        onAdd={isSelectionMode ? () => {} : openCreate}
        addLabel="Görev ekle"
        onBack={onBack}
        selectionBar={isSelectionMode ? (
          <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', width: '100%' }}>
            <AppText variant="title" tone="accent">{selectedIds.size} seçildi</AppText>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.xs }}>
              <AppButton
                label={selectedIds.size === visible.length ? 'Tümünü kaldır' : 'Tümünü seç'}
                variant="text"
                size="sm"
                color={colors.tabTasks}
                onPress={selectAllVisible}
              />
              <AppButton
                label={`Sil (${selectedIds.size})`}
                variant="text"
                size="sm"
                color={colors.tabTasks}
                onPress={deleteSelected}
              />
              <AppButton
                label="İptal"
                variant="text"
                size="sm"
                color={colors.tabTasks}
                onPress={() => { setIsSelectionMode(false); setSelectedIds(new Set()); }}
              />
            </View>
          </View>
        ) : undefined}
        controls={
          <View style={{ gap: spacing.sm }}>
            <AppTextField
              label="Ara"
              placeholder="Görev ara"
              value={query}
              onChangeText={setQuery}
              focusedColor={colors.tabTasks}
            />
            <ChoiceGroup label="Durum">
              {(['all', ...taskStatuses] as StatusFilter[]).map((value) => (
                <AppButton
                  key={value}
                  label={value === 'all' ? 'Tümü' : statusLabels[value]}
                  size="sm"
                  color={colors.tabTasks}
                  selected={filter === value}
                  variant={filter === value ? 'primary' : 'text'}
                  onPress={() => setFilter(value)}
                />
              ))}
            </ChoiceGroup>
            <ChoiceGroup label="Sıralama">
              <AppButton
                label="Eklenme"
                size="sm"
                color={colors.tabTasks}
                selected={sort === 'newest'}
                variant={sort === 'newest' ? 'primary' : 'text'}
                onPress={() => setSort('newest')}
              />
              <AppButton
                label="Tarih"
                size="sm"
                color={colors.tabTasks}
                selected={sort === 'due'}
                variant={sort === 'due' ? 'primary' : 'text'}
                onPress={() => setSort('due')}
              />
            </ChoiceGroup>
          </View>
        }
      >
        {visible.length === 0 ? (
          <EmptyState
            title="Henüz görev yok"
            message="İlk görevini sağ alttaki + butonuna dokunarak ekleyebilirsin."
          />
        ) : (
          <View style={{ gap: spacing.sm }}>
            <SectionHeader title="Bugün" count={todayTasks.length} color={colors.tabTasks} />
            {todayTasks.length === 0 ? (
              <AppText variant="bodySmall" tone="muted" style={{ paddingVertical: spacing.xs, paddingHorizontal: spacing.xs }}>
                Bugün için planlanan görev yok.
              </AppText>
            ) : (
              todayTasks.map((t) => renderTaskRow(t, false))
            )}

            {upcomingTasks.length > 0 ? (
              <>
                <SectionHeader title="Yaklaşan" count={upcomingTasks.length} color={colors.tabTasks} />
                {upcomingTasks.map((t) => renderTaskRow(t, false))}
              </>
            ) : null}

            <CollapsibleHistorySection
              count={pastTasks.length}
              isExpanded={historyOpen}
              onToggle={() => setHistoryOpen((prev) => !prev)}
              color={colors.tabTasks}
              emptyLabel="Geçmiş görev bulunmuyor."
            >
              {pastTasks.map((t) => renderTaskRow(t, true))}
            </CollapsibleHistorySection>
          </View>
        )}
      </ListScreenShell>
      <ListEditorSheet
        presented={sheetOpen}
        title={editingId ? 'Görevi düzenle' : 'Görev ekle'}
        accentColor={colors.tabTasks}
        isDirty={isDirty}
        error={error}
        saving={saving}
        onDismiss={close}
        onSave={() => void save()}
        deleteLabel={editingId ? 'Görevi sil' : undefined}
        onDelete={editingId ? confirmRemove : undefined}
      >
        <AppTextField
          autoFocus
          label="Görev adı"
          placeholder="Görev adı"
          value={title}
          error={titleError}
          focusedColor={colors.tabTasks}
          onChangeText={(text) => {
            setTitle(text);
            if (titleError) setTitleError(null);
          }}
          returnKeyType="next"
        />
        <AppTextField
          label="Açıklama (isteğe bağlı)"
          placeholder="Açıklama"
          value={description}
          focusedColor={colors.tabTasks}
          onChangeText={setDescription}
          multiline
          numberOfLines={3}
        />
        <ChoiceGroup label="Tarih">
          <AppButton
            label={`Başlangıç · ${dateLabel(startDate)}`}
            variant="secondary"
            color={colors.tabTasks}
            selected={picker === 'start'}
            icon={<AppIcon name="calendarBlank" size={16} tone="accent" />}
            onPress={() => setPicker('start')}
          />
          <AppButton
            label={`Bitiş · ${dateLabel(dueDate)}`}
            variant="secondary"
            color={colors.tabTasks}
            selected={picker === 'due'}
            icon={<AppIcon name="calendarBlank" size={16} tone="accent" />}
            onPress={() => setPicker('due')}
          />
        </ChoiceGroup>
        {dateError ? (
          <AppText tone="error" variant="caption">
            {dateError}
          </AppText>
        ) : null}
        <ChoiceGroup label="Zaman">
          <AppButton
            label="Tüm gün"
            size="sm"
            color={colors.tabTasks}
            selected={allDay}
            variant={allDay ? 'primary' : 'text'}
            onPress={() => setAllDay(true)}
          />
          <AppButton
            label="Saatli"
            size="sm"
            color={colors.tabTasks}
            selected={!allDay}
            variant={!allDay ? 'primary' : 'text'}
            onPress={() => setAllDay(false)}
          />
          {!allDay ? (
            <AppButton
              label={timeLabel(dueDate)}
              size="sm"
              color={colors.tabTasks}
              selected={picker === 'time'}
              variant="secondary"
              icon={<AppIcon name="clock" size={16} tone="accent" />}
              onPress={() => setPicker('time')}
            />
          ) : null}
        </ChoiceGroup>
        <ChoiceGroup label="Öncelik">
          {taskPriorities.map((value) => (
            <AppButton
              key={value}
              label={priorityLabels[value]}
              size="sm"
              color={colors.tabTasks}
              selected={priority === value}
              variant={priority === value ? 'primary' : 'text'}
              onPress={() => setPriority(value)}
            />
          ))}
        </ChoiceGroup>
        <ChoiceGroup label="Durum">
          {taskStatuses.map((value) => (
            <AppButton
              key={value}
              label={statusLabels[value]}
              size="sm"
              color={colors.tabTasks}
              selected={status === value}
              variant={status === value ? 'primary' : 'text'}
              onPress={() => setStatus(value)}
            />
          ))}
        </ChoiceGroup>
        <ChoiceGroup label="Tekrarlama">
          {repeatRules.map((value) => (
            <AppButton
              key={value}
              label={value}
              size="sm"
              color={colors.tabTasks}
              selected={repeatRule === value}
              variant={repeatRule === value ? 'primary' : 'text'}
              onPress={() => setRepeatRule(value)}
            />
          ))}
        </ChoiceGroup>

        <ChoiceGroup label="Goal">
          <AppButton
            label="Bağlantı yok"
            size="sm"
            color={colors.tabTasks}
            selected={relatedGoalId === null}
            variant={relatedGoalId === null ? 'primary' : 'text'}
            onPress={() => setRelatedGoalId(null)}
          />
          {goals.map((goal) => (
            <AppButton
              key={goal.id}
              label={goal.title}
              size="sm"
              color={colors.tabTasks}
              selected={relatedGoalId === goal.id}
              variant={relatedGoalId === goal.id ? 'primary' : 'text'}
              onPress={() => setRelatedGoalId(goal.id)}
            />
          ))}
        </ChoiceGroup>
      </ListEditorSheet>
      {picker ? (
        <DateTimePicker
          value={picker === 'start' ? (startDate ?? new Date()) : (dueDate ?? new Date())}
          mode={picker === 'time' ? 'time' : 'date'}
          accentColor={colors.tabTasks}
          themeVariant="light"
          positiveButton={{ label: 'Ayarla' }}
          negativeButton={{ label: 'İptal' }}
          onValueChange={(_event, value) => {
            if (picker === 'start') {
              setStartDate(day(normalizePickerDate(value)));
              if (dateError) setDateError(null);
            } else if (picker === 'due') {
              const normalized = normalizePickerDate(value);
              setDueDate(allDay ? day(normalized) : mergeDateAndTime(normalized, dueDate ?? new Date()));
              if (dateError) setDateError(null);
            } else {
              setDueDate(mergeDateAndTime(dueDate ?? new Date(), value));
            }
            setPicker(null);
          }}
          onDismiss={() => setPicker(null)}
        />
      ) : null}
    </>
  );
}

function ChoiceGroup({ label, children }: { label: string; children: ReactNode }) {
  return (
    <View style={{ gap: spacing.sm }}>
      <Kicker>{label}</Kicker>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm }}>{children}</View>
    </View>
  );
}


