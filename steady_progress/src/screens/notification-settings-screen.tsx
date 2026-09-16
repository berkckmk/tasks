import DateTimePicker from '@expo/ui/community/datetime-picker';
import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'expo-router';
import { AppState, Linking, Pressable, Switch, View } from 'react-native';
import { AppButton, AppCard, AppIcon, AppScreen, AppText, Kicker, PageHeaderGradient } from '@/components/ui';
import { useAppData } from '@/core/data/app-data';
import { defaultNotificationSettings, notificationChannels, withNotificationChannel, type NotificationSettings } from '@/features/notifications/notification-settings';
import { NotificationSettingsRepository } from '@/features/notifications/notification-settings-repository';
import {
  ImportantAlarmService,
  ensureNotificationPermission,
  type PermissionStatus,
} from '@/features/reminders/reminder-scheduler';
import { colors, spacing } from '@/theme';

export function NotificationSettingsScreen() {
  const router = useRouter();
  const { gateway, userId } = useAppData();
  const repository = useMemo(() => new NotificationSettingsRepository(gateway, userId), [gateway, userId]);
  const [settings, setSettings] = useState<NotificationSettings>(defaultNotificationSettings);
  const [picker, setPicker] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [permissionDenied, setPermissionDenied] = useState(false);
  const [permissionStatus, setPermissionStatus] = useState<PermissionStatus>({
    notifications: true,
    exactAlarm: true,
    fullScreenAlarm: true,
    dndAccess: true,
    alarmVolume: true,
    batteryOptimizationIgnored: true,
  });

  useEffect(() => {
    const refreshPermissions = () => void ImportantAlarmService.getPermissionStatus().then(setPermissionStatus);
    refreshPermissions();
    const appStateSubscription = AppState.addEventListener('change', (state) => {
      if (state === 'active') refreshPermissions();
    });
    const stopRepository = repository.watch(
      (next) => {
        setSettings(next);
        setError(null);
      },
      (reason) => setError(String(reason)),
    );
    return () => {
      appStateSubscription.remove();
      stopRepository();
    };
  }, [repository]);

  async function commit(next: NotificationSettings) {
    setSettings(next);
    try {
      await repository.save(next);
      setError(null);
    } catch (reason) {
      setError(String(reason));
    }
  }

  async function setMaster(value: boolean) {
    if (value && !await ensureNotificationPermission()) {
      setPermissionDenied(true);
      setError('Bildirim izni sistem ayarlarında reddedildi.');
      return;
    }
    setPermissionDenied(false);
    await commit({ ...settings, masterEnabled: value });
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
          <AppText variant="h2">Bildirimler</AppText>
          <AppText tone="muted">Hatırlatıcı izinleri ve bildirim kanallarını tek merkezden yönet.</AppText>
        </View>
      </PageHeaderGradient>

      {error ? <AppText accessibilityRole="alert" tone="error">{error}</AppText> : null}
      {permissionDenied ? <AppButton label="Sistem bildirim ayarlarını aç" variant="secondary" onPress={() => void Linking.openSettings()} /> : null}

      <SettingCard
        title="Bildirimlere izin ver"
        description="Aşağıdaki seçimleri kaybetmeden tüm bildirimleri kapat."
        value={settings.masterEnabled}
        onValueChange={(value) => void setMaster(value)}
      />

      <Kicker>Bildirim türleri</Kicker>
      {notificationChannels.map((channel) => (
        <View key={channel.key} style={{ gap: spacing.sm }}>
          <SettingCard
            title={channel.label}
            description={channel.description}
            value={!settings.disabledChannels.has(channel.key)}
            disabled={!settings.masterEnabled}
            onValueChange={(value) => void commit(withNotificationChannel(settings, channel.key, value))}
          />
          {channel.key === 'notifyTaskDigest' ? (
            <AppCard>
              <Kicker>Gönderim saati</Kicker>
              <AppButton
                label={`${String(settings.taskDigestHour).padStart(2, '0')}:00`}
                variant="secondary"
                disabled={!settings.masterEnabled || settings.disabledChannels.has(channel.key)}
                onPress={() => setPicker(true)}
              />
              {picker ? (
                <DateTimePicker
                  value={new Date(2026, 0, 1, settings.taskDigestHour)}
                  mode="time"
                  accentColor={colors.accent}
                  themeVariant="light"
                  onValueChange={(_event, value) => {
                    setPicker(false);
                    void commit({ ...settings, taskDigestHour: value.getHours() });
                  }}
                  onDismiss={() => setPicker(false)}
                />
              ) : null}
            </AppCard>
          ) : null}
        </View>
      ))}

      <AppText tone="muted">
        Saatler cihazın yerel saat dilimine göre yorumlanır: {Intl.DateTimeFormat().resolvedOptions().timeZone}
      </AppText>

      <Kicker>Android alarm ve zamanlama</Kicker>
      <AppCard>
        <AppText variant="title">Exact alarm · {permissionStatus.exactAlarm ? 'Hazır' : 'İzin gerekli'}</AppText>
        <AppText tone="muted">Önemli hatırlatıcıların tam zamanında çalması için gereklidir.</AppText>
        {!permissionStatus.exactAlarm ? (
          <AppButton
            label="Exact alarm erişimini aç"
            variant="secondary"
            onPress={() => void ImportantAlarmService.openExactAlarmSettings()}
          />
        ) : null}

        <View style={{ height: spacing.xs }} />

        <AppText variant="title">Tam ekran alarm · {permissionStatus.fullScreenAlarm ? 'Hazır' : 'İzin gerekli'}</AppText>
        <AppText tone="muted">Telefon kilitliyken veya ekran kapalıyken alarm ekranının uyanabilmesi için gereklidir.</AppText>
        {!permissionStatus.fullScreenAlarm ? (
          <AppButton
            label="Tam ekran alarm erişimini aç"
            variant="secondary"
            onPress={() => void ImportantAlarmService.openFullScreenAlarmSettings()}
          />
        ) : null}

        <View style={{ height: spacing.xs }} />

        <AppText variant="title">Rahatsız Etmeyin erişimi · {permissionStatus.dndAccess ? 'Hazır' : 'İzin gerekli'}</AppText>
        <AppText tone="muted">Önemli alarmın Rahatsız Etmeyin modunu aşabilmesi için sistem erişimi gerekir.</AppText>
        {!permissionStatus.dndAccess ? (
          <AppButton
            label="Rahatsız Etmeyin erişimini aç"
            variant="secondary"
            onPress={() => void ImportantAlarmService.openDndSettings()}
          />
        ) : null}

        <View style={{ height: spacing.xs }} />

        <AppText variant="title">Alarm ses düzeyi · {permissionStatus.alarmVolume ? 'Hazır' : 'Ses kapalı'}</AppText>
        <AppText tone={permissionStatus.alarmVolume ? 'muted' : 'error'}>Telefon sessizde olsa bile alarm ses düzeyi sıfırsa ses çalınamaz.</AppText>

        <View style={{ height: spacing.xs }} />

        <AppText variant="title">Pil optimizasyonu · {permissionStatus.batteryOptimizationIgnored ? 'Kısıtlanmıyor' : 'Kontrol gerekli'}</AppText>
        <AppText tone="muted">Samsung arka plan kısıtlamaları alarm ve veri yenilemeyi geciktirebilir.</AppText>

        <View style={{ height: spacing.xs }} />
        <AppButton
          label="Pil optimizasyonu ayarlarını aç"
          variant="text"
          onPress={() => void ImportantAlarmService.openBatteryOptimizationSettings()}
        />
      </AppCard>
    </AppScreen>
  );
}

function SettingCard({
  title,
  description,
  value,
  disabled,
  onValueChange,
}: {
  title: string;
  description: string;
  value: boolean;
  disabled?: boolean;
  onValueChange: (value: boolean) => void;
}) {
  return (
    <AppCard>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.md }}>
        <View style={{ flex: 1, gap: spacing.xs }}>
          <AppText variant="title">{title}</AppText>
          <AppText tone="muted">{description}</AppText>
        </View>
        <Switch value={value} disabled={disabled} onValueChange={onValueChange} />
      </View>
    </AppCard>
  );
}
