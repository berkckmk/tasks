import { dateFromFirestore, enumValue } from '../../core/data/firestore-values.ts';

export const contentStatuses = ['idea', 'drafted', 'scheduled', 'published'] as const;
export const contentPlatforms = [
  'Instagram',
  'X',
  'TikTok',
  'Facebook',
  'YouTube',
  'Other',
] as const;

export type ContentStatus = typeof contentStatuses[number];
export type ContentPlatform = typeof contentPlatforms[number];

export type ContentItem = {
  id: string;
  title: string;
  platform: ContentPlatform;
  platforms: ContentPlatform[];
  publishDate: Date | null;
  status: ContentStatus;
};

export function contentItemFromDocument(id: string, data: Record<string, unknown>): ContentItem {
  const platformsArray: ContentPlatform[] = Array.isArray(data.platforms)
    ? data.platforms.filter((p): p is ContentPlatform => typeof p === 'string' && (contentPlatforms as readonly string[]).includes(p))
    : [];

  const legacyPlatform = enumValue(data.platform, contentPlatforms, 'Other');
  const resolvedPlatforms = platformsArray.length > 0 ? platformsArray : [legacyPlatform];

  return {
    id,
    title: typeof data.title === 'string' ? data.title : '',
    platform: resolvedPlatforms[0] ?? 'Other',
    platforms: resolvedPlatforms,
    publishDate: dateFromFirestore(data.publishDate),
    status: enumValue(data.status, contentStatuses, 'idea'),
  };
}
