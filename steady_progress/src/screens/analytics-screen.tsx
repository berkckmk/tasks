import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'expo-router';
import { Pressable, View } from 'react-native';
import { AppCard, AppIcon, AppScreen, AppText, Kicker, PageHeaderGradient } from '@/components/ui';
import { useAppData } from '@/core/data/app-data';
import { buildAnalyticsSummary } from '@/features/analytics/analytics-summary';
import { GoalRepository } from '@/features/goals/goal-repository';
import type { Goal } from '@/features/goals/goal';
import { HabitRepository } from '@/features/habits/habit-repository';
import { addCalendarDays, formatLogDate, mergeHabitsWithLogs, type Habit, type HabitLog } from '@/features/habits/habit';
import { TaskRepository } from '@/features/tasks/task-repository';
import type { TaskItem } from '@/features/tasks/task-item';
import { radius, spacing } from '@/theme';

export function AnalyticsScreen() {
  const router = useRouter();
  const { gateway, userId } = useAppData();
  const habitsRepo = useMemo(() => new HabitRepository(gateway, userId), [gateway, userId]);
  const tasksRepo = useMemo(() => new TaskRepository(gateway, userId), [gateway, userId]);
  const goalsRepo = useMemo(() => new GoalRepository(gateway, userId), [gateway, userId]);

  const [habits, setHabits] = useState<Habit[]>([]);
  const [logs, setLogs] = useState<HabitLog[]>([]);
  const [tasks, setTasks] = useState<TaskItem[]>([]);
  const [goals, setGoals] = useState<Goal[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fail = (reason: unknown) => setError(String(reason));
    const stops = [
      habitsRepo.watch(setHabits, fail),
      habitsRepo.watchRecentLogs(setLogs, fail, formatLogDate(addCalendarDays(new Date(), -28))),
      tasksRepo.watch(setTasks, fail),
      goalsRepo.watch(setGoals, fail),
    ];
    return () => stops.forEach((stop) => stop());
  }, [habitsRepo, tasksRepo, goalsRepo]);

  const summary = useMemo(
    () => buildAnalyticsSummary({ habits: mergeHabitsWithLogs(habits, logs), logs, tasks, goals }),
    [habits, logs, tasks, goals],
  );

  return (
    <AppScreen tab="more">
      <PageHeaderGradient tab="more">
        <Pressable
          hitSlop={12}
          onPress={() => router.back()}
          accessibilityRole="button"
          accessibilityLabel="Geri"
          style={{
            flexDirection: 'row',
            alignItems: 'center',
            gap: spacing.xs,
            paddingVertical: 2,
            marginBottom: spacing.xs,
          }}
        >
          <AppIcon name="arrowLeft" size={18} tone="accent" />
          <AppText variant="meta" tone="muted">Geri</AppText>
        </Pressable>
        <View style={{ gap: spacing.xs }}>
          <AppText variant="h2">Analiz</AppText>
          <AppText tone="muted">Haftalık ve aylık alışkanlık, görev ve hedef performansı.</AppText>
        </View>
      </PageHeaderGradient>

      {error ? <AppText tone="error">{error}</AppText> : null}

      {/* Üretkenlik Skoru Kartı */}
      <AppCard style={{ gap: spacing.xs }}>
        <Kicker>Üretkenlik skoru</Kicker>
        <AppText variant="h2" tone="inkAccent">{summary.productivityScore}</AppText>
        <AppText tone="muted">Bu haftaki alışkanlık, görev ve hedef tamamlama dengesi.</AppText>
      </AppCard>

      {/* İstatistikler */}
      <View style={{ flexDirection: 'row', gap: spacing.sm }}>
        <AppCard style={{ flex: 1, gap: 2, padding: spacing.sm, borderRadius: radius.sm }}>
          <Kicker>En iyi seri</Kicker>
          <AppText variant="title">{summary.bestStreak} gün</AppText>
        </AppCard>
        <AppCard style={{ flex: 1, gap: 2, padding: spacing.sm, borderRadius: radius.sm }}>
          <Kicker>Hedef ortalaması</Kicker>
          <AppText variant="title">%{Math.round(summary.goalProgressAverage * 100)}</AppText>
        </AppCard>
      </View>

      {summary.mostConsistentHabitName ? (
        <AppCard style={{ gap: spacing.xs }}>
          <Kicker>En istikrarlı alışkanlık</Kicker>
          <AppText variant="title">{summary.mostConsistentHabitName}</AppText>
        </AppCard>
      ) : null}

      {/* Haftalık Dağılım */}
      <View style={{ gap: spacing.xs }}>
        <Kicker>Haftalık tamamlama</Kicker>
        <View style={{ gap: spacing.sm }}>
          {summary.weeklyBreakdown.map((week) => (
            <AppCard key={week.weekLabel} style={{ gap: 2 }}>
              <AppText variant="title">{week.weekLabel} haftası</AppText>
              <AppText tone="muted">
                Alışkanlıklar %{Math.round(week.habitCompletionRate * 100)}
                {week.taskCompletionRate === null ? '' : ` · Görevler %${Math.round(week.taskCompletionRate * 100)}`}
              </AppText>
            </AppCard>
          ))}
        </View>
      </View>
    </AppScreen>
  );
}
