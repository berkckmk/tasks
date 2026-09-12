import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'expo-router';
import { Linking, Pressable, View } from 'react-native';
import { AppButton, AppCard, AppIcon, AppScreen, AppText, Kicker, PageHeaderGradient } from '@/components/ui';
import { useAppData } from '@/core/data/app-data';
import { ReportRepository } from '@/features/reports/report-repository';
import type { Report, ReportStatus } from '@/features/reports/report';
import { spacing } from '@/theme';

const statusLabels: Record<ReportStatus, string> = {
  pending: 'Beklemede',
  generating: 'Hazırlanıyor…',
  ready: 'Hazır',
  failed: 'Başarısız',
};

function date(value: Date) {
  return new Intl.DateTimeFormat('tr-TR', { month: 'short', day: 'numeric' }).format(value);
}

export function ReportsScreen() {
  const router = useRouter();
  const { gateway, userId } = useAppData();
  const repository = useMemo(() => new ReportRepository(gateway, userId), [gateway, userId]);
  const [items, setItems] = useState<Report[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    return repository.watch(setItems, (reason) => setError(String(reason)));
  }, [repository]);

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
          <AppText variant="h2">Raporlar</AppText>
          <AppText tone="muted">Hesabınızdan üretilen Google Doküman ilerleme ve aktivite raporları.</AppText>
        </View>
      </PageHeaderGradient>

      {error ? <AppText tone="error">{error}</AppText> : null}

      {items.length ? (
        <View style={{ gap: spacing.md }}>
          {items.map((item) => (
            <AppCard key={item.id} style={{ gap: spacing.xs }}>
              <Kicker>{item.type === 'weekly' ? 'Haftalık' : 'Aylık'} · {statusLabels[item.status]}</Kicker>
              <AppText variant="title">{date(item.periodStart)} – {date(item.periodEnd)}</AppText>
              {item.googleDocUrl ? (
                <AppButton
                  label="Google Dokümanını Aç"
                  variant="text"
                  onPress={() => void Linking.openURL(item.googleDocUrl!)}
                />
              ) : null}
            </AppCard>
          ))}
        </View>
      ) : (
        <View style={{ alignItems: 'center', justifyContent: 'center', paddingVertical: spacing.xxl, gap: spacing.xs }}>
          <AppText variant="title" tone="text" style={{ textAlign: 'center' }}>
            Henüz rapor yok
          </AppText>
          <AppText variant="bodySmall" tone="muted" style={{ textAlign: 'center', paddingHorizontal: spacing.lg }}>
            Google Entegrasyonları bölümünden yeni bir ilerleme raporu oluşturabilirsiniz.
          </AppText>
        </View>
      )}
    </AppScreen>
  );
}
