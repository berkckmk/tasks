import 'content_item.dart';

abstract class ContentRepository {
  Stream<List<ContentItem>> watchItems();

  Future<void> saveItem({
    required String? id,
    required String title,
    required String platform,
    required DateTime? publishDate,
    required ContentStatus status,
  });

  Future<void> deleteItem(String itemId);
}
