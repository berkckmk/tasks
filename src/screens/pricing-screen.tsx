import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'expo-router';
import { Pressable, View } from 'react-native';
import { AppButton, AppCard, AppIcon, AppScreen, AppText, Kicker, PageHeaderGradient } from '@/components/ui';
import { useAppData } from '@/core/data/app-data';
import { betaAllAccess, planCatalog, planPrice } from '@/features/subscription/plans';
import { SubscriptionRepository } from '@/features/subscription/subscription-repository';
import type { SubscriptionStatus } from '@/features/subscription/subscription-status';
import { spacing } from '@/theme';

export function PricingScreen() {
  const router = useRouter();
  const { gateway, userId, userEmail } = useAppData();
  const repository = useMemo(() => new SubscriptionRepository(gateway, userId, userEmail), [gateway, userId, userEmail]);
  const [status, setStatus] = useState<SubscriptionStatus | null>(null);
  const [yearly, setYearly] = useState(false);

  useEffect(() => repository.watch(setStatus, () => undefined), [repository]);

  const daysLeft = status?.expiresAt
    ? Math.max(0, Math.ceil((status.expiresAt.getTime() - Date.now()) / (24 * 60 * 60 * 1000)))
    : null;

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
          <AppText variant="h2">Planlar & Abonelik</AppText>
          <AppText tone="muted">Abonelik durumu ve Pro özellik paketleri.</AppText>
        </View>
      </PageHeaderGradient>

      {status ? (
        <AppCard style={{ gap: spacing.xs }}>
          <Kicker>Mevcut durum</Kicker>
          <AppText variant="title">Kayıtlı plan: {status.planId.toUpperCase()} · {status.status}</AppText>
          {daysLeft !== null ? <AppText tone="muted">{daysLeft} gün kaldı</AppText> : null}
        </AppCard>
      ) : null}

      {betaAllAccess ? (
        <AppCard style={{ gap: spacing.xs }}>
          <AppText variant="title">Kapalı beta erişimi</AppText>
          <AppText tone="muted">Beta süresince Complete planındaki tüm özellikler ücretsiz açık. Bu ekran ücret tahsil etmez.</AppText>
        </AppCard>
      ) : null}

      <View style={{ flexDirection: 'row', justifyContent: 'flex-start' }}>
        <AppButton label={yearly ? 'Yıllık fiyatlar' : 'Aylık fiyatlar'} variant="secondary" size="sm" onPress={() => setYearly((value) => !value)} />
      </View>

      <View style={{ gap: spacing.md }}>
        {planCatalog.map((plan) => (
          <AppCard key={plan.id} style={{ gap: spacing.sm }}>
            <Kicker>{plan.popular ? 'Popüler · ' : ''}{plan.name}</Kicker>
            <AppText variant="h3">{planPrice(plan, yearly)}</AppText>
            <View style={{ gap: spacing.xs }}>
              {plan.features.map((feature) => (
                <AppText key={feature} tone="muted">✓ {feature}</AppText>
              ))}
            </View>
            <AppButton disabled={betaAllAccess} label={betaAllAccess ? 'Beta kapsamında açık' : 'Bu planı seç'} />
          </AppCard>
        ))}
      </View>
    </AppScreen>
  );
}
