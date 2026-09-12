import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import DateTimePicker from '@expo/ui/community/datetime-picker';
import { Alert, Pressable, Text, View } from 'react-native';
import { AppButton, AppCard, AppIcon, AppText, AppTextField, CheckCircle, CollapsibleHistorySection, EmptyState, Kicker, ListEditorSheet, ListScreenShell, ListItemRow, SectionHeader } from '@/components/ui';
import { useAppData } from '@/core/data/app-data';
import { ReminderRepository } from '@/features/reminders/reminder-repository';
import { ImportantAlarmService } from '@/features/reminders/important-alarm-service';
import { cancelReminder, scheduleReminder } from '@/features/reminders/reminder-scheduler';
import { effectiveReminderPriority, getRecurrenceDayBadge, isMedicineReminder, reminderPriorities, type ReminderItem, type ReminderPriority } from '@/features/reminders/reminder';
import { isCompletedToday } from '@/core/data/firestore-values';
import { colors, radius, spacing, typography } from '@/theme';

const priorityLabels: Record<ReminderPriority, string> = { low: 'Sessiz', normal: 'Normal', important: 'Önemli' };
const earlyAlerts = [0, 5, 10, 15, 30, 60, 1440] as const;
const repeatRules = ['Tekrarlama', 'Her gün', 'Hafta içi (Pzt-Cum)', 'Her hafta', 'Her ay', 'Her yıl'] as const;
const categories = ['Hatırlatıcılarım', 'İş', 'Kişisel', 'Sağlık', 'Alışveriş', 'Hedefler'] as const;

function nextHour() { const now = new Date(); return new Date(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours() + 1); }
function dateLabel(date: Date | null) { return date ? new Intl.DateTimeFormat('tr-TR', { year: 'numeric', month: 'short', day: 'numeric' }).format(date) : 'Tarih seç'; }
function timeLabel(date: Date | null) { return date ? `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}` : 'Saat seç'; }
function mergeDate(value: Date, previous: Date) {
  // Use UTC calendar components from Compose DatePicker to prevent timezone-shift day off-by-one errors
  const year = value.getUTCFullYear();
  const month = value.getUTCMonth();
  const date = value.getUTCDate();
  return new Date(year, month, date, previous.getHours(), previous.getMinutes(), 0, 0);
}
function mergeTime(value: Date, previous: Date) {
  return new Date(previous.getFullYear(), previous.getMonth(), previous.getDate(), value.getHours(), value.getMinutes(), 0, 0);
}
function earlyLabel(value: number) { if (!value) return 'Erken uyarı yok'; if (value < 60) return `${value} dk önce`; if (value === 60) return '1 saat önce'; return '1 gün önce'; }

export function RemindersScreen({ initialEditId, onBack }: { initialEditId?: string; onBack?: () => void } = {}) {
  const { gateway, userId } = useAppData();
  const repository = useMemo(() => new ReminderRepository(gateway, userId), [gateway, userId]);
  const [items, setItems] = useState<ReminderItem[]>([]);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [title, setTitle] = useState('');
  const [titleError, setTitleError] = useState<string | null>(null);
  const [message, setMessage] = useState('');
  const [dueAt, setDueAt] = useState<Date>(nextHour);
  const [priority, setPriority] = useState<ReminderPriority>('normal');
  const [starred, setStarred] = useState(false);
  const [earlyAlertMinutes, setEarlyAlertMinutes] = useState<number | null>(null);
  const [repeatRule, setRepeatRule] = useState<string>('Tekrarlama');
  const [location, setLocation] = useState('');
  const [category, setCategory] = useState('Hatırlatıcılarım');
  const [checklistText, setChecklistText] = useState('');
  const [picker, setPicker] = useState<'date' | 'time' | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const handledInitialId = useRef<string | null>(null);
  const isSavingRef = useRef(false);
  const userChangedPriorityRef = useRef(false);
  const clientMutationIdRef = useRef<string>('');
  const initialSnapshotRef = useRef<{ title: string; message: string; location: string; checklistText: string } | null>(null);

  useEffect(() => repository.watch(setItems, (reason) => setError(String(reason))), [repository]);
  useEffect(() => {
    if (!initialEditId || handledInitialId.current === initialEditId) return;
    const item = items.find((value) => value.id === initialEditId);
    if (!item) return;
    handledInitialId.current = initialEditId;
    if (item.status === 'completed') {
      setHistoryOpen(true);
    }
    openEdit(item);
  }, [initialEditId, items]);

  function resetForm() {
    setEditingId(null);
    setTitle('');
    setTitleError(null);
    setMessage('');
    setDueAt(nextHour());
    setPriority('normal');
    setStarred(false);
    setEarlyAlertMinutes(null);
    setRepeatRule('Tekrarlama');
    setLocation('');
    setCategory('Hatırlatıcılarım');
    setChecklistText('');
    setPicker(null);
    setError(null);
    isSavingRef.current = false;
    setSaving(false);
    userChangedPriorityRef.current = false;
    clientMutationIdRef.current = `rem_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    initialSnapshotRef.current = null;
  }

  function openCreate() {
    resetForm();
    setSheetOpen(true);
  }

  function openEdit(item: ReminderItem) {
    setEditingId(item.id);
    setTitle(item.title);
    setTitleError(null);
    setMessage(item.message);
    setDueAt(item.dueAt ?? nextHour());
    setPriority(item.priority);
    setStarred(item.starred || item.priority === 'important');
    setEarlyAlertMinutes(item.earlyAlertMinutes);
    setRepeatRule(item.repeatRule ?? 'Tekrarlama');
    setLocation(item.location ?? '');
    setCategory(item.category || 'Hatırlatıcılarım');
    const chkText = item.checklist.join('\n');
    setChecklistText(chkText);
    setPicker(null);
    setError(null);
    isSavingRef.current = false;
    setSaving(false);
    userChangedPriorityRef.current = true;
    clientMutationIdRef.current = `rem_edit_${item.id}_${Date.now()}`;
    initialSnapshotRef.current = {
      title: item.title,
      message: item.message,
      location: item.location ?? '',
      checklistText: chkText,
    };
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
        message !== initialSnapshotRef.current.message ||
        location !== initialSnapshotRef.current.location ||
        checklistText !== initialSnapshotRef.current.checklistText
      );
    }
    return (
      title.trim().length > 0 ||
      message.trim().length > 0 ||
      location.trim().length > 0 ||
      checklistText.trim().length > 0 ||
      priority !== 'normal' ||
      starred ||
      earlyAlertMinutes !== null ||
      repeatRule !== 'Tekrarlama' ||
      category !== 'Hatırlatıcılarım'
    );
  }, [sheetOpen, editingId, title, message, location, checklistText, priority, starred, earlyAlertMinutes, repeatRule, category]);

  function payload(status: ReminderItem['status'] = 'scheduled') {
    const resolvedPriority = effectiveReminderPriority(title.trim(), message.trim(), priority);
    return {
      id: editingId ?? undefined,
      title: title.trim(),
      message: message.trim(),
      dueAt,
      status,
      priority: resolvedPriority,
      starred: starred || resolvedPriority === 'important',
      earlyAlertMinutes,
      repeatRule: repeatRule === 'Tekrarlama' ? null : repeatRule,
      location: location.trim() || null,
      category,
      checklist: checklistText.split('\n').map((value) => value.trim()).filter(Boolean),
      clientMutationId: clientMutationIdRef.current,
    };
  }

  async function save() {
    if (isSavingRef.current || saving) return;
    const trimmedTitle = title.trim();
    if (!trimmedTitle) {
      setTitleError('Hatırlatıcı adı gerekli.');
      return;
    }
    isSavingRef.current = true;
    setSaving(true);
    setError(null);
    try {
      if (editingId) {
        try {
          await ImportantAlarmService.cancel(editingId);
        } catch (alarmError) {
          console.warn('Alarm cancel error:', alarmError);
        }
      }
      const data = payload();
      const id = await repository.save(data);
      if (dueAt && dueAt.getTime() > Date.now()) {
        try {
          await ImportantAlarmService.schedule({
            id,
            timestampMs: dueAt.getTime(),
            title: data.title,
            message: data.message,
            priority: data.priority,
          });
        } catch (alarmError) {
          console.warn('Alarm schedule error:', alarmError);
        }
      }
      close();
    } catch (reason) {
      setError(String(reason));
      isSavingRef.current = false;
    } finally {
      setSaving(false);
    }
  }

  async function remove() {
    if (!editingId || isSavingRef.current || saving) return;
    isSavingRef.current = true;
    setSaving(true);
    try {
      try {
        await ImportantAlarmService.cancel(editingId);
      } catch (alarmError) {
        console.warn('Alarm cancel error:', alarmError);
      }
      await repository.delete(editingId);
      close();
    } catch (reason) {
      setError(String(reason));
      isSavingRef.current = false;
    } finally {
      setSaving(false);
    }
  }

  function confirmRemove() {
    Alert.alert('Hatırlatıcı silinsin mi?', 'Bu işlem geri alınamaz.', [
      { text: 'İptal', style: 'cancel' },
      { text: 'Sil', style: 'destructive', onPress: () => void remove() },
    ]);
  }

  function isReminderCompletedToday(item: ReminderItem) {
    return isCompletedToday(item.lastCompletedAt);
  }

  function isReminderDone(item: ReminderItem) {
    return item.status === 'completed' || isReminderCompletedToday(item);
  }

  async function toggleDone(item: ReminderItem, currentIsDone?: boolean) {
    const isDone = currentIsDone !== undefined ? currentIsDone : isReminderDone(item);
    const done = !isDone;
    const result = await repository.setDone(item.id, done);
    if (result.wasRepeated && result.nextDueAt) {
      await ImportantAlarmService.schedule({
        id: item.id,
        timestampMs: result.nextDueAt.getTime(),
        title: item.title,
        message: item.message,
        priority: item.priority,
      });
    } else if (done) {
      await ImportantAlarmService.complete(item.id);
    } else if (item.dueAt && item.dueAt > new Date()) {
      await ImportantAlarmService.schedule({
        id: item.id,
        timestampMs: item.dueAt.getTime(),
        title: item.title,
        message: item.message,
        priority: item.priority,
      });
    }
  }


  async function snooze(item: ReminderItem) {
    await ImportantAlarmService.snooze(item.id, 10, repository, item.dueAt);
  }

  // Multi-selection state — matching Flutter's RemindersScreen
  const [isSelectionMode, setIsSelectionMode] = useState(false);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [historyOpen, setHistoryOpen] = useState(false);

  const { todayItems, upcomingItems, pastItems } = useMemo(() => {
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    const endOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999).getTime();

    const todayList: ReminderItem[] = [];
    const upcomingList: ReminderItem[] = [];
    const pastList: ReminderItem[] = [];

    for (const item of items) {
      const wasCompletedToday = isReminderCompletedToday(item);
      const isExplicitlyCompleted = item.status === 'completed';

      // Any explicitly completed item goes to Geçmiş
      if (isExplicitlyCompleted) {
        pastList.push(item);
        continue;
      }

      // Any repeating item ticked today MUST fall into Geçmiş
      if (wasCompletedToday) {
        pastList.push({
          ...item,
          status: 'completed',
          dueAt: item.lastCompletedAt ?? item.dueAt,
        });
      }

      if (!item.dueAt) {
        if (!wasCompletedToday) todayList.push(item);
        continue;
      }

      const dueTime = item.dueAt.getTime();
      if (dueTime < startOfToday) {
        if (!wasCompletedToday) pastList.push(item);
      } else if (dueTime <= endOfToday) {
        todayList.push(item);
      } else {
        upcomingList.push(item);
      }
    }

    return {
      todayItems: todayList,
      upcomingItems: upcomingList,
      pastItems: pastList,
    };
  }, [items]);

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
    if (selectedIds.size === items.length) {
      setSelectedIds(new Set());
      setIsSelectionMode(false);
    } else {
      setSelectedIds(new Set(items.map((r) => r.id)));
    }
  }

  function deleteSelected() {
    if (selectedIds.size === 0) return;
    const count = selectedIds.size;
    Alert.alert(
      `Seçilen ${count} hatırlatıcı silinsin mi?`,
      'Bu işlem geri alınamaz.',
      [
        { text: 'İptal', style: 'cancel' },
        {
          text: 'Sil',
          style: 'destructive',
          onPress: async () => {
            try {
              await Promise.all(
                [...selectedIds].map(async (id) => {
                  await ImportantAlarmService.cancel(id);
                  await repository.delete(id);
                }),
              );
              setSelectedIds(new Set());
              setIsSelectionMode(false);
            } catch (reason) {
              Alert.alert('Hata', `Hatırlatıcılar silinemedi: ${reason}`);
            }
          },
        },
      ],
    );
  }

  function renderReminderRow(item: ReminderItem, inHistorySection = false) {
    const isSelected = selectedIds.has(item.id);
    const isDone = inHistorySection ? (item.status === 'completed' || isReminderCompletedToday(item)) : false;
    const displayDate = isDone && item.lastCompletedAt ? item.lastCompletedAt : item.dueAt;
    const recurrenceDayBadge = getRecurrenceDayBadge(item.repeatRule, displayDate);
    const metaParts = [
      item.category,
      dateLabel(displayDate),
      item.repeatRule && item.repeatRule !== 'Tekrarlama' ? item.repeatRule : null,
      recurrenceDayBadge,
      priorityLabels[item.priority],
      item.location,
      item.checklist.length ? `${item.checklist.length} alt madde` : null,
    ].filter(Boolean).join(' · ');

    return (
      <ListItemRow
        key={inHistorySection ? `${item.id}_history` : item.id}
        title={item.title}
        subtitle={metaParts}
        note={item.message || null}
        completed={isDone}
        isSelected={isSelected}
        onPress={isSelectionMode ? () => toggleSelect(item.id) : () => openEdit(item)}
        onLongPress={isSelectionMode ? () => toggleSelect(item.id) : () => startSelection(item.id)}
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
              accessibilityLabel={item.title}
              color={colors.tabReminders}
              onToggle={() => void toggleDone(item, isDone).catch((reason) => setError(String(reason)))}
            />
          )
        }
        badges={
          <>
            {item.starred ? <AppIcon name="star" filled size={13} color={colors.tabReminders} /> : null}
            {item.priority === 'important' && !item.starred ? <AppIcon name="bellRinging" size={13} color={colors.tabReminders} /> : null}
            {item.priority === 'low' ? <AppIcon name="bellSimpleSlash" size={13} tone="muted" /> : null}
            {item.repeatRule && item.repeatRule !== 'Tekrarlama' ? (
              <AppIcon name="arrowsClockwise" size={13} color={colors.tabReminders} />
            ) : null}
          </>
        }
        trailing={
          <View style={{ alignItems: 'flex-end', gap: 4 }}>
            <Text style={{ ...typography.meta, color: colors.muted }}>{timeLabel(displayDate)}</Text>
            {!isDone && !isSelectionMode ? (
              <Pressable
                hitSlop={8}
                onPress={(e) => {
                  e.stopPropagation?.();
                  void snooze(item).catch((reason) => setError(String(reason)));
                }}
                style={{ paddingHorizontal: 6, paddingVertical: 2, borderRadius: radius.sm, backgroundColor: colors.surfaceMuted }}
                accessibilityLabel="10 dakika ertele"
              >
                <Text style={{ ...typography.metaSmall, color: colors.caption }}>+10dk</Text>
              </Pressable>
            ) : null}
          </View>
        }
      />
    );
  }

  return <>
    <ListScreenShell
      title="Reminders"
      subtitle="Zamanı geldiğinde hatırlatılacak maddeleri takip et."
      onAdd={isSelectionMode ? () => {} : openCreate}
      addLabel="Hatırlatıcı ekle"
      onBack={onBack}
      selectionBar={isSelectionMode ? (
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', width: '100%' }}>
          <AppText variant="title" tone="accent">{selectedIds.size} seçildi</AppText>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.xs }}>
            <AppButton
              label={selectedIds.size === items.length ? 'Tümünü kaldır' : 'Tümünü seç'}
              variant="text"
              size="sm"
              color={colors.tabReminders}
              onPress={selectAll}
            />
            <AppButton
              label={`Sil (${selectedIds.size})`}
              variant="text"
              size="sm"
              color={colors.tabReminders}
              onPress={deleteSelected}
            />
            <AppButton
              label="İptal"
              variant="text"
              size="sm"
              color={colors.tabReminders}
              onPress={() => { setIsSelectionMode(false); setSelectedIds(new Set()); }}
            />
          </View>
        </View>
      ) : undefined}
    >
      {items.length === 0 ? (
        <EmptyState title="Henüz hatırlatıcı yok" message="İlk hatırlatıcını sağ alttaki + ile ekleyebilirsin." />
      ) : (
        <View style={{ gap: spacing.sm }}>
          <SectionHeader title="Bugün" count={todayItems.length} color={colors.tabReminders} />
          {todayItems.length === 0 ? (
            <AppText variant="bodySmall" tone="muted" style={{ paddingVertical: spacing.xs, paddingHorizontal: spacing.xs }}>
              Bugün için planlanan hatırlatıcı yok.
            </AppText>
          ) : (
            todayItems.map((item) => renderReminderRow(item, false))
          )}

          {upcomingItems.length > 0 ? (
            <>
              <SectionHeader title="Yaklaşan" count={upcomingItems.length} color={colors.tabReminders} />
              {upcomingItems.map((item) => renderReminderRow(item, false))}
            </>
          ) : null}

          <CollapsibleHistorySection
            count={pastItems.length}
            isExpanded={historyOpen}
            onToggle={() => setHistoryOpen((prev) => !prev)}
            color={colors.tabReminders}
            emptyLabel="Geçmiş hatırlatıcı bulunmuyor."
          >
            {pastItems.map((item) => renderReminderRow(item, true))}
          </CollapsibleHistorySection>
        </View>
      )}
    </ListScreenShell>
    <ListEditorSheet
      presented={sheetOpen}
      title={editingId ? 'Hatırlatıcıyı düzenle' : 'Hatırlatıcı ekle'}
      accentColor={colors.tabReminders}
      error={error}
      saving={saving}
      isDirty={isDirty}
      onDismiss={close}
      onSave={() => void save()}
      deleteLabel={editingId ? 'Hatırlatıcıyı sil' : undefined}
      onDelete={editingId ? confirmRemove : undefined}
    >
      <AppTextField
        autoFocus
        label="Hatırlatıcı adı"
        placeholder="Hatırlatıcı adı"
        value={title}
        error={titleError ?? undefined}
        focusedColor={colors.tabReminders}
        onChangeText={(val) => {
          setTitle(val);
          if (titleError) setTitleError(null);
          if (val && !userChangedPriorityRef.current) {
            if (isMedicineReminder(val, message)) {
              setPriority('important');
              setStarred(true);
            }
          }
        }}
      />
      <AppTextField
        label="Not (isteğe bağlı)"
        placeholder="Not"
        value={message}
        focusedColor={colors.tabReminders}
        onChangeText={(val) => {
          setMessage(val);
          if (val && !userChangedPriorityRef.current) {
            if (isMedicineReminder(title, val)) {
              setPriority('important');
              setStarred(true);
            }
          }
        }}
        multiline
        numberOfLines={3}
      />
      <ChoiceGroup label="Tarih ve saat">
        <AppButton
          label={dateLabel(dueAt)}
          variant="secondary"
          color={colors.tabReminders}
          icon={<AppIcon name="calendarBlank" size={16} color={colors.tabReminders} />}
          onPress={() => setPicker('date')}
        />
        <AppButton
          label={timeLabel(dueAt)}
          variant="secondary"
          color={colors.tabReminders}
          icon={<AppIcon name="clock" size={16} color={colors.tabReminders} />}
          onPress={() => setPicker('time')}
        />
      </ChoiceGroup>
      <ChoiceGroup label="Uyarı gücü">
        {reminderPriorities.map((value) => (
          <AppButton
            key={value}
            label={priorityLabels[value]}
            size="sm"
            color={colors.tabReminders}
            selected={priority === value}
            onPress={() => {
              userChangedPriorityRef.current = true;
              setPriority(value);
              if (value === 'important') setStarred(true);
            }}
          />
        ))}
      </ChoiceGroup>
      <ChoiceGroup label="Yıldız">
        <AppButton
          label={starred ? 'Yıldızlı' : 'Yıldızsız'}
          size="sm"
          color={colors.tabReminders}
          selected={starred}
          icon={<AppIcon name="star" filled={starred} size={15} color={starred ? colors.tabReminders : colors.muted} />}
          onPress={() => {
            userChangedPriorityRef.current = true;
            const next = !starred;
            setStarred(next);
            if (next) setPriority('important');
            else if (priority === 'important') setPriority('normal');
          }}
        />
      </ChoiceGroup>
      <ChoiceGroup label="Erken uyarı">
        {earlyAlerts.map((value) => (
          <AppButton
            key={value}
            label={earlyLabel(value)}
            size="sm"
            color={colors.tabReminders}
            selected={(earlyAlertMinutes ?? 0) === value}
            onPress={() => setEarlyAlertMinutes(value || null)}
          />
        ))}
      </ChoiceGroup>
      <ChoiceGroup label="Tekrarlama">
        {repeatRules.map((value) => (
          <AppButton
            key={value}
            label={value}
            size="sm"
            color={colors.tabReminders}
            selected={repeatRule === value}
            onPress={() => setRepeatRule(value)}
          />
        ))}
      </ChoiceGroup>
      <ChoiceGroup label="Kategori">
        {categories.map((value) => (
          <AppButton
            key={value}
            label={value}
            size="sm"
            color={colors.tabReminders}
            selected={category === value}
            onPress={() => setCategory(value)}
          />
        ))}
      </ChoiceGroup>
      <AppTextField
        label="Konum (isteğe bağlı)"
        placeholder="Yer"
        value={location}
        focusedColor={colors.tabReminders}
        onChangeText={setLocation}
      />
      <AppTextField
        label="Alt maddeler"
        placeholder="Her satıra bir madde"
        value={checklistText}
        focusedColor={colors.tabReminders}
        onChangeText={setChecklistText}
        multiline
        numberOfLines={4}
      />
    </ListEditorSheet>
    {picker ? (
      <DateTimePicker
        value={dueAt}
        mode={picker}
        accentColor={colors.tabReminders}
        themeVariant="light"
        positiveButton={{ label: 'Ayarla' }}
        negativeButton={{ label: 'İptal' }}
        onValueChange={(_event, value) => {
          setDueAt(picker === 'date' ? mergeDate(value, dueAt) : mergeTime(value, dueAt));
          setPicker(null);
        }}
        onDismiss={() => setPicker(null)}
      />
    ) : null}
  </>;
}
function ChoiceGroup({ label, children }: { label: string; children: ReactNode }) { return <View style={{ gap: spacing.sm }}><Kicker>{label}</Kicker><View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm }}>{children}</View></View>; }

