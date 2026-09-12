import 'learning_item.dart';

abstract class LearningRepository {
  Stream<List<LearningItem>> watchItems();

  Future<void> saveItem({
    required String? id,
    required String title,
    required LearningType type,
    required LearningStatus status,
    required int rating,
    required String notes,
    required List<String> keyTakeaways,
  });

  Future<void> deleteItem(String itemId);
}
