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
} as const;

export function getTabGradient(key: string) {
  const k = key.toLowerCase();
  if (k === 'reminders' || k.includes('hatırlat') || k.includes('hatirlat')) return tabGradients.reminders;
  if (k === 'habits' || k.includes('alışkanlık') || k.includes('aliskanlik')) return tabGradients.habits;
  if (k === 'tasks' || k.includes('görev') || k.includes('gorev')) return tabGradients.tasks;
  if (k === 'content' || k.includes('i̇çerik') || k.includes('icerik')) return tabGradients.content;
  if (k === 'more' || k.includes('goal') || k.includes('hedef') || k.includes('workout') || k.includes('learn') || k.includes('öğren') || k.includes('ogren') || k.includes('finance') || k.includes('finans') || k.includes('analytic') || k.includes('report')) return tabGradients.more;
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
  if (k === 'more' || k.includes('goal') || k.includes('hedef') || k.includes('workout') || k.includes('learn') || k.includes('öğren') || k.includes('ogren') || k.includes('finance') || k.includes('finans') || k.includes('analytic') || k.includes('report')) return tabColors.more;
  if (k === 'index' || k === 'today' || k.includes('bugün') || k.includes('bugun')) return tabColors.today;
  return tabColors.today;
}

export function getTabActiveColor(key: string): string {
  const k = key.toLowerCase();
  if (k === 'reminders' || k.includes('hatırlat') || k.includes('hatirlat')) return tabActiveColors.reminders;
  if (k === 'habits' || k.includes('alışkanlık') || k.includes('aliskanlik')) return tabActiveColors.habits;
  if (k === 'tasks' || k.includes('görev') || k.includes('gorev')) return tabActiveColors.tasks;
  if (k === 'content' || k.includes('i̇çerik') || k.includes('icerik')) return tabActiveColors.content;
  if (k === 'more' || k.includes('goal') || k.includes('hedef') || k.includes('workout') || k.includes('learn') || k.includes('öğren') || k.includes('ogren') || k.includes('finance') || k.includes('finans') || k.includes('analytic') || k.includes('report')) return tabActiveColors.more;
  if (k === 'index' || k === 'today' || k.includes('bugün') || k.includes('bugun')) return tabActiveColors.today;
  return tabActiveColors.today;
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
