import type { ReactNode } from 'react';
import { Pressable, StyleSheet, Text, View, type StyleProp, type ViewStyle } from 'react-native';
import { colors, radius, spacing, typography } from '@/theme';

export interface ListItemRowProps {
  title: string;
  subtitle?: string | null;
  note?: string | null;
  leading?: ReactNode;
  trailing?: ReactNode;
  badges?: ReactNode;
  completed?: boolean;
  isSelected?: boolean;
  onPress?: () => void;
  onLongPress?: () => void;
  style?: StyleProp<ViewStyle>;
  children?: ReactNode;
}

export function ListItemRow({
  title,
  subtitle,
  note,
  leading,
  trailing,
  badges,
  completed = false,
  isSelected = false,
  onPress,
  onLongPress,
  style,
  children,
}: ListItemRowProps) {
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      onLongPress={onLongPress}
      disabled={!onPress && !onLongPress}
      style={({ pressed }) => [
        styles.container,
        isSelected && styles.selected,
        completed && styles.completedContainer,
        pressed && styles.pressed,
        style,
      ]}
    >
      <View style={styles.contentRow}>
        {leading ? <View style={styles.leading}>{leading}</View> : null}

        <View style={styles.textColumn}>
          <View style={styles.titleRow}>
            {badges ? <View style={styles.badges}>{badges}</View> : null}
            <Text
              numberOfLines={2}
              style={[
                styles.title,
                completed && styles.completedTitle,
              ]}
            >
              {title}
            </Text>
          </View>

          {subtitle ? (
            <Text numberOfLines={1} style={styles.subtitle}>
              {subtitle}
            </Text>
          ) : null}

          {note ? (
            <Text numberOfLines={2} style={styles.note}>
              {note}
            </Text>
          ) : null}
        </View>

        {trailing ? <View style={styles.trailing}>{trailing}</View> : null}
      </View>
      {children ? <View style={styles.extra}>{children}</View> : null}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderWidth: 1,
    borderRadius: radius.card,
    borderCurve: 'continuous',
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.md,
    minHeight: 52,
    justifyContent: 'center',
  },
  contentRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  selected: {
    borderColor: colors.text,
    backgroundColor: colors.surfaceMuted,
  },
  completedContainer: {
    opacity: 0.55,
  },
  pressed: {
    opacity: 0.8,
  },
  leading: {
    marginRight: spacing.sm,
    alignItems: 'center',
    justifyContent: 'center',
  },
  textColumn: {
    flex: 1,
    justifyContent: 'center',
    gap: 2,
  },
  titleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    flexWrap: 'wrap',
  },
  badges: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  title: {
    ...typography.title,
    color: colors.text,
  },
  completedTitle: {
    textDecorationLine: 'line-through',
    color: colors.muted,
  },
  subtitle: {
    ...typography.meta,
    color: colors.muted,
  },
  note: {
    ...typography.note,
    color: colors.note,
    marginTop: 2,
  },
  trailing: {
    marginLeft: spacing.sm,
    alignItems: 'flex-end',
    justifyContent: 'center',
  },
  extra: {
    marginTop: spacing.xs,
  },
});
