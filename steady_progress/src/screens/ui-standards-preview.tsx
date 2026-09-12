import { useState } from 'react';
import { View } from 'react-native';
import {
  AppButton,
  AppCard,
  AppSheet,
  AppText,
  AppTextField,
  EmptyState,
  Kicker,
  ListScreenShell,
} from '@/components/ui';
import { AppDialog } from '@/components/modal';
import { spacing } from '@/theme';

type ListKind = 'tasks' | 'habits' | 'learning';

const copy = {
  tasks: {
    title: 'Tasks',
    subtitle: 'Planlanan işlerini tek yerde takip et.',
    emptyTitle: 'Henüz görev yok',
    emptyMessage: 'İlk görevini sağ alttaki + ile ekleyebilirsin.',
    addLabel: 'Görev ekle',
    fieldLabel: 'Görev adı',
  },
  habits: {
    title: 'Habits',
    subtitle: 'Düzenli tekrarlarını ve serilerini takip et.',
    emptyTitle: 'Henüz alışkanlık yok',
    emptyMessage: 'İlk alışkanlığını sağ alttaki + ile ekleyebilirsin.',
    addLabel: 'Alışkanlık ekle',
    fieldLabel: 'Alışkanlık adı',
  },
  learning: {
    title: 'Learning tracker',
    subtitle: 'Kitap, kurs ve podcast notlarını takip et.',
    emptyTitle: 'Henüz öğrenme kaydı yok',
    emptyMessage: 'İlk kaydını sağ alttaki + ile ekleyebilirsin.',
    addLabel: 'Öğrenme kaydı ekle',
    fieldLabel: 'Title',
  },
} as const;

/** Review surface proving Tasks and Habits share one layout and one form contract. */
export function UiStandardsPreviewScreen() {
  const [kind, setKind] = useState<ListKind>('tasks');
  const [sheetOpen, setSheetOpen] = useState(false);
  const [dialogOpen, setDialogOpen] = useState(false);
  const current = copy[kind];

  return (
    <>
      <ListScreenShell
        title={current.title}
        subtitle={current.subtitle}
        onAdd={() => setSheetOpen(true)}
        addLabel={current.addLabel}
        controls={(
          <AppCard>
            <Kicker>Ortak sayfa yapısı</Kicker>
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm }}>
              <AppButton
                label="Tasks"
                variant={kind === 'tasks' ? 'primary' : 'text'}
                onPress={() => setKind('tasks')}
              />
              <AppButton
                label="Habits"
                variant={kind === 'habits' ? 'primary' : 'text'}
                onPress={() => setKind('habits')}
              />
              <AppButton
                label="Learning"
                variant={kind === 'learning' ? 'primary' : 'text'}
                onPress={() => setKind('learning')}
              />
              <AppButton
                label="Dialog Test"
                variant="secondary"
                onPress={() => setDialogOpen(true)}
              />
            </View>
          </AppCard>
        )}
      >
        <EmptyState title={current.emptyTitle} message={current.emptyMessage} />
      </ListScreenShell>
      <AppSheet presented={sheetOpen} onDismiss={() => setSheetOpen(false)} testID="standard-add-sheet">
        <View style={{ gap: spacing.lg, paddingTop: spacing.lg }}>
          <AppText variant="h5">{current.addLabel}</AppText>
          <AppTextField
            key={`${kind}-title`}
            autoFocus
            label={current.fieldLabel}
            placeholder={current.fieldLabel}
            returnKeyType="done"
          />
          {kind === 'learning' ? (
            <>
              <AppTextField
                label="Notes (optional)"
                placeholder="Notlarını yaz"
                multiline
                numberOfLines={3}
              />
              <AppTextField
                label="Key takeaways (one per line)"
                placeholder="Önemli çıkarımlar"
                multiline
                numberOfLines={3}
              />
            </>
          ) : null}
          <AppButton label="Kaydet" expand onPress={() => setSheetOpen(false)} />
        </View>
      </AppSheet>
      <AppDialog presented={dialogOpen} onDismiss={() => setDialogOpen(false)}>
        <View style={{ gap: spacing.md }}>
          <AppText variant="h4">Ortak Dialog Standardı</AppText>
          <AppText tone="muted">
            0.96 ölçek ve 8px translateY ile mikro hareket. Saydam backdrop ve pürüzsüz animasyon.
          </AppText>
          <AppButton label="Tamam" onPress={() => setDialogOpen(false)} />
        </View>
      </AppDialog>
    </>
  );
}
