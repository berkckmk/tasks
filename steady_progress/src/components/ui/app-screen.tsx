import { useRef, type PropsWithChildren } from 'react';
import {
  LayoutAnimation,
  PanResponder,
  StyleSheet,
  View,
  ScrollView,
  type ScrollViewProps,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import { useRouter } from 'expo-router';
import { LinearGradient } from 'expo-linear-gradient';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { colors, getTabAtmosphere, spacing } from '@/theme';

const TAB_ORDER = ['reminders', 'today', 'habits', 'tasks', 'more'] as const;
const TAB_ROUTES: Record<string, string> = {
  reminders: '/main/reminders',
  today: '/main',
  habits: '/main/habits',
  tasks: '/main/tasks',
  more: '/main/more',
};

type AppScreenProps = PropsWithChildren<{
  tab?: string;
  contentStyle?: StyleProp<ViewStyle>;
  scrollProps?: Omit<ScrollViewProps, 'contentContainerStyle' | 'children'>;
}>;

export function AppScreen({ children, tab, contentStyle, scrollProps }: AppScreenProps) {
  const insets = useSafeAreaInsets();
  const router = useRouter();

  const panResponder = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => false,
      onStartShouldSetPanResponderCapture: () => false,
      onMoveShouldSetPanResponder: (_, gestureState) => {
        if (!tab || !TAB_ORDER.includes(tab as any)) return false;
        return Math.abs(gestureState.dx) > 24 && Math.abs(gestureState.dx) > Math.abs(gestureState.dy) * 2;
      },
      onMoveShouldSetPanResponderCapture: (_, gestureState) => {
        if (!tab || !TAB_ORDER.includes(tab as any)) return false;
        return Math.abs(gestureState.dx) > 24 && Math.abs(gestureState.dx) > Math.abs(gestureState.dy) * 2;
      },
      onPanResponderRelease: (_, gestureState) => {
        if (!tab) return;
        const currentIndex = TAB_ORDER.indexOf(tab as any);
        if (currentIndex === -1) return;

        if (gestureState.dx < -55 && currentIndex < TAB_ORDER.length - 1) {
          LayoutAnimation.configureNext({
            duration: 200,
            create: { type: LayoutAnimation.Types.easeInEaseOut, property: LayoutAnimation.Properties.opacity },
            update: { type: LayoutAnimation.Types.easeInEaseOut },
            delete: { type: LayoutAnimation.Types.easeInEaseOut, property: LayoutAnimation.Properties.opacity },
          });
          router.navigate(TAB_ROUTES[TAB_ORDER[currentIndex + 1]] as any);
        } else if (gestureState.dx > 55 && currentIndex > 0) {
          LayoutAnimation.configureNext({
            duration: 200,
            create: { type: LayoutAnimation.Types.easeInEaseOut, property: LayoutAnimation.Properties.opacity },
            update: { type: LayoutAnimation.Types.easeInEaseOut },
            delete: { type: LayoutAnimation.Types.easeInEaseOut, property: LayoutAnimation.Properties.opacity },
          });
          router.navigate(TAB_ROUTES[TAB_ORDER[currentIndex - 1]] as any);
        }
      },
    })
  ).current;

  return (
    <View style={styles.root} {...panResponder.panHandlers}>
      {tab ? (
        <LinearGradient
          colors={getTabAtmosphere(tab)}
          start={{ x: 0.5, y: 0 }}
          end={{ x: 0.5, y: 1 }}
          style={styles.atmosphere}
          pointerEvents="none"
        />
      ) : null}
      <ScrollView
        style={styles.scroll}
        contentInsetAdjustmentBehavior="automatic"
        keyboardDismissMode="interactive"
        keyboardShouldPersistTaps="handled"
        {...scrollProps}
        contentContainerStyle={[
          {
            paddingHorizontal: spacing.screenH,
            paddingTop: insets.top + spacing.xs,
            paddingBottom: insets.bottom + spacing.xxl,
            gap: spacing.lg,
          },
          contentStyle,
        ]}
      >
        {children}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.background,
  },
  atmosphere: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 280,
  },
  scroll: {
    flex: 1,
    backgroundColor: colors.transparent,
  },
});
