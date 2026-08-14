import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/query_limits.dart';
import '../domain/learning_item.dart';
import '../domain/learning_repository.dart';

class FirestoreLearningRepository implements LearningRepository {
  FirestoreLearningRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _itemsRef =>
      _firestore.collection('users').doc(_uid).collection('learning_items');

  @override
  Stream<List<LearningItem>> watchItems() {
    return _itemsRef.orderBy('createdAt', descending: true).limit(kListPageLimit).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => LearningItem.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> saveItem({
    required String? id,
    required String title,
    required LearningType type,
    required LearningStatus status,
    required int rating,
    required String notes,
    required List<String> keyTakeaways,
  }) async {
    final data = LearningItem(
      id: id ?? '',
      title: title,
      type: type,
      status: status,
      rating: rating,
      notes: notes,
      keyTakeaways: keyTakeaways,
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
