import type { PropsWithChildren, ReactNode } from 'react';
import { Pressable, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { colors, controlSize, getTabColor, radius, spacing } from '@/theme';
import { AppFab } from './app-fab';
import { AppIcon } from './app-icon';
import { AppScreen } from './app-screen';
import { AppText } from './app-text';
import { PageHeaderGradient } from './page-header-gradient';

type ListScreenShellProps = PropsWithChildren<{
  title: string;
  subtitle?: string;
  controls?: ReactNode;
  selectionBar?: ReactNode;
  onAdd?: () => void;
  addLabel?: string;
  hideFab?: boolean;
  onBack?: () => void;
}>;

/** Shared page structure for Tasks and Habits. It owns the single add affordance. */
export function ListScreenShell({
  title,
  subtitle,
  controls,
  selectionBar,
  onAdd,
  addLabel,
  hideFab = false,
  onBack,
  children,
}: ListScreenShellProps) {
  const insets = useSafeAreaInsets();
  const tabKey = title.toLowerCase();
  const tabColor = getTabColor(tabKey);
  const showFab = !hideFab && Boolean(onAdd);

  return (
    <View style={{ flex: 1 }}>
      <AppScreen tab={tabKey} contentStyle={{ paddingBottom: insets.bottom + (showFab ? controlSize.fab + spacing.md : spacing.lg) + (selectionBar ? 60 : 0) }}>
        <PageHeaderGradient tab={tabKey}>
          {onBack ? (
            <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: spacing.xs }}>
              <Pressable
                hitSlop={12}
                onPress={onBack}
                accessibilityRole="button"
                accessibilityLabel="Geri"
                style={{
                  flexDirection: 'row',
                  alignItems: 'center',
                  gap: spacing.xs,
                  paddingVertical: 2,
                }}
              >
                <AppIcon name="arrowLeft" size={18} tone="accent" />
                <AppText variant="meta" tone="muted">Geri</AppText>
              </Pressable>
            </View>
          ) : null}
          <View style={{ gap: spacing.xs }}>
            <AppText variant="h2">{title}</AppText>
            {subtitle ? <AppText tone="muted">{subtitle}</AppText> : null}
          </View>
        </PageHeaderGradient>
        {controls}
        {children}
      </AppScreen>
      {selectionBar ? (
        <View
          style={{
            position: 'absolute',
            bottom: insets.bottom + spacing.sm,
            left: spacing.screenH,
            right: spacing.screenH,
            backgroundColor: colors.surface,
            borderColor: tabColor,
            borderWidth: 1,
            borderRadius: radius.card,
            borderCurve: 'continuous',
            paddingHorizontal: spacing.md,
            paddingVertical: spacing.sm,
            zIndex: 99,
          }}
        >
          {selectionBar}
        </View>
      ) : showFab && onAdd ? (
        <AppFab
          label={addLabel ?? ''}
          color={tabColor}
          tab={tabKey}
          onPress={onAdd}
          style={{ position: 'absolute', right: spacing.screenH, bottom: insets.bottom + spacing.lg }}
        />
      ) : null}
    </View>
  );
}

const controlSizeOffset = controlSize.fab + spacing.xxl;
