import { router, type Href } from 'expo-router';
import { View } from 'react-native';
import { AppIcon, AppScreen, AppText, Kicker, ListItemRow, PageHeaderGradient } from '@/components/ui';
import { colors, radius, spacing, type AppIconName, type ColorTone } from '@/theme';

type MoreItem = {
  id: string;
  label: string;
  description: string;
  icon: AppIconName;
  tone: ColorTone;
  badgeBg: keyof typeof colors;
  route: Href;
};

type MoreGroup = {
  title: string;
  items: MoreItem[];
};

const groups: MoreGroup[] = [
  {
    title: 'Planla',
    items: [
      {
        id: 'habits',
        label: 'Habits',
        description: 'Alışkanlık zincirleri ve günlük rutinler',
        icon: 'plant',
        tone: 'accent',
        badgeBg: 'section',
        route: '/habits',
      },
      {
        id: 'goals',
        label: 'Goals',
        description: 'Hedefler, kilometre taşları ve vizyon',
        icon: 'target',
        tone: 'accent',
        badgeBg: 'section',
        route: '/goals',
      },
      {
        id: 'content',
        label: 'Content planner',
        description: 'İçerik takvimi ve fikir havuzu',
        icon: 'notePencil',
        tone: 'accent',
        badgeBg: 'section',
        route: '/content',
      },
    ],
  },
  {
    title: 'Takip et',
    items: [
      {
        id: 'finance',
        label: 'Finance',
        description: 'Gelir, gider ve bütçe dengesi',
        icon: 'wallet',
        tone: 'accent',
        badgeBg: 'section',
        route: '/finance',
      },
      {
        id: 'workout',
        label: 'Workout',
        description: 'Antrenman ve egzersiz programları',
        icon: 'barbell',
        tone: 'accent',
        badgeBg: 'section',
        route: '/workout',
      },
      {
        id: 'learning',
        label: 'Learning',
        description: 'Dersler, okuma listeleri ve notlar',
        icon: 'bookOpen',
        tone: 'accent',
        badgeBg: 'section',
        route: '/learning',
      },
    ],
  },
  {
    title: 'Değerlendir',
    items: [
      {
        id: 'analytics',
        label: 'Analytics',
        description: 'Haftalık ve aylık ilerleme analizleri',
        icon: 'chartLine',
        tone: 'accent',
        badgeBg: 'section',
        route: '/analytics',
      },
      {
        id: 'reports',
        label: 'Reports',
        description: 'Detaylı aktivite ve performans özetleri',
        icon: 'fileText',
        tone: 'accent',
        badgeBg: 'section',
        route: '/reports',
      },
    ],
  },
  {
    title: 'Hesap ve Tercihler',
    items: [
      {
        id: 'profile',
        label: 'Profile',
        description: 'Hesap bilgileri, profil fotoğrafı ve e-posta',
        icon: 'userCircle',
        tone: 'accent',
        badgeBg: 'section',
        route: '/profile',
      },
      {
        id: 'notifications',
        label: 'Notifications',
        description: 'Hatırlatıcılar ve bildirim tercihleri',
        icon: 'bell',
        tone: 'accent',
        badgeBg: 'section',
        route: '/notifications',
      },
      {
        id: 'google-integrations',
        label: 'Google integrations',
        description: 'Google Calendar ve bulut senkronizasyonu',
        icon: 'googleLogo',
        tone: 'accent',
        badgeBg: 'section',
        route: '/google-integrations',
      },
      {
        id: 'pricing',
        label: 'Planlar & Abonelik',
        description: 'Abonelik durumu ve Pro özellikler',
        icon: 'sparkle',
        tone: 'accent',
        badgeBg: 'section',
        route: '/pricing',
      },
    ],
  },
];

export function MoreScreen() {
  return (
    <AppScreen tab="more">
      <PageHeaderGradient tab="more">
        <View style={{ gap: spacing.xs }}>
          <AppText variant="h2">More</AppText>
          <AppText tone="muted">Tüm yardımcı modüller ve tercihler tek merkezde.</AppText>
        </View>
      </PageHeaderGradient>

      {groups.map((group) => (
        <View key={group.title} style={{ gap: spacing.sm }}>
          <Kicker>{group.title}</Kicker>
          <View style={{ gap: spacing.sm }}>
            {group.items.map((item) => (
              <ListItemRow
                key={item.id}
                title={item.label}
                subtitle={item.description}
                onPress={() => router.push(item.route)}
                leading={
                  <View
                    style={{
                      width: 38,
                      height: 38,
                      borderRadius: radius.md,
                      backgroundColor: colors[item.badgeBg],
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}
                  >
                    <AppIcon name={item.icon} filled tone={item.tone} size={20} />
                  </View>
                }
                trailing={<AppIcon name="caretRight" tone="muted" size={16} />}
              />
            ))}
          </View>
        </View>
      ))}
    </AppScreen>
  );
}
