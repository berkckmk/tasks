import assert from 'node:assert/strict';
import test from 'node:test';
import { MemoryDataGateway } from '../../core/data/memory-data-gateway.ts';
import { contentItemFromDocument, type ContentItem } from './content-item.ts';
import { ContentRepository } from './content-repository.ts';

test('content documents preserve Flutter defaults for malformed legacy values', () => {
  const item = contentItemFromDocument('content-1', {
    title: 'Plan',
    platform: 'Unknown platform',
    status: 'unknown',
  });
  assert.equal(item.platform, 'Other');
  assert.equal(item.status, 'idea');
  assert.equal(item.publishDate, null);
});

test('content repository creates, edits and deletes through the common gateway', async () => {
  const gateway = new MemoryDataGateway('preview-user');
  const repository = new ContentRepository(gateway, 'preview-user');
  let visible: ContentItem[] = [];
  const stop = repository.watch(
    (items) => { visible = items; },
    (error) => assert.fail(String(error)),
  );
  const publishDate = new Date(2026, 8, 20);

  const id = await repository.save({
    title: 'Launch video',
    platform: 'YouTube',
    platforms: ['YouTube', 'Instagram'],
    publishDate,
    status: 'scheduled',
  });
  assert.equal(visible[0].title, 'Launch video');
  assert.deepEqual(visible[0].publishDate, publishDate);
  assert.deepEqual(visible[0].platforms, ['YouTube', 'Instagram']);

  await repository.save({
    id,
    title: 'Published video',
    platform: 'YouTube',
    platforms: ['YouTube', 'TikTok', 'X'],
    publishDate,
    status: 'published',
  });
  assert.equal(visible[0].status, 'published');
  assert.deepEqual(visible[0].platforms, ['YouTube', 'TikTok', 'X']);

  await repository.delete(id);
  assert.deepEqual(visible, []);
  stop();
});
