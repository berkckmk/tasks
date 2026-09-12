import React from 'react';
import {
  LayoutAnimation,
  Platform,
  StyleSheet,
  Text,
  TouchableOpacity,
  UIManager,
  View,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppIcon } from '@/components/ui/app-icon';
import {
  colors,
  controlSize,
  fonts,
  getTabActiveColor,
  getTabColor,
  getTabGradient,
  hexToRgba,
  radius,
  spacing,
  typography,
  type AppIconName,
} from '@/theme';

import type { BottomTabBarProps } from 'expo-router/build/react-navigation/bottom-tabs';

if (Platform.OS === 'android' && UIManager.setLayoutAnimationEnabledExperimental) {
  UIManager.setLayoutAnimationEnabledExperimental(true);
}

interface TabItemConfig {
  name: string;
  label: string;
  icon: AppIconName;
}

const TAB_CONFIGS: Record<string, TabItemConfig> = {
  reminders: { name: 'reminders', label: 'Reminders', icon: 'bell' },
  index: { name: 'index', label: 'Today', icon: 'sunHorizon' },
  habits: { name: 'habits', label: 'Habits', icon: 'plant' },
  tasks: { name: 'tasks', label: 'Tasks', icon: 'checkSquareOffset' },
  more: { name: 'more', label: 'More', icon: 'dotsThreeCircle' },
};

export function CustomTabBar({ state, navigation }: BottomTabBarProps) {
  const insets = useSafeAreaInsets();
  // Lift capsule comfortably above home gesture bar
  const bottomInset = Math.max(insets.bottom, spacing.md) + spacing.md;

  return (
    <View style={[styles.outerWrapper, { paddingBottom: bottomInset }]}>
      <View style={styles.container}>
        {state.routes.map((route, index) => {
          const isFocused = state.index === index;
          const config = TAB_CONFIGS[route.name] ?? {
            name: route.name,
            label: route.name,
            icon: 'circle' as AppIconName,
          };

          const tabColor = getTabColor(route.name);
          const activeColor = getTabActiveColor(route.name);
          const gradient = getTabGradient(route.name);

          const onPress = () => {
            const event = navigation.emit({
              type: 'tabPress',
              target: route.key,
              canPreventDefault: true,
            });

            if (!isFocused && !event.defaultPrevented) {
              LayoutAnimation.configureNext({
                duration: 220,
                create: { type: LayoutAnimation.Types.easeInEaseOut, property: LayoutAnimation.Properties.opacity },
                update: { type: LayoutAnimation.Types.easeInEaseOut },
                delete: { type: LayoutAnimation.Types.easeInEaseOut, property: LayoutAnimation.Properties.opacity },
              });
              navigation.navigate(route.name);
            }
          };

          const onLongPress = () => {
            navigation.emit({
              type: 'tabLongPress',
              target: route.key,
            });
          };

          const isLeft = index === 0;
          const isRight = index === state.routes.length - 1;

          const gradientStart = isLeft
            ? { x: 0, y: 0.5 }
            : isRight
              ? { x: 1, y: 0.5 }
              : { x: 0.2, y: 0.2 };
          const gradientEnd = isLeft
            ? { x: 1, y: 0.5 }
            : isRight
              ? { x: 0, y: 0.5 }
              : { x: 0.8, y: 0.8 };

          return (
            <TouchableOpacity
              key={route.key}
              accessibilityRole="button"
              accessibilityState={isFocused ? { selected: true } : {}}
              accessibilityLabel={config.label}
              testID={`tab-${route.name}`}
              onPress={onPress}
              onLongPress={onLongPress}
              activeOpacity={0.8}
              style={[
                styles.slot,
                isFocused ? styles.slotActive : styles.slotInactive,
                isLeft ? styles.slotLeft : isRight ? styles.slotRight : styles.slotCenter,
              ]}
            >
              {isFocused ? (
                <LinearGradient
                  colors={gradient.pill}
                  start={gradientStart}
                  end={gradientEnd}
                  style={[
                    styles.activePill,
                    {
                      backgroundColor: hexToRgba(tabColor, 0.20),
                    },
                    isRight && styles.activePillReverse,
                  ]}
                >
                  <AppIcon name={config.icon} filled color={activeColor} size={controlSize.navIcon} />
                  <Text style={[styles.activeLabel, { color: activeColor }]} numberOfLines={1}>
                    {config.label}
                  </Text>
                </LinearGradient>
              ) : (
                <View style={styles.inactivePill}>
                  <AppIcon
                    name={config.icon}
                    filled={false}
                    color={colors.navInactive}
                    size={controlSize.navIcon}
                  />
                </View>
              )}
            </TouchableOpacity>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  outerWrapper: {
    backgroundColor: colors.background,
    paddingHorizontal: spacing.screenH,
    paddingTop: spacing.xs,
  },
  container: {
    backgroundColor: colors.navBackground,
    borderRadius: radius.navBar,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.sm,
    minHeight: 64,
    borderWidth: 1,
    borderColor: colors.navBorder,
    shadowColor: colors.text,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.08,
    shadowRadius: 16,
    elevation: 4,
  },
  slot: {
    justifyContent: 'center',
  },
  slotActive: {
    flex: 1.85,
  },
  slotInactive: {
    flex: 1,
  },
  slotLeft: {
    alignItems: 'flex-start',
  },
  slotRight: {
    alignItems: 'flex-end',
  },
  slotCenter: {
    alignItems: 'center',
  },
  activePill: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: radius.activePill,
    paddingHorizontal: 15,
    marginHorizontal: 2,
    paddingVertical: 8,
    minHeight: 42,
    gap: spacing.xs,
  },
  activePillReverse: {
    flexDirection: 'row-reverse',
  },
  activeLabel: {
    ...typography.navLabel,
  },
  inactivePill: {
    width: controlSize.hitTarget,
    height: controlSize.hitTarget,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: radius.activePill,
  },
});
