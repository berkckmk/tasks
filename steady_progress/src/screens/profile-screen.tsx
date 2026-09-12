import { getAuth, updateEmail, updateProfile } from '@react-native-firebase/auth';
import { signOutApp } from '@/features/auth/production-data-host';
import { useEffect, useMemo, useState } from 'react';
import { router } from 'expo-router';
import { Alert, Image, Pressable, ScrollView, View } from 'react-native';
import {
  AppButton,
  AppCard,
  AppIcon,
  AppScreen,
  AppSheet,
  AppText,
  AppTextField,
  Kicker,
  ListEditorSheet,
  PageHeaderGradient,
} from '@/components/ui';
import { useAppData } from '@/core/data/app-data';
import { ProfileRepository } from '@/features/profile/profile-repository';
import type { UserProfile } from '@/features/profile/user-profile';
import { ReminderRepository } from '@/features/reminders/reminder-repository';
import type { ReminderItem } from '@/features/reminders/reminder';
import { TaskRepository } from '@/features/tasks/task-repository';
import type { TaskItem } from '@/features/tasks/task-item';
import { PROGRESS_AREAS, resetProgressForAreas, type ProgressAreaId } from '@/features/profile/progress-reset';
import { pickAndUploadAvatar } from '@/features/profile/avatar-storage';
import { colors, controlSize, radius, spacing } from '@/theme';

export function ProfileScreen() {
  const { gateway, userId, userEmail, synthetic } = useAppData();
  const authUser = !synthetic ? getAuth().currentUser : null;
  const repositories = useMemo(() => ({
    profile: new ProfileRepository(gateway, userId),
    tasks: new TaskRepository(gateway, userId),
    reminders: new ReminderRepository(gateway, userId),
  }), [gateway, userId]);

  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [tasks, setTasks] = useState<TaskItem[]>([]);
  const [reminders, setReminders] = useState<ReminderItem[]>([]);
  const [open, setOpen] = useState(false);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [saving, setSaving] = useState(false);
  const [avatarBusy, setAvatarBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // İlerlemeyi Sıfırlama State'leri
  const [resetModalOpen, setResetModalOpen] = useState(false);
  const [selectedAreas, setSelectedAreas] = useState<Set<ProgressAreaId>>(new Set());
  const [resetting, setResetting] = useState(false);

  useEffect(() => {
    const onError = (reason: unknown) => setError(String(reason));
    const stops = [
      repositories.profile.watch((p) => { setProfile(p); setError(null); }, onError),
      repositories.tasks.watch(setTasks, onError),
      repositories.reminders.watch(setReminders, onError),
    ];
    return () => stops.forEach((stop) => stop());
  }, [repositories]);

  function edit() {
    setName(profile?.displayName ?? authUser?.displayName ?? '');
    setEmail(profile?.email ?? authUser?.email ?? '');
    setSaving(false);
    setOpen(true);
  }

  async function save() {
    if (!name.trim()) { setError('Görünen ad gerekli.'); return; }
    setSaving(true);
    try {
      if (!synthetic) {
        const current = getAuth().currentUser;
        if (!current) throw new Error('Oturum bulunamadı.');
        if (current.displayName !== name.trim()) await updateProfile(current, { displayName: name.trim() });
        if (email.trim() && current.email !== email.trim()) await updateEmail(current, email.trim());
      }
      await repositories.profile.saveIdentity({ displayName: name.trim(), email: email.trim() });
      setOpen(false);
    } catch (reason) {
      setError(String(reason));
    } finally {
      setSaving(false);
    }
  }

  async function changeAvatar() {
    if (synthetic) { setError('Avatar yükleme yalnızca production Firebase hostunda kullanılabilir.'); return; }
    setAvatarBusy(true);
    try {
      await pickAndUploadAvatar(gateway, userId);
      setError(null);
    } catch (reason) {
      setError(String(reason));
    } finally {
      setAvatarBusy(false);
    }
  }

  function toggleArea(areaId: ProgressAreaId) {
    setSelectedAreas((prev) => {
      const next = new Set(prev);
      if (next.has(areaId)) next.delete(areaId);
      else next.add(areaId);
      return next;
    });
  }

  const allSelected = selectedAreas.size === PROGRESS_AREAS.length;

  function toggleAllAreas() {
    if (allSelected) setSelectedAreas(new Set());
    else setSelectedAreas(new Set(PROGRESS_AREAS.map((a) => a.id)));
  }

  function confirmReset() {
    if (selectedAreas.size === 0) return;
    const count = selectedAreas.size;
    const isAll = count === PROGRESS_AREAS.length;
    Alert.alert(
      'İlerlemeyi Sıfırla',
      isAll
        ? 'Tüm alanlardaki ilerleme ve kayıt verileri sıfırlanacak. Bu işlem geri alınamaz. Onaylıyor musunuz?'
        : `Seçili ${count} alandaki ilerleme verileri sıfırlanacak. Bu işlem geri alınamaz. Onaylıyor musunuz?`,
      [
        { text: 'Vazgeç', style: 'cancel' },
        { text: 'Evet, Sıfırla', style: 'destructive', onPress: () => void executeReset() },
      ],
    );
  }

  async function executeReset() {
    if (selectedAreas.size === 0) {
      Alert.alert('Uyarı', 'Lütfen sıfırlanacak en az bir alan seçin.');
      return;
    }
    setResetting(true);
    try {
      await resetProgressForAreas(gateway, userId, Array.from(selectedAreas));
      setResetModalOpen(false);
      setSelectedAreas(new Set());
      Alert.alert('Başarılı', 'Seçilen alanların ilerlemesi başarıyla sıfırlandı.');
    } catch (reason) {
      Alert.alert('Hata', `İlerleme sıfırlanırken bir hata oluştu: ${reason}`);
    } finally {
      setResetting(false);
    }
  }

  const effectiveEmail = profile?.email || authUser?.email || userEmail || '';
  const isVip = effectiveEmail.trim().toLowerCase() === 'ekmekarasitutun@gmail.com';
  const displayName = profile?.displayName || authUser?.displayName || profile?.email || authUser?.email || 'User';
  const displayEmail = effectiveEmail || null;
  const photoUrl = profile?.photoUrl || authUser?.photoURL || null;

  return (
    <>
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
            <AppText variant="h2">Profil & Hesap</AppText>
            <AppText tone="muted">Hesap bilgileri, ilerleme sıfırlama ve tercihler.</AppText>
          </View>
        </PageHeaderGradient>

        {error && !open ? <AppText tone="error">{error}</AppText> : null}

        {/* Profil Kartı */}
        <AppCard style={{ gap: spacing.md }}>
          <Kicker>{isVip ? 'COMPLETE PLAN · 999 GÜN VIP' : `${profile?.selectedPlan ?? 'starter'} plan · beta`}</Kicker>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.md }}>
            {photoUrl ? (
              <Image
                source={{ uri: photoUrl }}
                accessibilityLabel={`${displayName} profil fotoğrafı`}
                style={{ width: 64, height: 64, borderRadius: radius.pill }}
              />
            ) : (
              <View
                style={{
                  width: 64,
                  height: 64,
                  borderRadius: radius.pill,
                  backgroundColor: colors.surfaceMuted,
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <AppIcon name="userCircle" size={36} tone="muted" />
              </View>
            )}
            <View style={{ flex: 1, gap: 2 }}>
              <AppText variant="h3">{displayName}</AppText>
              {displayEmail ? <AppText tone="muted" numberOfLines={1}>{displayEmail}</AppText> : null}
            </View>
          </View>
          <View style={{ flexDirection: 'row', gap: spacing.sm }}>
            <AppButton label="Fotoğrafı değiştir" variant="secondary" size="sm" loading={avatarBusy} onPress={() => void changeAvatar()} />
            <AppButton label="Profili düzenle" variant="text" size="sm" onPress={edit} />
          </View>
        </AppCard>

        {/* İstatistikler */}
        <View style={{ flexDirection: 'row', gap: spacing.sm }}>
          <Stat value={String(reminders.filter((item) => item.status === 'completed').length)} label="Hatırlatıcı bitti" />
          <Stat value={String(tasks.filter((item) => item.status === 'done').length)} label="Görev tamamlandı" />
        </View>

        <Kicker>Ayarlar</Kicker>
        <AppCard>
          <AppButton label="Reminders ve bildirimler" variant="text" expand onPress={() => router.push('/notifications')} />
          <AppButton label="Analytics" variant="text" expand onPress={() => router.push('/analytics')} />
          <AppButton label="Planı yönet" variant="text" expand onPress={() => router.push('/pricing')} />
          {!synthetic ? <AppButton label="Çıkış yap" variant="text" expand onPress={() => void signOutApp()} /> : null}
        </AppCard>

        <Kicker>Veri ve İlerleme</Kicker>
        <AppCard style={{ gap: spacing.sm }}>
          <AppText variant="body" style={{ fontWeight: '600' }}>İlerleme Verilerini Sıfırla</AppText>
          <AppText tone="muted">
            Tamamlanan görevler, alışkanlık zincirleri, hatırlatıcılar veya tüm modüllerin ilerlemesini temizleyebilirsiniz.
          </AppText>
          <AppButton
            label="İlerlemeyi Sıfırla"
            variant="destructive"
            expand
            onPress={() => setResetModalOpen(true)}
          />
        </AppCard>

        <AppText tone="muted">Saat dilimi: {profile?.timezone || Intl.DateTimeFormat().resolvedOptions().timeZone}</AppText>
      </AppScreen>

      {/* Profil Düzenleme Sheet */}
      <ListEditorSheet presented={open} title="Profili düzenle" error={open ? error : null} saving={saving} onDismiss={() => setOpen(false)} onSave={() => void save()}>
        <AppTextField label="Görünen ad" value={name} onChangeText={setName} />
        <AppTextField label="E-posta" value={email} onChangeText={setEmail} keyboardType="email-address" autoCapitalize="none" />
      </ListEditorSheet>

      {/* İlerlemeyi Sıfırlama Sheet */}
      <AppSheet presented={resetModalOpen} onDismiss={() => setResetModalOpen(false)}>
        <View style={{ gap: spacing.md, paddingTop: spacing.md }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
            <AppText variant="h3">İlerlemeyi Sıfırla</AppText>
            <Pressable hitSlop={8} onPress={() => setResetModalOpen(false)} accessibilityLabel="Kapat">
              <AppIcon name="x" size={20} tone="muted" />
            </Pressable>
          </View>
          <AppText tone="muted">
            Sıfırlamak istediğiniz alanları seçin. İlgili modüllerin geçmiş ve tamamlama verileri sıfırlanacaktır.
          </AppText>

          {/* Hepsi Toggle Butonu */}
          <Pressable
            onPress={toggleAllAreas}
            style={{
              flexDirection: 'row',
              alignItems: 'center',
              justifyContent: 'space-between',
              padding: spacing.md,
              borderRadius: radius.card,
              backgroundColor: allSelected ? colors.surfaceElevated : colors.surface,
              borderWidth: 1,
              borderColor: allSelected ? colors.error : colors.border,
            }}
          >
            <View style={{ gap: 2 }}>
              <AppText variant="body" style={{ fontWeight: '700' }}>Hepsi (Tüm Alanlar)</AppText>
              <AppText variant="meta" tone="muted">Tüm alanlardaki ilerleme verilerini sıfırlar</AppText>
            </View>
            <AppIcon
              name={allSelected ? 'check' : 'circle'}
              size={20}
              color={allSelected ? colors.error : colors.muted}
            />
          </Pressable>

          {/* Tekil Alanlar Listesi */}
          <View style={{ gap: spacing.xs, maxHeight: 300 }}>
            <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ gap: spacing.xs }}>
              {PROGRESS_AREAS.map((area) => {
                const isSelected = selectedAreas.has(area.id);
                return (
                  <Pressable
                    key={area.id}
                    onPress={() => toggleArea(area.id)}
                    style={{
                      flexDirection: 'row',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: spacing.sm,
                      borderRadius: radius.card,
                      backgroundColor: isSelected ? colors.surfaceElevated : colors.surface,
                      borderWidth: 1,
                      borderColor: isSelected ? colors.text : colors.border,
                    }}
                  >
                    <View style={{ gap: 2, flex: 1, marginRight: spacing.sm }}>
                      <AppText variant="body" style={{ fontWeight: isSelected ? '600' : '400' }}>{area.label}</AppText>
                      <AppText variant="metaSmall" tone="muted">{area.description}</AppText>
                    </View>
                    <AppIcon
                      name={isSelected ? 'check' : 'circle'}
                      size={18}
                      color={isSelected ? colors.text : colors.muted}
                    />
                  </Pressable>
                );
              })}
            </ScrollView>
          </View>

          {/* Aksiyon Butonları */}
          <View style={{ gap: spacing.sm, marginTop: spacing.xs }}>
            <AppButton
              label={selectedAreas.size > 0 ? `Seçilenleri Sıfırla (${selectedAreas.size})` : 'Alan Seçin'}
              variant="destructive"
              expand
              disabled={selectedAreas.size === 0 || resetting}
              loading={resetting}
              onPress={confirmReset}
            />
            <AppButton
              label="Vazgeç"
              variant="text"
              expand
              disabled={resetting}
              onPress={() => setResetModalOpen(false)}
            />
          </View>
        </View>
      </AppSheet>
    </>
  );
}

function Stat({ value, label }: { value: string; label: string }) {
  return (
    <AppCard style={{ flex: 1 }}>
      <AppText variant="h3">{value}</AppText>
      <AppText tone="muted">{label}</AppText>
    </AppCard>
  );
}
