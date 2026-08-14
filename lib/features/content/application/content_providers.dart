import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/firestore_content_repository.dart';
import '../domain/content_item.dart';
import '../domain/content_repository.dart';

final contentRepositoryProvider = Provider<ContentRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return FirestoreContentRepository(ref.watch(firestoreProvider), uid);
});

final contentItemsProvider = StreamProvider<List<ContentItem>>((ref) {
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
