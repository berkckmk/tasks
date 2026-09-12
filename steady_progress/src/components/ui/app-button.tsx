import type { ReactNode } from 'react';
import {
  ActivityIndicator,
  Pressable,
  type PressableProps,
  type StyleProp,
  type ViewStyle,
  View,
} from 'react-native';
import { colors, controlSize, hexToRgba, radius, spacing } from '@/theme';
import { AppText } from './app-text';

export type AppButtonVariant = 'primary' | 'secondary' | 'text' | 'destructive';
export type AppButtonSize = 'sm' | 'md' | 'lg';

const heights: Record<AppButtonSize, number> = {
  sm: controlSize.hitTarget,
  md: controlSize.button,
  lg: controlSize.fab,
};

export type AppButtonProps = Omit<PressableProps, 'children' | 'style'> & {
  label: string;
  variant?: AppButtonVariant;
  size?: AppButtonSize;
  loading?: boolean;
  expand?: boolean;
  pill?: boolean;
  icon?: ReactNode;
  color?: string;
  selected?: boolean;
  style?: StyleProp<ViewStyle>;
};

export function AppButton({
  label,
  variant = 'primary',
  size = 'md',
  loading = false,
  expand = false,
  pill = false,
  icon,
  color,
  selected,
  disabled,
  style,
  ...props
}: AppButtonProps) {
  const isDisabled = disabled || loading;

  let foreground: string;
  let borderColor: string;
  let backgroundColor: string;
  let borderWidth: number;

  if (selected !== undefined) {
    if (selected) {
      foreground = color ?? colors.text;
      borderColor = color ?? colors.border;
      borderWidth = 1.5;
      backgroundColor = color ? hexToRgba(color, 0.16) : colors.surfaceMuted;
    } else {
      foreground = colors.muted;
      borderColor = colors.border;
      borderWidth = 1;
      backgroundColor = colors.transparent;
    }
  } else if (variant === 'secondary') {
    foreground = colors.text;
    borderColor = color ?? colors.border;
    borderWidth = 1;
    backgroundColor = colors.surfaceElevated;
  } else if (variant === 'destructive') {
    foreground = colors.error;
    borderColor = colors.error;
    borderWidth = 1;
    backgroundColor = colors.transparent;
  } else if (variant === 'text') {
    foreground = color ?? colors.text;
    borderColor = colors.transparent;
    borderWidth = 0;
    backgroundColor = colors.transparent;
  } else if (expand && color) {
    foreground = colors.text;
    borderColor = color;
    borderWidth = 1.5;
    backgroundColor = hexToRgba(color, 0.22);
  } else {
    foreground = color ?? colors.text;
    borderColor = color ?? colors.border;
    borderWidth = color ? 1.5 : 1;
    backgroundColor = colors.transparent;
  }

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ disabled: isDisabled, busy: loading, selected }}
      disabled={isDisabled}
      style={({ pressed }) => [
        {
          minHeight: heights[size],
          minWidth: expand ? '100%' : controlSize.hitTarget,
          paddingHorizontal: variant === 'text' && selected === undefined ? spacing.md : spacing.lg,
          paddingVertical: variant === 'text' && selected === undefined ? spacing.sm : spacing.md,
          borderRadius: pill ? radius.pill : radius.button,
          borderCurve: pill ? undefined : 'continuous',
          borderWidth,
          borderColor,
          backgroundColor: pressed
            ? (color ? hexToRgba(color, expand ? 0.35 : 0.28) : colors.surfaceMuted)
            : backgroundColor,
          alignItems: 'center',
          justifyContent: 'center',
          opacity: isDisabled ? 0.45 : 1,
        },
        style,
      ]}
      {...props}
    >
      {loading ? (
        <ActivityIndicator color={foreground} />
      ) : (
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm }}>
          {icon}
          <AppText
            variant="title"
            style={{
              color: foreground,
              textAlign: 'center',
              fontWeight: selected || (expand && color) ? '600' : '500',
            }}
          >
            {label}
          </AppText>
        </View>
      )}
    </Pressable>
  );
}

