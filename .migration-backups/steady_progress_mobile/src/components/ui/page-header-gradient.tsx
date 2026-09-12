import React from 'react';
import { StyleSheet, type StyleProp, type ViewStyle } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { colors, getTabColor, getTabGradient, hexToRgba, radius, spacing } from '@/theme';

interface PageHeaderGradientProps {
  tab: string;
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
}

export function PageHeaderGradient({ tab, children, style }: PageHeaderGradientProps) {
  const gradient = getTabGradient(tab);
  const tabColor = getTabColor(tab);

  return (
    <LinearGradient
      colors={gradient.header}
      locations={[0, 0.5, 1]}
      start={{ x: 0.5, y: 0 }}
      end={{ x: 0.5, y: 1 }}
      style={[
        styles.container,
        {
          borderColor: hexToRgba(tabColor, 0.22),
        },
        style,
      ]}
    >
      {children}
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  container: {
    borderRadius: radius.pageHeader,
    backgroundColor: colors.surfaceElevated,
    borderWidth: 1,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
  },
});

