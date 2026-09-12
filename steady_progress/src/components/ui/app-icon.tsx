import { Text, type TextProps } from 'react-native';
import {
  colors,
  controlSize,
  iconFonts,
  icons,
  type AppIconName,
  type ColorTone,
} from '@/theme';

export function AppIcon({
  name,
  filled = false,
  size = controlSize.icon,
  tone = 'text',
  color,
  style,
  ...props
}: Omit<TextProps, 'children'> & {
  name: AppIconName;
  filled?: boolean;
  size?: number;
  tone?: ColorTone;
  color?: string;
}) {
  return (
    <Text
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
      style={[
        {
          fontFamily: filled ? iconFonts.fill : iconFonts.regular,
          fontSize: size,
          color: color ?? colors[tone],
          backgroundColor: 'transparent',
          includeFontPadding: false,
        },
        style,
      ]}
      {...props}
    >
      {String.fromCodePoint(icons[name])}
    </Text>
  );
}
