import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'expo-router';
import { Linking, Pressable, View } from 'react-native';
import { AppButton, AppCard, AppIcon, AppScreen, AppText, Kicker, PageHeaderGradient } from '@/components/ui';
import { useAppData } from '@/core/data/app-data';
import { GoogleIntegrationsRepository, googleIntegrationIds, type GoogleIntegrationId, type GoogleIntegrationStatus } from '@/features/google/google-integrations';
import { spacing } from '@/theme';

const labels: Record<GoogleIntegrationId, { title: string; detail: string; action: string }> = {
  calendar: { title: 'Google Calendar Sync', detail: 'Yalnızca Steady Progress tarafından oluşturulan görev ve alışkanlık etkinliklerini yönetir.', action: 'Şimdi eşitle' },
  sheets: { title: 'Google Sheets Export', detail: 'Seçili Steady Progress verilerinden bir çalışma sayfası oluşturur.', action: 'Dışa aktar' },
  drive: { title: 'Google Drive Backup', detail: 'Uygulamanın oluşturduğu özel klasöre JSON yedeği kaydeder.', action: 'Yedekle' },
  docs: { title: 'Google Docs Reports', detail: 'Aylık ilerleme raporunu yeni bir Google Dokümanı olarak üretir.', action: 'Rapor oluştur' },
};

export function GoogleIntegrationsScreen() {
  const router = useRouter();
  const { gateway, userId, synthetic } = useAppData();
  const repository = useMemo(() => new GoogleIntegrationsRepository(gateway, userId), [gateway, userId]);
  const [statuses, setStatuses] = useState<GoogleIntegrationStatus[]>([]);
  const [busy, setBusy] = useState<GoogleIntegrationId | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  useEffect(() => repository.watch(setStatuses, (reason) => setMessage(String(reason))), [repository]);

  async function run(id: GoogleIntegrationId, action: () => Promise<Record<string, unknown>>) {
    setBusy(id);
    setMessage(null);
    try {
      const result = await action();
      const url = Object.values(result).find((value) => typeof value === 'string' && value.startsWith('https://'));
      if (typeof url === 'string') await Linking.openURL(url);
      else setMessage('İşlem tamamlandı.');
    } catch (reason) {
      setMessage(String(reason));
    } finally {
      setBusy(null);
    }
  }

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
          <AppText variant="h2">Google Entegrasyonları</AppText>
          <AppText tone="muted">Calendar, Sheets, Drive ve Docs servisleri ile bulut senkronizasyonu.</AppText>
        </View>
      </PageHeaderGradient>

      {synthetic ? (
        <AppCard>
          <AppText tone="muted">Google izinleri yalnızca production uygulamasında etkinleştirilir.</AppText>
        </AppCard>
      ) : null}

      {message ? <AppText tone="muted">{message}</AppText> : null}

      <View style={{ gap: spacing.md }}>
        {googleIntegrationIds.map((id) => {
          const item = statuses.find((status) => status.id === id);
          const definition = labels[id];
          const connected = item?.enabled && item.status === 'connected';
          return (
            <AppCard key={id} style={{ gap: spacing.xs }}>
              <Kicker>{connected ? 'Bağlı' : item?.status === 'error' ? 'Hata' : 'Bağlı değil'}</Kicker>
              <AppText variant="title">{definition.title}</AppText>
              <AppText tone="muted">{definition.detail}</AppText>
              {item?.lastSyncedAt ? (
                <AppText tone="muted">Son işlem: {item.lastSyncedAt.toLocaleString('tr-TR')}</AppText>
              ) : null}
              {item?.errorMessage ? <AppText tone="error">{item.errorMessage}</AppText> : null}
              <View style={{ flexDirection: 'row', gap: spacing.sm, marginTop: spacing.xs }}>
                <AppButton
                  disabled={synthetic || busy !== null}
                  loading={busy === id}
                  label={connected ? 'Bağlantıyı kaldır' : 'Bağla'}
                  variant={connected ? 'text' : 'secondary'}
                  onPress={() => void run(id, () => connected ? repository.disconnect(id) : repository.connect(id).then(() => ({})))}
                />
                {connected ? (
                  <AppButton
                    disabled={busy !== null}
                    label={definition.action}
                    variant="text"
                    onPress={() => void run(id, () => id === 'calendar' ? repository.syncCalendar() : id === 'sheets' ? repository.exportSheets() : id === 'drive' ? repository.backupDrive() : repository.generateDocsReport())}
                  />
                ) : null}
              </View>
            </AppCard>
          );
        })}
      </View>
    </AppScreen>
  );
}
