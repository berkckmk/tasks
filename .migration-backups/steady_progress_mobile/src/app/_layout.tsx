import { useFonts } from 'expo-font';
import { Stack } from 'expo-router/stack';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';
import { View } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { AppText } from '@/components/ui';
import { colors, fonts } from '@/theme';
import { WidgetRouteListener } from '@/screens/widget-preview';
import { prepareReminderChannels } from '@/features/reminders/reminder-scheduler';
import { ImportantAlarmSync } from '@/features/reminders/important-alarm-sync';
import { WidgetDataSync } from '@/features/widget/widget-data-sync';
import { WidgetMutationDrain } from '@/features/widget/widget-mutation-drain';
import { ProductionDataHost } from '@/features/auth/production-data-host';

export default function RootLayout() {
  const [loaded, error] = useFonts({
    'Inter-Regular': require('../../assets/fonts/Inter-Regular.ttf'),
    'Inter-Medium': require('../../assets/fonts/Inter-Medium.ttf'),
    'Inter-SemiBold': require('../../assets/fonts/Inter-SemiBold.ttf'),
    'Inter-Bold': require('../../assets/fonts/Inter-Bold.ttf'),
    PhosphorRegular: require('../../assets/fonts/Phosphor-Regular.ttf'),
    PhosphorFill: require('../../assets/fonts/Phosphor-Fill.ttf'),
  });
  useEffect(() => {
    void prepareReminderChannels();
  }, []);
  if (!loaded && !error) return <View style={{ flex: 1, backgroundColor: colors.background }} />;
  if (error) return <AppText>Font yüklenemedi: {error.message}</AppText>;
  return (
    <SafeAreaProvider>
      <StatusBar style="dark" />
      <View style={{ flex: 1, backgroundColor: colors.background }}>
        <ProductionDataHost>
          <AppNavigator />
        </ProductionDataHost>
      </View>
    </SafeAreaProvider>
  );
}

function AppNavigator() {
  return <>
          <Stack screenOptions={{
            headerStyle: { backgroundColor: colors.background },
            headerTintColor: colors.text,
            headerTitleStyle: { fontFamily: fonts.medium },
            headerShadowVisible: false,
            contentStyle: { backgroundColor: colors.background },
          }}>
            <Stack.Screen name="index" options={{ title: 'Steady Progress · Preview' }} />
            <Stack.Screen name="[...widget]" options={{ title: 'Widget yönlendirmesi' }} />
            <Stack.Screen name="ui-standards" options={{ title: 'Ortak UI standardı' }} />
            <Stack.Screen name="tasks" options={{ headerShown: false }} />
            <Stack.Screen name="habits" options={{ headerShown: false }} />
            <Stack.Screen name="learning" options={{ headerShown: false }} />
            <Stack.Screen name="reminders" options={{ headerShown: false }} />
            <Stack.Screen name="content" options={{ headerShown: false }} />
            <Stack.Screen name="workout" options={{ headerShown: false }} />
            <Stack.Screen name="goals" options={{ headerShown: false }} />
            <Stack.Screen name="analytics" options={{ headerShown: false }} />
            <Stack.Screen name="reports" options={{ headerShown: false }} />
            <Stack.Screen name="dashboard" options={{ headerShown: false }} />
            <Stack.Screen name="finance" options={{ headerShown: false }} />
            <Stack.Screen name="notifications" options={{ headerShown: false }} />
            <Stack.Screen name="profile" options={{ headerShown: false }} />
            <Stack.Screen name="pricing" options={{ headerShown: false }} />
            <Stack.Screen name="google-integrations" options={{ headerShown: false }} />
            <Stack.Screen name="more" options={{ headerShown: false }} />
            <Stack.Screen name="onboarding" options={{ headerShown: false }} />
            <Stack.Screen name="main" options={{ headerShown: false }} />
          </Stack>
          <WidgetRouteListener />
          <WidgetMutationDrain />
          <WidgetDataSync />
          <ImportantAlarmSync />
        </>;
}
