import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { useRouter } from 'expo-router';
import DateTimePicker from '@expo/ui/community/datetime-picker';
import { Alert, Text, View } from 'react-native';
import { AppButton, AppCard, AppText, AppTextField, Kicker, ListEditorSheet, ListScreenShell, ListItemRow } from '@/components/ui';
import { useAppData } from '@/core/data/app-data';
import { goalCategories, goalProgress, goalProgressTypes, type Goal, type GoalCategory, type GoalProgressType, type Milestone } from '@/features/goals/goal';
import { GoalRepository } from '@/features/goals/goal-repository';
import { colors, radius, spacing, typography } from '@/theme';

const categoryLabels: Record<GoalCategory, string> = {
  career: 'Kariyer',
  finance: 'Finans',
  health: 'Sağlık',
  learning: 'Öğrenme',
  personal: 'Kişisel',
};

function dateLabel(value: Date | null) {
  return value
    ? new Intl.DateTimeFormat('tr-TR', { year: 'numeric', month: 'short', day: 'numeric' }).format(value)
    : 'Hedef tarihi belirle (isteğe bağlı)';
}

export function GoalsScreen() {
  const router = useRouter();
  const { gateway, userId } = useAppData();
  const repository = useMemo(() => new GoalRepository(gateway, userId), [gateway, userId]);
  const [goals, setGoals] = useState<Goal[]>([]);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory] = useState<GoalCategory>('personal');
  const [targetDate, setTargetDate] = useState<Date | null>(null);
  const [dateOpen, setDateOpen] = useState(false);
  const [progressType, setProgressType] = useState<GoalProgressType>('percentage');
  const [progressText, setProgressText] = useState('0');
  const [milestones, setMilestones] = useState<Milestone[]>([]);
  const [milestoneDraft, setMilestoneDraft] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const sequence = useRef(0);

  useEffect(() => repository.watch(setGoals, (reason) => setError(String(reason))), [repository]);

  function reset() {
    setEditingId(null);
    setTitle('');
    setDescription('');
    setCategory('personal');
    targetDate && setTargetDate(null);
    setDateOpen(false);
    setProgressType('percentage');
    setProgressText('0');
    setMilestones([]);
    setMilestoneDraft('');
    setError(null);
    setSaving(false);
  }

  function openCreate() { reset(); setSheetOpen(true); }
  function openEdit(goal: Goal) {
    setEditingId(goal.id);
    setTitle(goal.title);
    setDescription(goal.description);
    setCategory(goal.category);
    setTargetDate(goal.targetDate);
    setProgressType(goal.progressType);
    setProgressText(String(Math.round(goal.manualProgress * 100)));
    setMilestones(goal.milestones);
    setMilestoneDraft('');
    setError(null);
    setSaving(false);
    setSheetOpen(true);
  }
  function close() { setSheetOpen(false); reset(); }

  function addMilestone() {
    const value = milestoneDraft.trim();
    if (!value) return;
    setMilestones((items) => [...items, { id: `m_${Date.now()}_${sequence.current++}`, title: value, isDone: false }]);
    setMilestoneDraft('');
  }

  async function save() {
    if (!title.trim()) return setError('Hedef başlığı gerekli.');
    const percent = Number(progressText);
    if (!Number.isFinite(percent) || percent < 0 || percent > 100) return setError('İlerleme 0 ile 100 arasında olmalıdır.');
    setSaving(true);
    try {
      await repository.save({ id: editingId ?? undefined, title: title.trim(), description: description.trim(), category, targetDate, progressType, manualProgress: percent / 100, milestones });
      close();
    } catch (reason) { setError(String(reason)); } finally { setSaving(false); }
  }

  async function remove() {
    if (!editingId) return;
    setSaving(true);
    try { await repository.delete(editingId); close(); }
    catch (reason) { setError(String(reason)); } finally { setSaving(false); }
  }

  function confirmRemove() {
    Alert.alert('Hedef silinsin mi?', 'Bu işlem geri alınamaz.', [
      { text: 'Vazgeç', style: 'cancel' },
      { text: 'Sil', style: 'destructive', onPress: () => void remove() },
    ]);
  }

  return (
    <>
      <ListScreenShell
        title="Hedefler"
        subtitle="Büyük hedefleri kilometre taşlarına bölün ve ilerlemenizi takip edin."
        onBack={() => router.back()}
        onAdd={openCreate}
        addLabel="Hedef ekle"
        hideFab={true}
      >
        {/* Üst Aksiyon Başlık Alanı */}
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: spacing.sm }}>
          <AppText variant="h3">Hedefler</AppText>
          <AppButton
            label="+ Yeni Hedef"
            size="sm"
            color={colors.tabMore}
            onPress={openCreate}
          />
        </View>

        {goals.length ? (
          <View style={{ gap: spacing.sm }}>
            {goals.map((goal) => {
              const progressPct = Math.round(goalProgress(goal) * 100);
              return (
                <ListItemRow
                  key={goal.id}
                  title={goal.title}
                  subtitle={`${categoryLabels[goal.category]}${goal.targetDate ? ` · ${dateLabel(goal.targetDate)}` : ''}`}
                  note={goal.description || null}
                  onPress={() => openEdit(goal)}
                  trailing={
                    <View style={{ alignItems: 'flex-end', gap: 4 }}>
                      <View style={{ paddingHorizontal: 6, paddingVertical: 2, borderRadius: radius.sm, backgroundColor: 'rgba(210, 206, 253, 0.1)' }}>
                        <Text style={{ ...typography.metaSmall, color: colors.inkAccent }}>%{progressPct}</Text>
                      </View>
                    </View>
                  }
                />
              );
            })}
          </View>
        ) : (
          <View style={{ alignItems: 'center', justifyContent: 'center', paddingVertical: spacing.xxl, gap: spacing.xs }}>
            <AppText variant="title" tone="text" style={{ textAlign: 'center' }}>
              Henüz hedef yok
            </AppText>
            <AppText variant="bodySmall" tone="muted" style={{ textAlign: 'center', paddingHorizontal: spacing.lg }}>
              Yukarıdaki + Yeni Hedef butonu ile ilk hedefinizi ekleyebilir ve kilometre taşlarınızı belirleyebilirsiniz.
            </AppText>
          </View>
        )}
      </ListScreenShell>

      <ListEditorSheet
        presented={sheetOpen}
        title={editingId ? 'Hedefi düzenle' : 'Yeni hedef'}
        error={error}
        saving={saving}
        onDismiss={close}
        onSave={() => void save()}
        deleteLabel={editingId ? 'Hedefi sil' : undefined}
        onDelete={editingId ? confirmRemove : undefined}
      >
        <AppTextField autoFocus label="Hedef başlığı" value={title} onChangeText={setTitle} />
        <AppTextField label="Açıklama (isteğe bağlı)" value={description} onChangeText={setDescription} multiline numberOfLines={3} />
        <Choice label="Kategori">
          {goalCategories.map((value) => (
            <AppButton key={value} label={categoryLabels[value]} size="sm" variant={category === value ? 'primary' : 'text'} onPress={() => setCategory(value)} />
          ))}
        </Choice>
        <View style={{ gap: spacing.sm }}>
          <Kicker>Hedef tarihi</Kicker>
          <AppButton label={dateLabel(targetDate)} variant="secondary" onPress={() => setDateOpen(true)} />
          {targetDate ? <AppButton label="Tarihi kaldır" variant="text" onPress={() => setTargetDate(null)} /> : null}
        </View>
        <Choice label="İlerleme türü">
          {goalProgressTypes.map((value) => (
            <AppButton key={value} label={value === 'percentage' ? 'Yüzde' : 'Kilometre taşları'} size="sm" variant={progressType === value ? 'primary' : 'text'} onPress={() => setProgressType(value)} />
          ))}
        </Choice>
        {progressType === 'percentage' ? (
          <AppTextField label="İlerleme %" value={progressText} keyboardType="number-pad" onChangeText={setProgressText} />
        ) : (
          <View style={{ gap: spacing.sm }}>
            <Kicker>Kilometre taşları</Kicker>
            {milestones.map((item) => (
              <AppCard key={item.id} style={{ padding: spacing.sm, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
                <AppButton label={`${item.isDone ? '✓ ' : ''}${item.title}`} variant="text" size="sm" onPress={() => setMilestones((values) => values.map((value) => value.id === item.id ? { ...value, isDone: !value.isDone } : value))} />
                <AppButton label="Kaldır" variant="destructive" size="sm" onPress={() => setMilestones((values) => values.filter((value) => value.id !== item.id))} />
              </AppCard>
            ))}
            <AppTextField label="Kilometre taşı ekle" value={milestoneDraft} onChangeText={setMilestoneDraft} onSubmitEditing={addMilestone} />
            <AppButton label="+ Kilometre taşı ekle" variant="text" onPress={addMilestone} />
          </View>
        )}
        {dateOpen ? (
          <DateTimePicker
            value={targetDate ?? new Date()}
            mode="date"
            accentColor={colors.accent}
            themeVariant="light"
            positiveButton={{ label: 'Seç' }}
            negativeButton={{ label: 'Vazgeç' }}
            onValueChange={(_event, value) => {
              setTargetDate(new Date(value.getFullYear(), value.getMonth(), value.getDate()));
              setDateOpen(false);
            }}
            onDismiss={() => setDateOpen(false)}
          />
        ) : null}
      </ListEditorSheet>
    </>
  );
}

function Choice({ label, children }: { label: string; children: ReactNode }) {
  return (
    <View style={{ gap: spacing.sm }}>
      <Kicker>{label}</Kicker>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm }}>{children}</View>
    </View>
  );
}
