import type { TextStyle } from 'react-native';

export const fonts = {
  regular: 'Inter-Regular',
  medium: 'Inter-Medium',
  semibold: 'Inter-SemiBold',
  bold: 'Inter-Bold',
} as const;

const tabular: Pick<TextStyle, 'fontVariant'> = { fontVariant: ['tabular-nums'] };

/** Exact Nocturne type roles. Headings stay at medium weight. */
export const typography = {
  display: { fontFamily: fonts.medium, fontSize: 44, lineHeight: 46, letterSpacing: -0.66 },
  displaySmall: { fontFamily: fonts.medium, fontSize: 36, lineHeight: 40, letterSpacing: -0.54 },
  h2: { fontFamily: fonts.medium, fontSize: 30, lineHeight: 35, letterSpacing: -0.45 },
  numeral: { fontFamily: fonts.medium, fontSize: 34, lineHeight: 34, letterSpacing: -0.51, ...tabular },
  h3: { fontFamily: fonts.medium, fontSize: 25, lineHeight: 30, letterSpacing: -0.375 },
  h4: { fontFamily: fonts.medium, fontSize: 26, lineHeight: 31, letterSpacing: -0.39, ...tabular },
  h5: { fontFamily: fonts.medium, fontSize: 19, lineHeight: 24, letterSpacing: -0.285 },
  title: { fontFamily: fonts.medium, fontSize: 15, lineHeight: 20 },
  body: { fontFamily: fonts.regular, fontSize: 15, lineHeight: 22 },
  bodySmall: { fontFamily: fonts.regular, fontSize: 14, lineHeight: 21 },
  note: { fontFamily: fonts.regular, fontSize: 12.5, lineHeight: 19 },
  caption: { fontFamily: fonts.regular, fontSize: 13, lineHeight: 18 },
  meta: { fontFamily: fonts.regular, fontSize: 12, lineHeight: 15, ...tabular },
  metaSmall: { fontFamily: fonts.regular, fontSize: 11, lineHeight: 14, ...tabular },
  kicker: { fontFamily: fonts.medium, fontSize: 11, lineHeight: 14, letterSpacing: 1.1 },
  kickerSmall: { fontFamily: fonts.medium, fontSize: 9, lineHeight: 11, letterSpacing: 1.17 },
  tabLabel: { fontFamily: fonts.regular, fontSize: 10, lineHeight: 12 },
  navLabel: { fontFamily: fonts.semibold, fontSize: 13.5, lineHeight: 18, letterSpacing: 0.15 },
} as const satisfies Record<string, TextStyle>;

export type TypographyVariant = keyof typeof typography;
