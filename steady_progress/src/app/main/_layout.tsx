import { Tabs } from 'expo-router';
import { CustomTabBar } from '@/components/navigation/custom-tab-bar';
import { colors } from '@/theme';

/**
 * Five tabs, matching Flutter's `StatefulShellRoute.indexedStack` order in
 * `app_router.dart`. Reminders is tab 0 — a cold start lands there because
 * it is the owner's stated focus, not a side effect of tab ordering.
 *
 * CustomTabBar renders the Figma-standard pill navigation bar with
 * directional gradient active pill and fixed tab color family.
 */
export default function MainTabs() {
  return (
    <Tabs
      tabBar={(props) => <CustomTabBar {...props} />}
      screenOptions={{
        headerShown: false,
        sceneStyle: { backgroundColor: colors.background },
      }}
    >
      <Tabs.Screen name="reminders" options={{ title: 'Reminders' }} />
      <Tabs.Screen name="index" options={{ title: 'Today' }} />
      <Tabs.Screen name="habits" options={{ title: 'Habits' }} />
      <Tabs.Screen name="tasks" options={{ title: 'Tasks' }} />
      <Tabs.Screen name="more" options={{ title: 'More' }} />
    </Tabs>
  );
}
