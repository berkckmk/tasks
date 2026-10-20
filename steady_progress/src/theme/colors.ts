/**
 * Global Neutral Palette: Warm Stone, Beige, Off-White (75–85% of UI).
 * Controlled dark anchoring element for the floating navbar (~5% of UI).
 * Page-specific accents for Reminders, Today, Habits, Tasks, More (10–20% of UI).
 */
export const colors = {
  // Global Warm Stone Neutral Palette
  background: '#E8E4DC',
  backgroundSoft: '#F0ECE5',
  surface: '#F5F1EA',
  surfaceElevated: '#FAF7F1',
  surfaceMuted: '#DDD7CD',

  border: '#C9C2B7',
  divider: '#D6D0C6',

  text: '#292724',
  note: '#6F6A63',
  muted: '#6F6A63',
  caption: '#969087',
  inactive: '#969087',
  faint: '#969087',
  chevron: '#969087',
  unchecked: '#C9C2B7',

  inkAccent: '#6F6A63',
  // Note: Purple is NEVER a global accent color. Reminders only uses tabReminders.
  accent: '#292724',

  edgeSm: '#C9C2B7',
  edgeMd: '#B8B0A2',
  edgeLg: '#969087',
  error: '#D9485C',
  scrim: 'rgba(41, 39, 36, 0.45)',
  transparent: 'transparent',

  // Warm Light Stone Floating Navbar (Beige / Warm Sand)
  navBackground: '#FAF6EF',
  navInactive: '#7D766C',
  navBorder: '#DED8CE',

  // Neutral scale
  neutral100: '#FAF7F1',
  neutral200: '#F5F1EA',
  neutral300: '#F0ECE5',
  neutral400: '#E8E4DC',
  neutral500: '#DDD7CD',
  neutral600: '#969087',
  neutral700: '#6F6A63',
  neutral800: '#423F3A',
  neutral900: '#292724',
  section: '#F0ECE5',

  // Page-Specific Accent Colors
  tabReminders: '#9E86FF',
  tabToday: '#FFB986',
  tabHabits: '#86E6B0',
  tabTasks: '#FF86EC',
  tabMore: '#86DBFF',
  tabContent: '#D97A53',
} as const;

export const tabColors = {
  reminders: '#9E86FF',
  today: '#FFB986',
  habits: '#86E6B0',
  tasks: '#FF86EC',
  more: '#86DBFF',
  content: '#D97A53',
  goals: '#48CAE4',
  finance: '#2EC4B6',
  workout: '#FF9F1C',
  learning: '#8338EC',
  analytics: '#3A86FF',
  reports: '#06D6A0',
} as const;

export type TabKey = keyof typeof tabColors;

/** Rich, high-contrast foreground tones for active elements on light surfaces */
export const tabActiveColors = {
  reminders: '#6242DE',
  today: '#C2561A',
  habits: '#1B7A48',
  tasks: '#B32598',
  more: '#147294',
  content: '#B04E24',
  goals: '#0077B6',
  finance: '#0E7490',
  workout: '#C2561A',
  learning: '#5A189A',
  analytics: '#1D4ED8',
  reports: '#0F7A5E',
} as const;

export function hexToRgba(hex: string, alpha: number): string {
  const clean = hex.replace('#', '');
  const r = parseInt(clean.substring(0, 2), 16);
  const g = parseInt(clean.substring(2, 4), 16);
  const b = parseInt(clean.substring(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

export const tabGradients = {
  reminders: {
    pill: ['rgba(158, 134, 255, 0.45)', 'rgba(158, 134, 255, 0.05)'] as const,
    header: ['rgba(158, 134, 255, 0.24)', 'rgba(158, 134, 255, 0.08)', 'rgba(232, 228, 220, 0.0)'] as const,
    atmosphere: ['rgba(158, 134, 255, 0.18)', 'rgba(158, 134, 255, 0.05)', 'rgba(232, 228, 220, 0.0)'] as const,
    fab: ['rgba(158, 134, 255, 0.50)', 'rgba(158, 134, 255, 0.18)'] as const,
  },
  today: {
    pill: ['rgba(255, 185, 134, 0.45)', 'rgba(255, 185, 134, 0.05)'] as const,
    header: ['rgba(255, 185, 134, 0.26)', 'rgba(255, 185, 134, 0.09)', 'rgba(232, 228, 220, 0.0)'] as const,
    atmosphere: ['rgba(255, 185, 134, 0.22)', 'rgba(255, 185, 134, 0.06)', 'rgba(232, 228, 220, 0.0)'] as const,
    fab: ['rgba(255, 185, 134, 0.55)', 'rgba(255, 185, 134, 0.20)'] as const,
  },
  habits: {
    pill: ['rgba(134, 230, 176, 0.45)', 'rgba(134, 230, 176, 0.05)'] as const,
    header: ['rgba(134, 230, 176, 0.26)', 'rgba(134, 230, 176, 0.09)', 'rgba(232, 228, 220, 0.0)'] as const,
    atmosphere: ['rgba(134, 230, 176, 0.22)', 'rgba(134, 230, 176, 0.06)', 'rgba(232, 228, 220, 0.0)'] as const,
    fab: ['rgba(134, 230, 176, 0.55)', 'rgba(134, 230, 176, 0.20)'] as const,
  },
  tasks: {
    pill: ['rgba(255, 134, 236, 0.45)', 'rgba(255, 134, 236, 0.05)'] as const,
    header: ['rgba(255, 134, 236, 0.24)', 'rgba(255, 134, 236, 0.08)', 'rgba(232, 228, 220, 0.0)'] as const,
    atmosphere: ['rgba(255, 134, 236, 0.18)', 'rgba(255, 134, 236, 0.05)', 'rgba(232, 228, 220, 0.0)'] as const,
    fab: ['rgba(255, 134, 236, 0.50)', 'rgba(255, 134, 236, 0.18)'] as const,
  },
  more: {
    pill: ['rgba(134, 219, 255, 0.45)', 'rgba(134, 219, 255, 0.05)'] as const,
    header: ['rgba(134, 219, 255, 0.26)', 'rgba(134, 219, 255, 0.09)', 'rgba(232, 228, 220, 0.0)'] as const,
    atmosphere: ['rgba(134, 219, 255, 0.20)', 'rgba(134, 219, 255, 0.06)', 'rgba(232, 228, 220, 0.0)'] as const,
    fab: ['rgba(134, 219, 255, 0.55)', 'rgba(134, 219, 255, 0.20)'] as const,
  },
  content: {
    pill: ['rgba(217, 122, 83, 0.45)', 'rgba(217, 122, 83, 0.05)'] as const,
    header: ['rgba(217, 122, 83, 0.26)', 'rgba(217, 122, 83, 0.09)', 'rgba(232, 228, 220, 0.0)'] as const,
    atmosphere: ['rgba(217, 122, 83, 0.22)', 'rgba(217, 122, 83, 0.06)', 'rgba(232, 228, 220, 0.0)'] as const,
    fab: ['rgba(217, 122, 83, 0.55)', 'rgba(217, 122, 83, 0.20)'] as const,
  },
  goals: {
    pill: ['rgba(72, 202, 228, 0.45)', 'rgba(72, 202, 228, 0.05)'] as const,
    header: ['rgba(72, 202, 228, 0.26)', 'rgba(72, 202, 228, 0.09)', 'rgba(232, 228, 220, 0.0)'] as const,
    atmosphere: ['rgba(72, 202, 228, 0.20)', 'rgba(72, 202, 228, 0.06)', 'rgba(232, 228, 220, 0.0)'] as const,
    fab: ['rgba(72, 202, 228, 0.55)', 'rgba(72, 202, 228, 0.20)'] as const,
  },
  finance: {
    pill: ['rgba(46, 196, 182, 0.45)', 'rgba(46, 196, 182, 0.05)'] as const,
    header: ['rgba(46, 196, 182, 0.26)', 'rgba(46, 196, 182, 0.09)', 'rgba(232, 228, 220, 0.0)'] as const,
    atmosphere: ['rgba(46, 196, 182, 0.20)', 'rgba(46, 196, 182, 0.06)', 'rgba(232, 228, 220, 0.0)'] as const,
    fab: ['rgba(46, 196, 182, 0.55)', 'rgba(46, 196, 182, 0.20)'] as const,
  },
  workout: {
    pill: ['rgba(255, 159, 28, 0.45)', 'rgba(255, 159, 28, 0.05)'] as const,
    header: ['rgba(255, 159, 28, 0.26)', 'rgba(255, 159, 28, 0.09)', 'rgba(232, 228, 220, 0.0)'] as const,
    atmosphere: ['rgba(255, 159, 28, 0.20)', 'rgba(255, 159, 28, 0.06)', 'rgba(232, 228, 220, 0.0)'] as const,
    fab: ['rgba(255, 159, 28, 0.55)', 'rgba(255, 159, 28, 0.20)'] as const,
  },
  learning: {
    pill: ['rgba(131, 56, 236, 0.45)', 'rgba(131, 56, 236, 0.05)'] as const,
    header: ['rgba(131, 56, 236, 0.26)', 'rgba(131, 56, 236, 0.09)', 'rgba(232, 228, 220, 0.0)'] as const,
    atmosphere: ['rgba(131, 56, 236, 0.20)', 'rgba(131, 56, 236, 0.06)', 'rgba(232, 228, 220, 0.0)'] as const,
    fab: ['rgba(131, 56, 236, 0.55)', 'rgba(131, 56, 236, 0.20)'] as const,
  },
  analytics: {
    pill: ['rgba(58, 134, 255, 0.45)', 'rgba(58, 134, 255, 0.05)'] as const,
    header: ['rgba(58, 134, 255, 0.26)', 'rgba(58, 134, 255, 0.09)', 'rgba(232, 228, 220, 0.0)'] as const,
    atmosphere: ['rgba(58, 134, 255, 0.20)', 'rgba(58, 134, 255, 0.06)', 'rgba(232, 228, 220, 0.0)'] as const,
    fab: ['rgba(58, 134, 255, 0.55)', 'rgba(58, 134, 255, 0.20)'] as const,
  },
  reports: {
    pill: ['rgba(6, 214, 160, 0.45)', 'rgba(6, 214, 160, 0.05)'] as const,
    header: ['rgba(6, 214, 160, 0.26)', 'rgba(6, 214, 160, 0.09)', 'rgba(232, 228, 220, 0.0)'] as const,
    atmosphere: ['rgba(6, 214, 160, 0.20)', 'rgba(6, 214, 160, 0.06)', 'rgba(232, 228, 220, 0.0)'] as const,
    fab: ['rgba(6, 214, 160, 0.55)', 'rgba(6, 214, 160, 0.20)'] as const,
  },
} as const;

export function getTabGradient(key: string) {
  const k = key.toLowerCase();
  if (k === 'reminders' || k.includes('hatırlat') || k.includes('hatirlat')) return tabGradients.reminders;
  if (k === 'habits' || k.includes('alışkanlık') || k.includes('aliskanlik')) return tabGradients.habits;
  if (k === 'tasks' || k.includes('görev') || k.includes('gorev')) return tabGradients.tasks;
  if (k === 'content' || k.includes('i̇çerik') || k.includes('icerik')) return tabGradients.content;
  if (k === 'goals' || k.includes('hedef') || k === 'goal') return tabGradients.goals;
  if (k === 'finance' || k.includes('finans')) return tabGradients.finance;
  if (k === 'workout' || k.includes('antrenman') || k.includes('egzersiz')) return tabGradients.workout;
  if (k === 'learning' || k.includes('öğren') || k.includes('ogren')) return tabGradients.learning;
  if (k === 'analytics' || k.includes('analiz') || k.includes('analytic')) return tabGradients.analytics;
  if (k === 'reports' || k.includes('rapor') || k.includes('report')) return tabGradients.reports;
  if (k === 'more') return tabGradients.more;
  if (k === 'index' || k === 'today' || k.includes('bugün') || k.includes('bugun')) return tabGradients.today;
  return tabGradients.today;
}

export function getTabAtmosphere(key: string) {
  return getTabGradient(key).atmosphere;
}

export function getTabFabGradient(key: string) {
  return getTabGradient(key).fab;
}

export function getTabColor(key: string): string {
  const k = key.toLowerCase();
  if (k === 'reminders' || k.includes('hatırlat') || k.includes('hatirlat')) return tabColors.reminders;
  if (k === 'habits' || k.includes('alışkanlık') || k.includes('aliskanlik')) return tabColors.habits;
  if (k === 'tasks' || k.includes('görev') || k.includes('gorev')) return tabColors.tasks;
  if (k === 'content' || k.includes('i̇çerik') || k.includes('icerik')) return tabColors.content;
  if (k === 'goals' || k.includes('hedef') || k === 'goal') return tabColors.goals;
  if (k === 'finance' || k.includes('finans')) return tabColors.finance;
  if (k === 'workout' || k.includes('antrenman') || k.includes('egzersiz')) return tabColors.workout;
  if (k === 'learning' || k.includes('öğren') || k.includes('ogren')) return tabColors.learning;
  if (k === 'analytics' || k.includes('analiz') || k.includes('analytic')) return tabColors.analytics;
  if (k === 'reports' || k.includes('rapor') || k.includes('report')) return tabColors.reports;
  if (k === 'more') return tabColors.more;
  if (k === 'index' || k === 'today' || k.includes('bugün') || k.includes('bugun')) return tabColors.today;
  return tabColors.today;
}

export function getTabActiveColor(key: string): string {
  const k = key.toLowerCase();
  if (k === 'reminders' || k.includes('hatırlat') || k.includes('hatirlat')) return tabActiveColors.reminders;
  if (k === 'habits' || k.includes('alışkanlık') || k.includes('aliskanlik')) return tabActiveColors.habits;
  if (k === 'tasks' || k.includes('görev') || k.includes('gorev')) return tabActiveColors.tasks;
  if (k === 'content' || k.includes('i̇çerik') || k.includes('icerik')) return tabActiveColors.content;
  if (k === 'goals' || k.includes('hedef') || k === 'goal') return tabActiveColors.goals;
  if (k === 'finance' || k.includes('finans')) return tabActiveColors.finance;
  if (k === 'workout' || k.includes('antrenman') || k.includes('egzersiz')) return tabActiveColors.workout;
  if (k === 'learning' || k.includes('öğren') || k.includes('ogren')) return tabActiveColors.learning;
  if (k === 'analytics' || k.includes('analiz') || k.includes('analytic')) return tabActiveColors.analytics;
  if (k === 'reports' || k.includes('rapor') || k.includes('report')) return tabActiveColors.reports;
  if (k === 'more') return tabActiveColors.more;
  if (k === 'index' || k === 'today' || k.includes('bugün') || k.includes('bugun')) return tabActiveColors.today;
  return tabActiveColors.today;
}

/**
 * Fixed slot colors for the 5 navbar items:
 * Slot 0: Purple (Reminders tone)
 * Slot 1: Peach / Warm Orange (Today tone)
 * Slot 2: Green (Habits tone)
 * Slot 3: Pink (Tasks tone)
 * Slot 4: Cyan / Blue (More tone)
 */
export const navbarSlotColors = [
  tabColors.reminders,
  tabColors.today,
  tabColors.habits,
  tabColors.tasks,
  tabColors.more,
] as const;

export const navbarSlotActiveColors = [
  tabActiveColors.reminders,
  tabActiveColors.today,
  tabActiveColors.habits,
  tabActiveColors.tasks,
  tabActiveColors.more,
] as const;

export const navbarSlotGradients = [
  tabGradients.reminders,
  tabGradients.today,
  tabGradients.habits,
  tabGradients.tasks,
  tabGradients.more,
] as const;

export function getNavBarSlotColor(slotIndex: number): string {
  const index = Math.max(0, Math.min(slotIndex, navbarSlotColors.length - 1));
  return navbarSlotColors[index];
}

export function getNavBarSlotActiveColor(slotIndex: number): string {
  const index = Math.max(0, Math.min(slotIndex, navbarSlotActiveColors.length - 1));
  return navbarSlotActiveColors[index];
}

export function getNavBarSlotGradient(slotIndex: number) {
  const index = Math.max(0, Math.min(slotIndex, navbarSlotGradients.length - 1));
  return navbarSlotGradients[index];
}

export type ColorTone =
  | 'text'
  | 'note'
  | 'muted'
  | 'inactive'
  | 'caption'
  | 'inkAccent'
  | 'accent'
  | 'error';
