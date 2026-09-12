import type { PropsWithChildren } from 'react';
import { Pressable, View } from 'react-native';
import { spacing } from '@/theme';
import { AppButton } from './app-button';
import { AppIcon } from './app-icon';
import { AppSheet } from './app-sheet';
import { AppText } from './app-text';

type ListEditorSheetProps = PropsWithChildren<{
  presented: boolean;
  title: string;
  accentColor?: string;
  error?: string | null;
  saving?: boolean;
  isDirty?: boolean;
  onDismiss: () => void;
  onSave: () => void;
  deleteLabel?: string;
  onDelete?: () => void;
}>;

/** Shared add/edit form frame for every list feature. */
export function ListEditorSheet({
  presented,
  title,
  accentColor,
  error,
  saving = false,
  isDirty: _isDirty,
  onDismiss,
  onSave,
  deleteLabel,
  onDelete,
  children,
}: ListEditorSheetProps) {
  return (
    <AppSheet presented={presented} onDismiss={onDismiss}>
      <View style={{ gap: spacing.lg, paddingTop: spacing.lg }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
          <AppText variant="h3">{title}</AppText>
          <Pressable
            hitSlop={8}
            onPress={onDismiss}
            accessibilityRole="button"
            accessibilityLabel="Kapat"
            style={{ padding: spacing.xs }}
          >
            <AppIcon name="x" size={20} tone="muted" />
          </Pressable>
        </View>
        {children}
        {error ? <AppText accessibilityRole="alert" tone="error">{error}</AppText> : null}
        <AppButton
          label="Kaydet"
          expand
          color={accentColor}
          loading={saving}
          disabled={saving}
          onPress={onSave}
        />
        {deleteLabel && onDelete ? (
          <AppButton label={deleteLabel} expand variant="destructive" disabled={saving} onPress={onDelete} />
        ) : null}
      </View>
    </AppSheet>
  );
}

