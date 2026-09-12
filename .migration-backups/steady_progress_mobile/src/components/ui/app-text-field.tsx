import { useState } from 'react';
import {
  StyleSheet,
  TextInput,
  View,
  type StyleProp,
  type TextInputProps,
  type ViewStyle,
} from 'react-native';
import { colors, controlSize, radius, spacing, typography } from '@/theme';
import { AppText } from './app-text';

export type AppTextFieldProps = TextInputProps & {
  label?: string;
  error?: string | null;
  focusedColor?: string;
  containerStyle?: StyleProp<ViewStyle>;
};

export function AppTextField({
  label,
  error,
  focusedColor,
  multiline,
  editable = true,
  value,
  defaultValue,
  onChangeText,
  containerStyle,
  onFocus,
  onBlur,
  style,
  ...props
}: AppTextFieldProps) {
  const [focused, setFocused] = useState(false);
  const borderColor = error ? colors.error : focused ? (focusedColor ?? colors.text) : colors.border;

  return (
    <View style={[{ gap: spacing.sm }, containerStyle]}>
      {label ? <AppText variant="caption" tone={focused ? 'text' : 'muted'} style={focused && focusedColor ? { color: focusedColor } : undefined}>{label}</AppText> : null}

      <View
        style={[
          styles.inputContainer,
          {
            minHeight: multiline ? controlSize.button * 2 : controlSize.button,
            borderColor,
            borderWidth: focused || error ? 1.5 : 1,
            opacity: editable ? 1 : 0.45,
          },
        ]}
      >
        <TextInput
          {...props}
          value={value}
          defaultValue={defaultValue}
          editable={editable}
          multiline={multiline}
          cursorColor={colors.text}
          selectionColor={colors.surfaceMuted}
          placeholderTextColor={colors.caption}
          onChangeText={onChangeText}
          onFocus={(e) => {
            setFocused(true);
            onFocus?.(e);
          }}
          onBlur={(e) => {
            setFocused(false);
            onBlur?.(e);
          }}
          style={[
            styles.input,
            {
              height: multiline ? controlSize.button * 2 : controlSize.button,
              textAlignVertical: multiline ? 'top' : 'center',
            },
            style,
          ]}
        />
      </View>
      {error ? <AppText accessibilityRole="alert" variant="caption" tone="error">{error}</AppText> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  inputContainer: {
    backgroundColor: colors.backgroundSoft,
    borderRadius: radius.input,
    borderCurve: 'continuous',
    overflow: 'hidden',
  },
  input: {
    width: '100%',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    color: colors.text,
    fontFamily: typography.body.fontFamily,
    fontSize: typography.body.fontSize,
  },
});

