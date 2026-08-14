import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/query_limits.dart';
import '../domain/content_item.dart';
import '../domain/content_repository.dart';

class FirestoreContentRepository implements ContentRepository {
  FirestoreContentRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _itemsRef =>
      _firestore.collection('users').doc(_uid).collection('content_items');

  @override
  Stream<List<ContentItem>> watchItems() {
    return _itemsRef.orderBy('createdAt', descending: true).limit(kListPageLimit).snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => ContentItem.fromFirestore(doc.id, doc.data())).toList(),
        );
  }

  @override
  Future<void> saveItem({
    required String? id,
    required String title,
    required String platform,
    required DateTime? publishDate,
    required ContentStatus status,
  }) async {
    final data = ContentItem(
      id: id ?? '',
      title: title,
      platform: platform,
      publishDate: publishDate,
      status: status,
    ).toFirestore();

    if (id == null) {
      await _itemsRef.add({...data, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await _itemsRef.doc(id).set(data, SetOptions(merge: true));
    }
  }

  @override
  Future<void> deleteItem(String itemId) async {
    await _itemsRef.doc(itemId).delete();
  }
}
