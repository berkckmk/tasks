import { Pressable, StyleSheet, View, type StyleProp, type ViewStyle } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { colors, controlSize, getTabActiveColor, getTabFabGradient, hexToRgba, radius, shadows } from '@/theme';

function PlusGlyph({ color = colors.neutral900, size = 18 }: { color?: string; size?: number }) {
  const thickness = 2.2;
  return (
    <View
      style={{
        width: size,
        height: size,
        alignItems: 'center',
        justifyContent: 'center',
      }}
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
    >
      <View
        style={{
          position: 'absolute',
          width: size,
          height: thickness,
          borderRadius: thickness / 2,
          backgroundColor: color,
        }}
      />
      <View
        style={{
          position: 'absolute',
          width: thickness,
          height: size,
          borderRadius: thickness / 2,
          backgroundColor: color,
        }}
      />
    </View>
  );
}

export function AppFab({
  onPress,
  label = 'Ekle',
  color,
  iconColor,
  tab,
  style,
}: {
  onPress: () => void;
  label?: string;
  color?: string;
  iconColor?: string;
  tab?: string;
  style?: StyleProp<ViewStyle>;
}) {
  const gradient = tab ? getTabFabGradient(tab) : null;
  const resolvedColors: readonly [string, string] = gradient
    ?? (color
      ? [hexToRgba(color, 0.55), hexToRgba(color, 0.20)] as const
      : ['rgba(255, 185, 134, 0.55)', 'rgba(255, 185, 134, 0.20)'] as const);

  const plusColor = iconColor ?? (tab ? getTabActiveColor(tab) : (color ?? colors.neutral900));

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={onPress}
      hitSlop={4}
      style={({ pressed }) => [
        styles.button,
        {
          opacity: pressed ? 0.85 : 1,
          transform: [{ scale: pressed ? 0.95 : 1 }],
        },
        style,
      ]}
    >
      <LinearGradient
        colors={resolvedColors}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={styles.gradient}
      >
        <PlusGlyph color={plusColor} size={18} />
      </LinearGradient>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {
    width: controlSize.fabWidth,
    height: controlSize.fabHeight,
    borderRadius: radius.fab,
    borderCurve: 'continuous',
    borderWidth: 0,
    overflow: 'hidden',
    boxShadow: shadows.md,
    backgroundColor: colors.surface,
  },
  gradient: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});

