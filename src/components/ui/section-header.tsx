import { type ReactNode } from 'react';
import { Text, View } from 'react-native';
import { colors, radius, spacing, typography } from '@/theme';
import { AppText } from './app-text';

export function SectionHeader({
  title,
  count,
  action,
  color,
}: {
  title: string;
  count?: number;
  action?: ReactNode;
  color?: string;
}) {
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        marginTop: spacing.md,
        marginBottom: spacing.xs,
        paddingHorizontal: spacing.xs,
      }}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.xs }}>
        <AppText variant="title" tone="text">
          {title}
        </AppText>
        {count !== undefined ? (
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
        ) : null}
      </View>
      {action}
    </View>
  );
}
