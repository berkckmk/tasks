import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { useRouter } from 'expo-router';
import { Alert, Text, View } from 'react-native';
import {
  AppButton,
  AppCard,
  AppIcon,
  AppText,
  AppTextField,
  Kicker,
  ListEditorSheet,
  ListScreenShell,
  ListItemRow,
} from '@/components/ui';
import { useAppData } from '@/core/data/app-data';
import { LearningRepository } from '@/features/learning/learning-repository';
import {
  type LearningItem,
  type LearningStatus,
  type LearningType,
} from '@/features/learning/learning-item';
import { colors, radius, spacing, typography } from '@/theme';

type StatusFilter = 'all' | LearningStatus;

const typeLabels: Record<LearningType, string> = {
  book: 'Kitap',
  course: 'Kurs',
  podcast: 'Podcast',
};

const statusLabels: Record<LearningStatus, string> = {
  planned: 'Planlandı',
  inProgress: 'Devam ediyor',
  completed: 'Tamamlandı',
};

const filterOptions: { value: StatusFilter; label: string }[] = [
  { value: 'all', label: 'Tümü' },
  { value: 'planned', label: statusLabels.planned },
  { value: 'inProgress', label: statusLabels.inProgress },
  { value: 'completed', label: statusLabels.completed },
];

export function LearningScreen() {
  const router = useRouter();
  const { gateway, userId } = useAppData();
  const repository = useMemo(() => new LearningRepository(gateway, userId), [gateway, userId]);
  const [items, setItems] = useState<LearningItem[]>([]);
  const [filter, setFilter] = useState<StatusFilter>('all');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [title, setTitle] = useState('');
  const [type, setType] = useState<LearningType>('book');
  const [status, setStatus] = useState<LearningStatus>('planned');
  const [rating, setRating] = useState(0);
  const [notes, setNotes] = useState('');
  const [takeaways, setTakeaways] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    return repository.watch(setItems, (reason) => setError(String(reason)));
  }, [repository]);

  const visibleItems = useMemo(() => {
    if (filter === 'all') return items;
    return items.filter((item) => item.status === filter);
  }, [items, filter]);

  function resetForm() {
    setTitle('');
    setType('book');
    setStatus('planned');
    setRating(0);
    setNotes('');
    setTakeaways('');
    setEditingId(null);
    setError(null);
    setSaving(false);
  }

  function openCreate() {
    resetForm();
    setSheetOpen(true);
  }

  function openEdit(item: LearningItem) {
    setEditingId(item.id);
    setTitle(item.title);
    setType(item.type);
    setStatus(item.status);
    setRating(item.rating);
    setNotes(item.notes);
    setTakeaways(item.keyTakeaways.join('\n'));
    setError(null);
    setSaving(false);
    setSheetOpen(true);
  }

  function close() {
    setSheetOpen(false);
    resetForm();
    setSaving(false);
  }

  async function save() {
    const trimmed = title.trim();
    if (!trimmed) {
      setError('Başlık gerekli.');
      return;
    }
    setSaving(true);
    try {
      await repository.save({
        id: editingId ?? undefined,
        title: trimmed,
        type,
        status,
        rating,
        notes: notes.trim(),
        keyTakeaways: takeaways.split('\n').map((line) => line.trim()).filter(Boolean),
      });
      close();
    } catch (reason) {
      setError(String(reason));
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
      'Kaydı sil',
      'Bu öğrenme kaydı kalıcı olarak silinecek.',
      [
        { text: 'Vazgeç', style: 'cancel' },
        { text: 'Sil', style: 'destructive', onPress: () => void remove() },
      ],
    );
  }

  return (
    <>
      <ListScreenShell
        title="Öğrenme Takibi"
        subtitle="Kitap, kurs ve podcast notlarını düzenleyin ve takip edin."
        onBack={() => router.back()}
        onAdd={openCreate}
        addLabel="Öğrenme kaydı ekle"
        hideFab={true}
        controls={(
          <AppCard>
            <Kicker>Durum</Kicker>
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm }}>
              {filterOptions.map((option) => (
                <AppButton
                  key={option.value}
                  label={option.label}
                  size="sm"
                  variant={filter === option.value ? 'primary' : 'text'}
                  onPress={() => setFilter(option.value)}
                />
              ))}
            </View>
          </AppCard>
        )}
      >
        {/* Üst Aksiyon Başlık Alanı */}
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: spacing.sm }}>
          <AppText variant="h3">Kayıtlar</AppText>
          <AppButton
            label="+ Yeni Kayıt"
            size="sm"
            color={colors.tabMore}
            onPress={openCreate}
          />
        </View>

        {visibleItems.length === 0 ? (
          <View style={{ alignItems: 'center', justifyContent: 'center', paddingVertical: spacing.xxl, gap: spacing.xs }}>
            <AppText variant="title" tone="text" style={{ textAlign: 'center' }}>
              {items.length === 0 ? 'Henüz öğrenme kaydı yok' : 'Bu durumda kayıt yok'}
            </AppText>
            <AppText variant="bodySmall" tone="muted" style={{ textAlign: 'center', paddingHorizontal: spacing.lg }}>
              {items.length === 0
                ? 'Yukarıdaki + Yeni Kayıt butonu ile ilk kaydınızı oluşturabilirsiniz.'
                : 'Başka bir durum filtresi seçebilir veya yeni kayıt ekleyebilirsiniz.'}
            </AppText>
          </View>
        ) : (
          <View style={{ gap: spacing.sm }}>
            {visibleItems.map((item) => (
              <ListItemRow
                key={item.id}
                title={item.title}
                subtitle={`${typeLabels[item.type]} · ${statusLabels[item.status]}`}
                note={item.notes || (item.keyTakeaways.length ? `• ${item.keyTakeaways[0]}` : null)}
                onPress={() => openEdit(item)}
                trailing={
                  item.rating > 0 ? (
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 2, paddingHorizontal: 6, paddingVertical: 2, borderRadius: radius.sm, backgroundColor: 'rgba(210, 206, 253, 0.1)' }}>
                      <AppIcon name="star" filled size={12} tone="accent" />
                      <Text style={{ ...typography.metaSmall, color: colors.inkAccent }}>{item.rating}/5</Text>
                    </View>
                  ) : null
                }
              />
            ))}
          </View>
        )}
      </ListScreenShell>
      <ListEditorSheet
        presented={sheetOpen}
        title={editingId ? 'Öğrenme kaydını düzenle' : 'Öğrenme kaydı ekle'}
        error={error}
        saving={saving}
        onDismiss={close}
        onSave={() => void save()}
        deleteLabel={editingId ? 'Kaydı sil' : undefined}
        onDelete={editingId ? confirmRemove : undefined}
      >
        <AppTextField
          autoFocus
          label="Title"
          placeholder="Title"
          value={title}
          onChangeText={setTitle}
          returnKeyType="next"
        />
        <ChoiceGroup label="Tür">
          {(Object.keys(typeLabels) as LearningType[]).map((value) => (
            <AppButton
              key={value}
              label={typeLabels[value]}
              size="sm"
              variant={type === value ? 'primary' : 'text'}
              onPress={() => setType(value)}
            />
          ))}
        </ChoiceGroup>
        <ChoiceGroup label="Durum">
          {(Object.keys(statusLabels) as LearningStatus[]).map((value) => (
            <AppButton
              key={value}
              label={statusLabels[value]}
              size="sm"
              variant={status === value ? 'primary' : 'text'}
              onPress={() => setStatus(value)}
            />
          ))}
        </ChoiceGroup>
        <ChoiceGroup label="Puan">
          {[0, 1, 2, 3, 4, 5].map((value) => (
            <AppButton
              key={value}
              label={String(value)}
              size="sm"
              variant={rating === value ? 'primary' : 'text'}
              onPress={() => setRating(value)}
            />
          ))}
        </ChoiceGroup>
        <AppTextField
          label="Notes (optional)"
          placeholder="Notlarını yaz"
          value={notes}
          onChangeText={setNotes}
          multiline
          numberOfLines={3}
        />
        <AppTextField
          label="Key takeaways (one per line)"
          placeholder="Önemli çıkarımlar"
          value={takeaways}
          onChangeText={setTakeaways}
          multiline
          numberOfLines={3}
        />
      </ListEditorSheet>
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
