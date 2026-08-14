import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore's hard limit on operations in a single [WriteBatch].
const int kFirestoreBatchLimit = 500;

/// Deletes every reference in [references], committing in chunks that stay
/// under Firestore's 500-operation batch limit.
///
/// The cleanup paths that delete a habit's logs (or a workout's exercise
/// logs) used to build one batch for the whole result set. Nothing prunes
/// those collections, so a habit tracked daily passes 500 logs in under two
/// years — at which point `commit()` threw `INVALID_ARGUMENT` and *every*
/// delete for that habit failed, permanently.
///
/// Chunks are committed sequentially rather than in parallel so a partial
/// failure leaves a prefix deleted rather than an arbitrary scatter, and so
/// a large cleanup doesn't burst Firestore's write throughput.
Future<void> deleteAllInBatches(
  FirebaseFirestore firestore,
  Iterable<DocumentReference<Object?>> references,
) async {
  final all = references.toList();
  for (var start = 0; start < all.length; start += kFirestoreBatchLimit) {
    final end = (start + kFirestoreBatchLimit).clamp(0, all.length);
    final batch = firestore.batch();
    for (final reference in all.sublist(start, end)) {
      batch.delete(reference);
    }
    await batch.commit();
  }
}
