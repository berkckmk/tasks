import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/firestore_learning_repository.dart';
import '../domain/learning_item.dart';
import '../domain/learning_repository.dart';

// Module streams below are `autoDispose`: each is watched only by its own
// screen, so the Firestore listener closes when the user navigates away
// instead of staying open for the rest of the session. Nothing outside the
// widget tree watches them, which is what makes this safe — a non-autoDispose
// provider cannot watch an autoDispose one.
final learningRepositoryProvider = Provider.autoDispose<LearningRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return FirestoreLearningRepository(ref.watch(firestoreProvider), uid);
});

final learningItemsProvider = StreamProvider.autoDispose<List<LearningItem>>((ref) {
  final repository = ref.watch(learningRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchItems();
});

class LearningActions {
  LearningActions(this._ref);

  final Ref _ref;

  Future<void> saveItem({
    String? id,
    required String title,
    required LearningType type,
    required LearningStatus status,
    required int rating,
    required String notes,
    required List<String> keyTakeaways,
  }) async {
    final repository = _ref.read(learningRepositoryProvider);
    if (repository == null) return;
    await repository.saveItem(
      id: id,
      title: title,
      type: type,
      status: status,
      rating: rating,
      notes: notes,
      keyTakeaways: keyTakeaways,
    );
  }

  Future<void> deleteItem(String itemId) async {
    final repository = _ref.read(learningRepositoryProvider);
    if (repository == null) return;
    await repository.deleteItem(itemId);
  }
}

final learningActionsProvider = Provider<LearningActions>((ref) => LearningActions(ref));
