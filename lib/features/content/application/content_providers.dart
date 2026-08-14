import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/firestore_content_repository.dart';
import '../domain/content_item.dart';
import '../domain/content_repository.dart';

// Module streams below are `autoDispose`: each is watched only by its own
// screen, so the Firestore listener closes when the user navigates away
// instead of staying open for the rest of the session. Nothing outside the
// widget tree watches them, which is what makes this safe — a non-autoDispose
// provider cannot watch an autoDispose one.
final contentRepositoryProvider = Provider.autoDispose<ContentRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return FirestoreContentRepository(ref.watch(firestoreProvider), uid);
});

final contentItemsProvider = StreamProvider.autoDispose<List<ContentItem>>((ref) {
  final repository = ref.watch(contentRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchItems();
});

class ContentActions {
  ContentActions(this._ref);

  final Ref _ref;

  Future<void> saveItem({
    String? id,
    required String title,
    required String platform,
    required DateTime? publishDate,
    required ContentStatus status,
  }) async {
    final repository = _ref.read(contentRepositoryProvider);
    if (repository == null) return;
    await repository.saveItem(
      id: id,
      title: title,
      platform: platform,
      publishDate: publishDate,
      status: status,
    );
  }

  Future<void> deleteItem(String itemId) async {
    final repository = _ref.read(contentRepositoryProvider);
    if (repository == null) return;
    await repository.deleteItem(itemId);
  }
}

final contentActionsProvider = Provider<ContentActions>((ref) => ContentActions(ref));
