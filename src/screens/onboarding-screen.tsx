import { router } from 'expo-router';
import { useMemo, useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import { AppButton, AppIcon, AppScreen, AppText } from '@/components/ui';
import { useAppData } from '@/core/data/app-data';
import { ProfileRepository } from '@/features/profile/profile-repository';
import { colors, radius, spacing, typography, type AppIconName } from '@/theme';

interface OnboardingSlide {
  icon: AppIconName;
  title: string;
  description: string;
}

const slides: OnboardingSlide[] = [
  {
    icon: 'plant',
    title: 'Track habits',
    description: 'Build steady routines and watch your streaks grow, one day at a time.',
  },
  {
    icon: 'calendarBlank',
    title: 'Plan your week',
    description: 'Turn your tasks and goals into a clear, calm plan for the week ahead.',
  },
  {
    icon: 'chartLine',
    title: 'See your progress',
    description: 'A single dashboard shows how your habits, tasks, and goals connect.',
  },
];

export function OnboardingScreen({ onCompleted }: { onCompleted?: () => void } = {}) {
  const { gateway, userId } = useAppData();
  const repository = useMemo(() => new ProfileRepository(gateway, userId), [gateway, userId]);
  const [index, setIndex] = useState(0);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const isLast = index === slides.length - 1;
  const current = slides[index];

  async function complete() {
    if (saving) return;
    setSaving(true);
    setError(null);
    try {
      await repository.markOnboardingCompleted();
      if (onCompleted) onCompleted();
      else router.replace('/main/reminders');
    } catch {
      setError('Başlangıç ayarları kaydedilemedi. Lütfen tekrar dene.');
    } finally {
      setSaving(false);
    }
  }

  function handleNext() {
    if (isLast) {
      void complete();
    } else {
      setIndex((prev) => prev + 1);
    }
  }

  return (
    <AppScreen contentStyle={styles.screenContent}>
      <View style={styles.topBar}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Skip onboarding"
          disabled={saving}
          onPress={() => void complete()}
          style={styles.skipButton}
        >
          <AppText tone="muted" style={typography.title}>
            Skip
          </AppText>
        </Pressable>
      </View>

      <View style={styles.slideContainer}>
        <View style={styles.iconCircle}>
          <AppIcon name={current.icon} size={48} tone="accent" />
        </View>
        <AppText variant="h2" style={styles.title}>
          {current.title}
        </AppText>
        <AppText tone="muted" style={styles.description}>
          {current.description}
        </AppText>
      </View>

      <View style={styles.indicatorsRow}>
        {slides.map((_, i) => (
          <View
            key={i}
            style={[
              styles.indicatorDot,
              i === index ? styles.indicatorActive : styles.indicatorInactive,
            ]}
          />
        ))}
      </View>

      <View style={styles.bottomBar}>
        {error ? <AppText tone="error" accessibilityRole="alert">{error}</AppText> : null}
        <AppButton
          label={isLast ? 'Get Started' : 'Next'}
          loading={saving}
          disabled={saving}
          onPress={handleNext}
        />
      </View>
    </AppScreen>
  );
}

const styles = StyleSheet.create({
  screenContent: {
    flexGrow: 1,
    justifyContent: 'space-between',
    paddingVertical: spacing.lg,
  },
  topBar: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    paddingHorizontal: spacing.md,
    minHeight: 40,
  },
  skipButton: {
    padding: spacing.sm,
  },
  slideContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: spacing.xl,
  },
  iconCircle: {
    width: 96,
    height: 96,
    borderRadius: radius.pill,
    backgroundColor: colors.surfaceElevated,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: spacing.xl,
  },
  title: {
    textAlign: 'center',
    marginBottom: spacing.sm,
  },
  description: {
    textAlign: 'center',
    lineHeight: 22,
  },
  indicatorsRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginVertical: spacing.lg,
    gap: spacing.xs,
  },
  indicatorDot: {
    height: 8,
    borderRadius: radius.sm,
  },
  indicatorActive: {
    width: 20,
    backgroundColor: colors.text,
  },
  indicatorInactive: {
    width: 8,
    backgroundColor: colors.divider,
  },
  bottomBar: {
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing.md,
  },
});
