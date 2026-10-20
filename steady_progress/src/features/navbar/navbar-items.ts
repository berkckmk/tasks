import type { AppIconName } from '@/theme';

export type NavSlotId =
  | 'reminders'
  | 'index'
  | 'habits'
  | 'tasks'
  | 'goals'
  | 'content'
  | 'finance'
  | 'workout'
  | 'learning'
  | 'analytics'
  | 'reports'
  | 'more';

export type NavCategory = 'core' | 'plan' | 'track' | 'evaluate';

export interface NavItemConfig {
  id: NavSlotId;
  name: string;
  label: string;
  title: string;
  description: string;
  icon: AppIconName;
  category: NavCategory;
  categoryLabel: string;
  isFixed?: boolean;
}

export const DEFAULT_NAVBAR_SLOTS: [NavSlotId, NavSlotId, NavSlotId, NavSlotId] = [
  'reminders',
  'index',
  'habits',
  'tasks',
];

export const FIXED_MORE_SLOT: NavSlotId = 'more';

export const ALL_NAV_ITEMS: Record<NavSlotId, NavItemConfig> = {
  reminders: {
    id: 'reminders',
    name: 'reminders',
    label: 'Reminders',
    title: 'Hatırlatıcılar & İlaç',
    description: 'Zamanlanmış alarmlar ve günlük hatırlatmalar',
    icon: 'bell',
    category: 'core',
    categoryLabel: 'Temel',
  },
  index: {
    id: 'index',
    name: 'index',
    label: 'Today',
    title: 'Bugün & Odak',
    description: 'Günlük genel bakış, odak ve ilerleme özeti',
    icon: 'sunHorizon',
    category: 'core',
    categoryLabel: 'Temel',
  },
  habits: {
    id: 'habits',
    name: 'habits',
    label: 'Habits',
    title: 'Alışkanlıklar',
    description: 'Alışkanlık zincirleri ve günlük rutinler',
    icon: 'plant',
    category: 'plan',
    categoryLabel: 'Planla',
  },
  tasks: {
    id: 'tasks',
    name: 'tasks',
    label: 'Tasks',
    title: 'Görevler',
    description: 'Öncelikli görevler ve yapılacak işler',
    icon: 'checkSquareOffset',
    category: 'core',
    categoryLabel: 'Temel',
  },
  goals: {
    id: 'goals',
    name: 'goals',
    label: 'Goals',
    title: 'Hedefler',
    description: 'Hedefler, kilometre taşları ve vizyon takibi',
    icon: 'target',
    category: 'plan',
    categoryLabel: 'Planla',
  },
  content: {
    id: 'content',
    name: 'content',
    label: 'Content',
    title: 'İçerik Planı',
    description: 'İçerik takvimi ve fikir havuzu',
    icon: 'notePencil',
    category: 'plan',
    categoryLabel: 'Planla',
  },
  finance: {
    id: 'finance',
    name: 'finance',
    label: 'Finance',
    title: 'Finans',
    description: 'Gelir, gider ve bütçe dengesi',
    icon: 'wallet',
    category: 'track',
    categoryLabel: 'Takip et',
  },
  workout: {
    id: 'workout',
    name: 'workout',
    label: 'Workout',
    title: 'Egzersiz & Antrenman',
    description: 'Antrenman ve egzersiz programları',
    icon: 'barbell',
    category: 'track',
    categoryLabel: 'Takip et',
  },
  learning: {
    id: 'learning',
    name: 'learning',
    label: 'Learning',
    title: 'Öğrenme & Notlar',
    description: 'Dersler, okuma listeleri ve çalışma notları',
    icon: 'bookOpen',
    category: 'track',
    categoryLabel: 'Takip et',
  },
  analytics: {
    id: 'analytics',
    name: 'analytics',
    label: 'Analytics',
    title: 'Analizler',
    description: 'Haftalık ve aylık ilerleme analizleri',
    icon: 'chartLine',
    category: 'evaluate',
    categoryLabel: 'Değerlendir',
  },
  reports: {
    id: 'reports',
    name: 'reports',
    label: 'Reports',
    title: 'Raporlar',
    description: 'Detaylı aktivite ve performans özetleri',
    icon: 'fileText',
    category: 'evaluate',
    categoryLabel: 'Değerlendir',
  },
  more: {
    id: 'more',
    name: 'more',
    label: 'More',
    title: 'Daha Fazla',
    description: 'Tüm yardımcı modüller ve tercihler',
    icon: 'dotsThreeCircle',
    category: 'core',
    categoryLabel: 'Sabit',
    isFixed: true,
  },
};

/** All selectable tracking items (excluding fixed 'more') */
export const SELECTABLE_TRACKING_ITEMS: NavItemConfig[] = Object.values(ALL_NAV_ITEMS).filter(
  (item) => !item.isFixed,
);

export function isValidSlotId(id: string): id is NavSlotId {
  return id in ALL_NAV_ITEMS && id !== FIXED_MORE_SLOT;
}

export function sanitizeNavbarSlots(rawSlots: unknown): [NavSlotId, NavSlotId, NavSlotId, NavSlotId] {
  if (!Array.isArray(rawSlots)) {
    return [...DEFAULT_NAVBAR_SLOTS];
  }

  const validItems: NavSlotId[] = [];
  for (const item of rawSlots) {
    if (typeof item === 'string' && isValidSlotId(item) && !validItems.includes(item)) {
      validItems.push(item);
    }
  }

  // Fill up with defaults if fewer than 4 valid items
  for (const fallback of DEFAULT_NAVBAR_SLOTS) {
    if (validItems.length >= 4) break;
    if (!validItems.includes(fallback)) {
      validItems.push(fallback);
    }
  }

  return [validItems[0], validItems[1], validItems[2], validItems[3]];
}
