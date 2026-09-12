import { useEffect, useMemo, useState, type ReactNode } from 'react';
import DateTimePicker from '@expo/ui/community/datetime-picker';
import { useRouter } from 'expo-router';
import { Alert, Pressable, ScrollView, Text, View } from 'react-native';
import {
  AppButton,
  AppCard,
  AppIcon,
  AppText,
  AppTextField,
  EmptyState,
  Kicker,
  ListEditorSheet,
  ListScreenShell,
  ListItemRow,
} from '@/components/ui';
import { useAppData } from '@/core/data/app-data';
import {
  contentPlatforms,
  contentStatuses,
  type ContentItem,
  type ContentPlatform,
  type ContentStatus,
} from '@/features/content/content-item';
import { ContentRepository } from '@/features/content/content-repository';
import {
  contentTemplates,
  type ContentTemplate,
} from '@/features/content/content-templates';
import { colors, radius, spacing, typography } from '@/theme';

const statusLabels: Record<ContentStatus, string> = {
  idea: 'Fikir',
  drafted: 'Taslak',
  scheduled: 'Planlandı',
  published: 'Yayınlandı',
};

function dateLabel(date: Date) {
  return new Intl.DateTimeFormat('tr-TR', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  }).format(date);
}

export function ContentScreen() {
  const router = useRouter();
  const { gateway, userId } = useAppData();
  const repository = useMemo(() => new ContentRepository(gateway, userId), [gateway, userId]);
  const [items, setItems] = useState<ContentItem[]>([]);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [title, setTitle] = useState('');
  const [platforms, setPlatforms] = useState<ContentPlatform[]>(['Instagram']);
  const [status, setStatus] = useState<ContentStatus>('idea');
  const [publishDate, setPublishDate] = useState<Date | null>(null);
  const [datePickerOpen, setDatePickerOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  // Template state
  const [templatePlatform, setTemplatePlatform] = useState<ContentPlatform>('Instagram');
  const [showTemplates, setShowTemplates] = useState(true);
  const [showModalTemplates, setShowModalTemplates] = useState(false);

  // Multi-selection state
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
    if (selectedIds.size === items.length) {
      setSelectedIds(new Set());
      setIsSelectionMode(false);
    } else {
      setSelectedIds(new Set(items.map((i) => i.id)));
    }
  }

  function deleteSelected() {
    if (selectedIds.size === 0) return;
    const count = selectedIds.size;
    Alert.alert(
      `Seçilen ${count} içerik fikri silinsin mi?`,
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
              Alert.alert('Hata', `İçerikler silinemedi: ${reason}`);
            }
          },
        },
      ],
    );
  }

  useEffect(() => repository.watch(setItems, (reason) => setError(String(reason))), [repository]);

  function resetForm() {
    setEditingId(null);
    setTitle('');
    setPlatforms(['Instagram']);
    setStatus('idea');
    setPublishDate(null);
    setDatePickerOpen(false);
    setError(null);
    setShowModalTemplates(false);
    setSaving(false);
  }

  function openCreate() {
    resetForm();
    setSheetOpen(true);
  }

  function openEdit(item: ContentItem) {
    setEditingId(item.id);
    setTitle(item.title);
    setPlatforms(item.platforms && item.platforms.length > 0 ? item.platforms : [item.platform]);
    setStatus(item.status);
    setPublishDate(item.publishDate);
    setDatePickerOpen(false);
    setError(null);
    setShowModalTemplates(false);
    setSaving(false);
    setSheetOpen(true);
  }

  function close() {
    setSheetOpen(false);
    resetForm();
    setSaving(false);
  }

  function togglePlatform(val: ContentPlatform) {
    setPlatforms((prev) => {
      if (prev.includes(val)) {
        if (prev.length === 1) return prev; // keep at least one platform selected
        return prev.filter((p) => p !== val);
      }
      return [...prev, val];
    });
  }

  function applyTemplate(template: ContentTemplate) {
    setTitle(template.title);
    setPlatforms(template.defaultPlatforms);
    setStatus('idea');
    setPublishDate(null);
    setEditingId(null);
    setShowModalTemplates(false);
    setSheetOpen(true);
  }

  function applyTemplateInModal(template: ContentTemplate) {
    setTitle(template.title);
    setPlatforms(template.defaultPlatforms);
    setShowModalTemplates(false);
  }

  async function save() {
    const trimmed = title.trim();
    if (!trimmed) {
      setError('Lütfen bir başlık girin.');
      return;
    }
    setSaving(true);
    try {
      await repository.save({
        id: editingId ?? undefined,
        title: trimmed,
        platforms,
        publishDate,
        status,
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
      'İçerik fikrini sil',
      'Bu içerik fikri kalıcı olarak silinecek.',
      [
        { text: 'İptal', style: 'cancel' },
        { text: 'Sil', style: 'destructive', onPress: () => void remove() },
      ],
    );
  }

  return (
    <>
      <ListScreenShell
        title="İçerik planlayıcı"
        subtitle="Sosyal medya içerik fikirlerini planlayın ve takip edin."
        onBack={() => router.back()}
        onAdd={isSelectionMode ? () => {} : openCreate}
        addLabel="İçerik fikri ekle"
        selectionBar={isSelectionMode ? (
          <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', width: '100%' }}>
            <AppText variant="title" tone="accent">{selectedIds.size} seçildi</AppText>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.xs }}>
              <AppButton label={selectedIds.size === items.length ? 'Bırak' : 'Tümünü seç'} variant="text" size="sm" onPress={selectAll} />
              <AppButton label={`Sil (${selectedIds.size})`} variant="destructive" size="sm" onPress={deleteSelected} />
              <AppButton label="Vazgeç" variant="text" size="sm" onPress={() => { setIsSelectionMode(false); setSelectedIds(new Set()); }} />
            </View>
          </View>
        ) : undefined}
        hideFab={true}
      >
        {/* Yeni Fikir / Hazır Şablonlar Üst Bar */}
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: spacing.sm }}>
          <AppText variant="h3">İçerik Fikirleri</AppText>
          <AppButton
            label="+ Yeni Fikir"
            size="sm"
            color={colors.tabContent}
            onPress={openCreate}
          />
        </View>

        {/* Hazır Templateler Alanı */}
        <AppCard style={{ gap: spacing.md }}>
          <Pressable
            onPress={() => setShowTemplates((prev) => !prev)}
            style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}
          >
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm }}>
              <AppIcon name="sparkle" size={18} color={colors.tabContent} />
              <AppText variant="title">Hazır İçerik Şablonları</AppText>
            </View>
            <AppIcon
              name={showTemplates ? 'caretUp' : 'caretDown'}
              size={16}
              tone="muted"
            />
          </Pressable>

          {showTemplates ? (
            <>
              {/* Sosyal Medya Platform Seçici Sekmeler */}
              <ScrollView
                horizontal
                showsHorizontalScrollIndicator={false}
                contentContainerStyle={{ gap: spacing.xs, paddingVertical: spacing.xs }}
              >
                {contentPlatforms.map((plat) => {
                  const isSelected = templatePlatform === plat;
                  return (
                    <AppButton
                      key={plat}
                      label={plat}
                      size="sm"
                      selected={isSelected}
                      color={colors.tabContent}
                      onPress={() => setTemplatePlatform(plat)}
                    />
                  );
                })}
              </ScrollView>

              {/* Seçilen Platformun Şablonları */}
              <View style={{ gap: spacing.sm }}>
                {contentTemplates[templatePlatform].map((tpl) => (
                  <Pressable
                    key={tpl.id}
                    onPress={() => applyTemplate(tpl)}
                    style={{
                      padding: spacing.md,
                      borderRadius: radius.card,
                      backgroundColor: colors.surfaceElevated,
                      borderWidth: 1,
                      borderColor: colors.border,
                      gap: spacing.xs,
                    }}
                  >
                    <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
                      <View
                        style={{
                          paddingHorizontal: spacing.sm,
                          paddingVertical: 2,
                          borderRadius: radius.pill,
                          backgroundColor: colors.surfaceMuted,
                        }}
                      >
                        <AppText variant="metaSmall" tone="muted">{tpl.suggestedTag}</AppText>
                      </View>
                      <AppIcon name="plus" size={14} color={colors.tabContent} />
                    </View>
                    <AppText variant="body" style={{ fontWeight: '600' }}>{tpl.title}</AppText>
                    <AppText variant="meta" tone="muted">{tpl.description}</AppText>
                  </Pressable>
                ))}
              </View>
            </>
          ) : null}
        </AppCard>

        {/* Kayıtlı İçerik Listesi */}
        {items.length === 0 ? (
          <EmptyState
            title="Henüz içerik fikri yok"
            message="Yukarıdaki hazır şablonlardan birini seçebilir veya sağ alttaki + ile yeni fikir ekleyebilirsin."
          />
        ) : (
          <View style={{ gap: spacing.sm }}>
            <Kicker>Kayıtlı Fikirler ({items.length})</Kicker>
            {items.map((item) => {
              const isSelected = selectedIds.has(item.id);
              const platformText = item.platforms && item.platforms.length > 0
                ? item.platforms.join(', ')
                : item.platform;

              return (
                <ListItemRow
                  key={item.id}
                  title={item.title}
                  subtitle={`${platformText} · ${statusLabels[item.status]}`}
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
                    ) : undefined
                  }
                  trailing={
                    item.publishDate ? (
                      <Text style={{ ...typography.meta, color: colors.muted }}>{dateLabel(item.publishDate)}</Text>
                    ) : null
                  }
                />
              );
            })}
          </View>
        )}
      </ListScreenShell>

      {/* İçerik Düzenleme / Ekleme Modalı */}
      <ListEditorSheet
        presented={sheetOpen}
        title={editingId ? 'İçerik fikrini düzenle' : 'İçerik fikri ekle'}
        accentColor={colors.tabContent}
        error={error}
        saving={saving}
        onDismiss={close}
        onSave={() => void save()}
        deleteLabel={editingId ? 'İçerik fikrini sil' : undefined}
        onDelete={editingId ? confirmRemove : undefined}
      >
        <View style={{ gap: spacing.xs }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
            <Kicker>Başlık</Kicker>
            <Pressable
              hitSlop={8}
              onPress={() => setShowModalTemplates((prev) => !prev)}
              style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}
            >
              <AppIcon name="sparkle" size={13} color={colors.tabContent} />
              <AppText variant="metaSmall" style={{ color: colors.tabContent }}>
                {showModalTemplates ? 'Şablonları Kapat' : 'Şablondan Doldur'}
              </AppText>
            </Pressable>
          </View>
          <AppTextField
            label="Başlık"
            placeholder="İçerik fikri başlığı"
            value={title}
            focusedColor={colors.tabContent}
            onChangeText={setTitle}
            returnKeyType="done"
          />
        </View>

        {/* Modal İçi Hazır Şablon Seçici */}
        {showModalTemplates ? (
          <View
            style={{
              padding: spacing.md,
              borderRadius: radius.card,
              backgroundColor: colors.surfaceElevated,
              borderWidth: 1,
              borderColor: colors.border,
              gap: spacing.sm,
            }}
          >
            <Kicker>Hazır Şablonlar</Kicker>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: spacing.xs }}>
              {contentPlatforms.map((plat) => (
                <AppButton
                  key={plat}
                  label={plat}
                  size="sm"
                  selected={templatePlatform === plat}
                  color={colors.tabContent}
                  onPress={() => setTemplatePlatform(plat)}
                />
              ))}
            </ScrollView>
            <View style={{ gap: spacing.xs }}>
              {contentTemplates[templatePlatform].map((tpl) => (
                <Pressable
                  key={tpl.id}
                  onPress={() => applyTemplateInModal(tpl)}
                  style={{
                    padding: spacing.sm,
                    borderRadius: radius.sm,
                    backgroundColor: colors.surfaceMuted,
                    gap: 2,
                  }}
                >
                  <AppText variant="body" style={{ fontWeight: '600' }}>{tpl.title}</AppText>
                  <AppText variant="metaSmall" tone="muted">{tpl.description}</AppText>
                </Pressable>
              ))}
            </View>
          </View>
        ) : null}

        {/* Sabit 3 Sütunlu Platform Izgarası (Kayma & Yer Değiştirme Kesinlikle Engellendi) */}
        <View style={{ gap: spacing.xs }}>
          <Kicker>Platformlar (Birden fazla seçilebilir)</Kicker>
          <View style={{ flexDirection: 'row', gap: spacing.sm }}>
            <View style={{ flex: 1 }}>
              <AppButton
                label="Instagram"
                size="sm"
                expand
                selected={platforms.includes('Instagram')}
                color={colors.tabContent}
                onPress={() => togglePlatform('Instagram')}
              />
            </View>
            <View style={{ flex: 1 }}>
              <AppButton
                label="X"
                size="sm"
                expand
                selected={platforms.includes('X')}
                color={colors.tabContent}
                onPress={() => togglePlatform('X')}
              />
            </View>
            <View style={{ flex: 1 }}>
              <AppButton
                label="TikTok"
                size="sm"
                expand
                selected={platforms.includes('TikTok')}
                color={colors.tabContent}
                onPress={() => togglePlatform('TikTok')}
              />
            </View>
          </View>
          <View style={{ flexDirection: 'row', gap: spacing.sm }}>
            <View style={{ flex: 1 }}>
              <AppButton
                label="Facebook"
                size="sm"
                expand
                selected={platforms.includes('Facebook')}
                color={colors.tabContent}
                onPress={() => togglePlatform('Facebook')}
              />
            </View>
            <View style={{ flex: 1 }}>
              <AppButton
                label="YouTube"
                size="sm"
                expand
                selected={platforms.includes('YouTube')}
                color={colors.tabContent}
                onPress={() => togglePlatform('YouTube')}
              />
            </View>
            <View style={{ flex: 1 }}>
              <AppButton
                label="Other"
                size="sm"
                expand
                selected={platforms.includes('Other')}
                color={colors.tabContent}
                onPress={() => togglePlatform('Other')}
              />
            </View>
          </View>
        </View>

        {/* Durum Seçimi */}
        <ChoiceGroup label="Durum">
          {contentStatuses.map((value) => (
            <AppButton
              key={value}
              label={statusLabels[value]}
              size="sm"
              selected={status === value}
              color={colors.tabContent}
              onPress={() => setStatus(value)}
            />
          ))}
        </ChoiceGroup>

        {/* Yayın Tarihi */}
        <View style={{ gap: spacing.sm }}>
          <Kicker>Yayın tarihi</Kicker>
          <AppButton
            label={publishDate ? dateLabel(publishDate) : 'Yayın tarihi belirle (isteğe bağlı)'}
            variant="secondary"
            color={colors.tabContent}
            icon={<AppIcon name="calendarBlank" size={18} color={colors.tabContent} />}
            onPress={() => setDatePickerOpen(true)}
          />
          {publishDate ? (
            <AppButton label="Tarihi kaldır" variant="text" size="sm" onPress={() => setPublishDate(null)} />
          ) : null}
        </View>
      </ListEditorSheet>

      {/* DateTimePicker ListEditorSheet dışında render edilir (Android Çökme Önlemi) */}
      {datePickerOpen ? (
        <DateTimePicker
          value={publishDate ?? new Date()}
          mode="date"
          minimumDate={new Date(new Date().getFullYear(), new Date().getMonth(), new Date().getDate() - 30)}
          maximumDate={new Date(new Date().getFullYear() + 1, new Date().getMonth(), new Date().getDate())}
          accentColor={colors.tabContent}
          themeVariant="light"
          positiveButton={{ label: 'Ayarla' }}
          negativeButton={{ label: 'İptal' }}
          onValueChange={(_event, date) => {
            setPublishDate(new Date(date.getFullYear(), date.getMonth(), date.getDate()));
            setDatePickerOpen(false);
          }}
          onDismiss={() => setDatePickerOpen(false)}
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
