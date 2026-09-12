import { type PropsWithChildren } from 'react';
import { Pressable, Text, View } from 'react-native';
import { colors, radius, spacing, typography } from '@/theme';
import { AppIcon } from './app-icon';
import { AppText } from './app-text';

export function CollapsibleHistorySection({
  count,
  isExpanded,
  onToggle,
  color,
  emptyLabel = 'Geçmiş kayıt bulunmuyor.',
  children,
}: PropsWithChildren<{
  count: number;
  isExpanded: boolean;
  onToggle: () => void;
  color?: string;
  emptyLabel?: string;
}>) {
  return (
    <View style={{ marginTop: spacing.md, gap: spacing.sm }}>
      <Pressable
        onPress={onToggle}
        style={({ pressed }) => ({
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: 'space-between',
          paddingVertical: spacing.sm + 2,
          paddingHorizontal: spacing.md,
          backgroundColor: pressed ? colors.surfaceMuted : colors.surface,
          borderRadius: radius.card,
          borderCurve: 'continuous',
          borderWidth: 1,
          borderColor: isExpanded && color ? `${color}40` : colors.border,
        })}
        accessibilityRole="button"
        accessibilityLabel={`Geçmiş, ${count} öğe, ${isExpanded ? 'açık' : 'kapalı'}`}
        accessibilityHint="Geçmiş öğeleri göster veya gizle"
      >
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.xs }}>
          <AppIcon name="clockClockwise" size={16} color={color ?? colors.muted} />
          <AppText variant="title" tone="text">
            Geçmiş
          </AppText>
          <View
            style={{
              paddingHorizontal: 8,
              paddingVertical: 2,
              borderRadius: radius.pill,
              backgroundColor: color ? `${color}1A` : colors.surfaceMuted,
            }}
          >
            <Text
              style={{
                ...typography.metaSmall,
                color: color ?? colors.muted,
                fontWeight: '600',
              }}
            >
              {count}
            </Text>
          </View>
        </View>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.xs }}>
          <AppText variant="meta" tone="muted">
            {isExpanded ? 'Gizle' : 'Göster'}
          </AppText>
          <AppIcon
            name={isExpanded ? 'caretUp' : 'caretDown'}
            size={14}
            tone="muted"
          />
        </View>
      </Pressable>
      {isExpanded ? (
        <View style={{ gap: spacing.sm }}>
          {count === 0 ? (
            <AppText
              variant="bodySmall"
              tone="muted"
              style={{ paddingVertical: spacing.xs, paddingHorizontal: spacing.xs }}
            >
              {emptyLabel}
            </AppText>
          ) : (
            children
          )}
        </View>
      ) : null}
    </View>
  );
}
