import { Pressable, StyleSheet, type StyleProp, type ViewStyle } from 'react-native';
import { AppIcon } from './app-icon';
import { colors, controlSize } from '@/theme';

export interface CheckCircleProps {
  checked: boolean;
  onToggle?: () => void;
  size?: number;
  accessibilityLabel?: string;
  color?: string;
  style?: StyleProp<ViewStyle>;
  disabled?: boolean;
}

export function CheckCircle({
  checked,
  onToggle,
  size = 18,
  accessibilityLabel,
  color,
  style,
  disabled = false,
}: CheckCircleProps) {
  return (
    <Pressable
      accessibilityRole="checkbox"
      accessibilityState={{ checked }}
      accessibilityLabel={accessibilityLabel}
      disabled={disabled || !onToggle}
      hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
      onPress={onToggle}
      style={({ pressed }) => [
        styles.container,
        pressed && styles.pressed,
        style,
      ]}
    >
      <AppIcon
        name={checked ? 'checkCircle' : 'circle'}
        filled={checked}
        size={size}
        color={checked ? (color ?? colors.text) : colors.inactive}
      />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    width: controlSize.hitTarget,
    height: controlSize.hitTarget,
    alignItems: 'center',
    justifyContent: 'center',
  },
  pressed: {
    opacity: 0.65,
  },
});
