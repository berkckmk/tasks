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

import { ALL_NAV_ITEMS, FIXED_MORE_SLOT, type NavSlotId } from '@/features/navbar/navbar-items';
import { useNavBar } from '@/features/navbar/navbar-context';
import { NavBarSettingsSheet } from './navbar-settings-sheet';

if (Platform.OS === 'android' && UIManager.setLayoutAnimationEnabledExperimental) {
  UIManager.setLayoutAnimationEnabledExperimental(true);
}

export function CustomTabBar({ state, navigation }: BottomTabBarProps) {
  const insets = useSafeAreaInsets();
  const { slots, openConfigModal } = useNavBar();
  // Lift capsule comfortably above home gesture bar
  const bottomInset = Math.max(insets.bottom, spacing.md) + spacing.md;

  // Exactly 4 variable slots + 1 fixed More slot
  const renderedTabIds: [NavSlotId, NavSlotId, NavSlotId, NavSlotId, typeof FIXED_MORE_SLOT] = [
    slots[0],
    slots[1],
    slots[2],
    slots[3],
    FIXED_MORE_SLOT,
  ];

  const currentRoute = state.routes[state.index];
  const currentRouteName = currentRoute?.name;

  return (
    <>
      <View style={[styles.outerWrapper, { paddingBottom: bottomInset }]}>
        <View style={styles.container}>
          {renderedTabIds.map((tabId, index) => {
            const isFocused = currentRouteName === tabId;
            const config = ALL_NAV_ITEMS[tabId] ?? {
              name: tabId,
              label: tabId,
              icon: 'circle' as AppIconName,
            };

            const targetRoute = state.routes.find((r) => r.name === tabId);
            const routeKey = targetRoute?.key ?? tabId;

            const tabColor = getTabColor(tabId);
            const activeColor = getTabActiveColor(tabId);
            const gradient = getTabGradient(tabId);

            const onPress = () => {
              if (targetRoute) {
                const event = navigation.emit({
                  type: 'tabPress',
                  target: routeKey,
                  canPreventDefault: true,
                });

                if (!isFocused && !event.defaultPrevented) {
                  LayoutAnimation.configureNext({
                    duration: 220,
                    create: { type: LayoutAnimation.Types.easeInEaseOut, property: LayoutAnimation.Properties.opacity },
                    update: { type: LayoutAnimation.Types.easeInEaseOut },
                    delete: { type: LayoutAnimation.Types.easeInEaseOut, property: LayoutAnimation.Properties.opacity },
                  });
                  navigation.navigate(tabId);
                }
              } else {
                navigation.navigate(tabId);
              }
            };

            const onLongPress = () => {
              if (tabId === FIXED_MORE_SLOT) {
                // Long press on More opens the navbar settings sheet
                openConfigModal();
              } else {
                // Long press on any other tab opens the navbar settings focusing that slot
                openConfigModal(index);
              }
            };

            const isLeft = index === 0;
            const isRight = index === 4; // 5th item is More

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
                key={`nav-tab-${tabId}-${index}`}
                accessibilityRole="button"
                accessibilityState={isFocused ? { selected: true } : {}}
                accessibilityLabel={config.label}
                accessibilityHint={tabId === FIXED_MORE_SLOT ? 'Ayarlar için basılı tutun' : undefined}
                testID={`tab-${tabId}`}
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
      <NavBarSettingsSheet />
    </>
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
