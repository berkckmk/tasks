import { router, type Href } from 'expo-router';
import { TouchableOpacity, View } from 'react-native';
import { AppIcon, AppScreen, AppText, Kicker, ListItemRow, PageHeaderGradient } from '@/components/ui';
import { useNavBar } from '@/features/navbar/navbar-context';
import { colors, radius, spacing, type AppIconName, type ColorTone } from '@/theme';

type MoreItem = {
  id: string;
  label: string;
  description: string;
  icon: AppIconName;
  tone: ColorTone;
  badgeBg: keyof typeof colors;
  route?: Href;
  onPress?: () => void;
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
        route: '/main/habits',
      },
      {
        id: 'goals',
        label: 'Goals',
        description: 'Hedefler, kilometre taşları ve vizyon',
        icon: 'target',
        tone: 'accent',
        badgeBg: 'section',
        route: '/main/goals',
      },
      {
        id: 'content',
        label: 'Content planner',
        description: 'İçerik takvimi ve fikir havuzu',
        icon: 'notePencil',
        tone: 'accent',
        badgeBg: 'section',
        route: '/main/content',
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
        route: '/main/finance',
      },
      {
        id: 'workout',
        label: 'Workout',
        description: 'Antrenman ve egzersiz programları',
        icon: 'barbell',
        tone: 'accent',
        badgeBg: 'section',
        route: '/main/workout',
      },
      {
        id: 'learning',
        label: 'Learning',
        description: 'Dersler, okuma listeleri ve notlar',
        icon: 'bookOpen',
        tone: 'accent',
        badgeBg: 'section',
        route: '/main/learning',
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
        route: '/main/analytics',
      },
      {
        id: 'reports',
        label: 'Reports',
        description: 'Detaylı aktivite ve performans özetleri',
        icon: 'fileText',
        tone: 'accent',
        badgeBg: 'section',
        route: '/main/reports',
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
  const { openConfigModal } = useNavBar();

  return (
    <AppScreen tab="more">
      <PageHeaderGradient tab="more">
        <View style={{ gap: spacing.xs }}>
          <AppText variant="h2">More</AppText>
          <AppText tone="muted">Tüm yardımcı modüller ve tercihler tek merkezde.</AppText>
        </View>
      </PageHeaderGradient>

      {/* QUICK NAVBAR CUSTOMIZATION PROMPT */}
      <TouchableOpacity
        activeOpacity={0.8}
        onPress={() => openConfigModal()}
        style={{
          backgroundColor: colors.surfaceElevated,
          borderRadius: radius.card,
          borderWidth: 1,
          borderColor: colors.border,
          padding: spacing.md,
          flexDirection: 'row',
          alignItems: 'center',
          gap: spacing.sm,
        }}
      >
        <View
          style={{
            width: 42,
            height: 42,
            borderRadius: radius.md,
            backgroundColor: colors.section,
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <AppIcon name="slidersHorizontal" filled tone="accent" size={20} />
        </View>
        <View style={{ flex: 1, gap: 2 }}>
          <AppText variant="title">Alt Barı Özelleştir</AppText>
          <AppText tone="muted" variant="caption">
            4 takip alanını düzenle (More butonuna basılı tutarak da açabilirsin)
          </AppText>
        </View>
        <AppIcon name="caretRight" tone="muted" size={16} />
      </TouchableOpacity>

      {groups.map((group) => (
        <View key={group.title} style={{ gap: spacing.sm }}>
          <Kicker>{group.title}</Kicker>
          <View style={{ gap: spacing.sm }}>
            {group.items.map((item) => (
              <ListItemRow
                key={item.id}
                title={item.label}
                subtitle={item.description}
                onPress={() => {
                  if (item.onPress) {
                    item.onPress();
                  } else if (item.route) {
                    router.push(item.route);
                  }
                }}
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
