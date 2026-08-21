import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/reminder.dart';

abstract class ReminderRepository {
  Stream<List<ReminderItem>> watchReminders();
  Future<void> saveReminder({
    required String? id,
    required String title,
    required String message,
    required DateTime? dueAt,
    required ReminderStatus status,
  });

  Future<void> deleteReminder(String id);
}

class FirestoreReminderRepository implements ReminderRepository {
  FirestoreReminderRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _remindersRef =>
      _firestore.collection('users').doc(_uid).collection('reminders');

  @override
  Stream<List<ReminderItem>> watchReminders() {
    return _remindersRef
        .orderBy('dueAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReminderItem.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> saveReminder({
    required String? id,
    required String title,
    required String message,
    required DateTime? dueAt,
    required ReminderStatus status,
  }) async {
    final data = {
      'title': title,
      'message': message,
      'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt),
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (id == null) {
      await _remindersRef.add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _remindersRef.doc(id).set({
        ...data,
        // Re-arms the reminder alert. `notifiedAt` is the idempotency marker
        // written by the sendDueReminders scheduled function, and this write
        // merges — so without clearing it, a reminder moved to a later time
        // would keep the marker from its old one and never fire again.
        // Cleared on every edit rather than only when dueAt changes: editing
        // a reminder at all is reason enough to let it notify again, and one
        // that isn't `scheduled` is skipped by the sender anyway.
        //
        // Only on this branch — FieldValue.delete() is rejected by add() and
        // by a set() without merge.
        'notifiedAt': FieldValue.delete(),
      }, SetOptions(merge: true));
    }
  }

  @override
  Future<void> deleteReminder(String id) async {
    await _remindersRef.doc(id).delete();
  }
}
