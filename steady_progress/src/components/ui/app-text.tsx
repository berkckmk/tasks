import type { ComponentProps } from 'react';
import { Text, type StyleProp, type TextStyle } from 'react-native';
import { colors, typography, type ColorTone, type TypographyVariant } from '@/theme';

export type AppTextProps = ComponentProps<typeof Text> & {
  variant?: TypographyVariant;
  tone?: ColorTone;
  style?: StyleProp<TextStyle>;
};

export function AppText({ variant = 'body', tone = 'text', style, ...props }: AppTextProps) {
  return <Text style={[typography[variant], { color: colors[tone] }, style]} {...props} />;
}

export function Kicker({ children, ...props }: AppTextProps) {
  const label = typeof children === 'string' ? children.toUpperCase() : children;
  return <AppText variant="kicker" tone="inkAccent" {...props}>{label}</AppText>;
}
