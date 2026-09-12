import { Stack, useLocalSearchParams, useRouter } from 'expo-router';
import { AppCard, AppScreen, AppText } from '@/components/ui';
import { HabitsScreen } from '@/screens/habits-screen';
import { RemindersScreen } from '@/screens/reminders-screen';
import { TasksScreen } from '@/screens/tasks-screen';
import { DashboardScreen } from '@/screens/dashboard-screen';

function extractSegments(rawWidget?: string[] | string): string[] {
  if (!rawWidget) return [];
  const rawList = Array.isArray(rawWidget) ? rawWidget : [rawWidget];
  const segments: string[] = [];
  for (const raw of rawList) {
    if (typeof raw === 'string') {
      for (const piece of raw.split('/')) {
        const trimmed = piece.trim();
        if (trimmed) {
          segments.push(decodeURIComponent(trimmed));
        }
      }
    }
  }
  if (segments[0]?.toLowerCase() === 'widget') {
    segments.shift();
  }
  return segments;
}

export default function WidgetDestination() {
  const router = useRouter();
  const params = useLocalSearchParams<{ widget?: string[] | string }>();
  const segments = extractSegments(params.widget);

  const rawCollection = segments[0]?.toLowerCase();
  const remaining = segments.slice(1);

  // If there's an id in remaining (excluding literal 'edit'), that's our target itemId
  const editId = remaining.find((part) => part.toLowerCase() !== 'edit') || undefined;

  const handleBack = () => {
    if (router.canGoBack()) {
      router.back();
    } else {
      router.replace('/main');
    }
  };

  if (rawCollection === 'task' || rawCollection === 'tasks') {
    return (
      <>
        <Stack.Screen options={{ headerShown: false }} />
        <TasksScreen initialEditId={editId} onBack={handleBack} />
      </>
    );
  }

  if (rawCollection === 'habit' || rawCollection === 'habits') {
    return (
      <>
        <Stack.Screen options={{ headerShown: false }} />
        <HabitsScreen initialEditId={editId} onBack={handleBack} />
      </>
    );
  }

  if (rawCollection === 'reminder' || rawCollection === 'reminders') {
    return (
      <>
        <Stack.Screen options={{ headerShown: false }} />
        <RemindersScreen initialEditId={editId} onBack={handleBack} />
      </>
    );
  }

  if (rawCollection === 'today' || rawCollection === 'dashboard' || rawCollection === 'main') {
    return (
      <>
        <Stack.Screen options={{ headerShown: false }} />
        <DashboardScreen />
      </>
    );
  }

  return (
    <>
      <Stack.Screen options={{ headerShown: true, title: 'Widget yönlendirmesi' }} />
      <AppScreen>
        <AppText variant="h5">Widget bağlantısı geçersiz</AppText>
        <AppCard>
          <AppText tone="muted">Bu hedef artık mevcut değil.</AppText>
        </AppCard>
      </AppScreen>
    </>
  );
}
