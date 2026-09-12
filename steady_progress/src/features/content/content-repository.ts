import type { DataGateway, Unsubscribe } from '../../core/data/data-gateway.ts';
import { userCollection } from '../../core/data/data-gateway.ts';
import {
  contentItemFromDocument,
  type ContentItem,
  type ContentPlatform,
  type ContentStatus,
} from './content-item.ts';

export type SaveContentInput = {
  id?: string;
  title: string;
  platform?: ContentPlatform;
  platforms?: ContentPlatform[];
  publishDate: Date | null;
  status: ContentStatus;
};

export class ContentRepository {
  private readonly gateway: DataGateway;
  private readonly userId: string;

  constructor(gateway: DataGateway, userId: string) {
    this.gateway = gateway;
    this.userId = userId;
  }

  watch(onData: (items: ContentItem[]) => void, onError: (error: unknown) => void): Unsubscribe {
    return this.gateway.watchCollection(
      userCollection(this.userId, 'content_items'),
      { orderBy: { field: 'createdAt', direction: 'desc' }, limit: 200 },
      (rows) => onData(rows.map((row) => contentItemFromDocument(row.id, row.data))),
      onError,
    );
  }

  async save(input: SaveContentInput): Promise<string> {
    const collection = userCollection(this.userId, 'content_items');
    const resolvedPlatforms = (input.platforms && input.platforms.length > 0)
      ? input.platforms
      : [input.platform ?? 'Instagram'];
    const primaryPlatform = resolvedPlatforms[0] ?? 'Other';
    const data = {
      title: input.title,
      platform: primaryPlatform,
      platforms: resolvedPlatforms,
      publishDate: input.publishDate,
      status: input.status,
      updatedAt: this.gateway.serverTimestamp(),
    };
    if (!input.id) {
      return (await this.gateway.addDocument(collection, {
        ...data,
        createdAt: this.gateway.serverTimestamp(),
      })).id;
    }
    await this.gateway.setDocument(`${collection}/${input.id}`, data, { merge: true });
    return input.id;
  }

  delete(id: string) {
    return this.gateway.deleteDocument(`${userCollection(this.userId, 'content_items')}/${id}`);
  }
}
