import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/callable_service.dart';
import '../../../core/firebase/query_limits.dart';
import '../../../core/firebase/firestore_batch.dart';
import '../domain/habit.dart';
import '../domain/habit_log.dart';
import '../domain/habit_repository.dart';
import '../domain/habit_status.dart' show formatLogDate;

class FirestoreHabitRepository implements HabitRepository {
  FirestoreHabitRepository(this._firestore, this._callables, this._uid);

  final FirebaseFirestore _firestore;
  final CallableService _callables;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _habitsRef =>
      _firestore.collection('users').doc(_uid).collection('habits');

  CollectionReference<Map<String, dynamic>> get _logsRef =>
      _firestore.collection('users').doc(_uid).collection('habit_logs');

  @override
  Stream<List<Habit>> watchHabits() {
    return _habitsRef.orderBy('createdAt').limit(kListPageLimit).snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => Habit.fromFirestore(doc.id, doc.data())).toList(),
        );
  }

  @override
  Stream<List<HabitLog>> watchRecentLogs({int days = 60}) {
    final cutoff = formatLogDate(DateTime.now().subtract(Duration(days: days)));
    return _logsRef.where('date', isGreaterThanOrEqualTo: cutoff).snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => HabitLog.fromFirestore(doc.id, doc.data())).toList(),
        );
  }

  @override
  Future<void> saveHabit({
    required String? id,
    required String name,
    required HabitCategory category,
    required String frequencyLabel,
    required int colorValue,
    String? reminderTimeLabel,
  }) async {
    if (id == null) {
      // Creation goes through the createHabit Cloud Function, not a direct
      // Firestore write — firestore.rules denies `create` on this
      // collection outright. This is the only way the Starter plan's
      // 3-habit limit can be enforced server-side (rules can't count a
      // collection's size). See functions/src/habits/createHabit.ts.
      await _callables.call('createHabit', {
        'name': name,
        'category': category.name,
        'frequencyLabel': frequencyLabel,
        'colorValue': colorValue,
        'reminderTimeLabel': reminderTimeLabel,
      });
      return;
    }

    final data = {
      'name': name,
      'category': category.name,
      'frequencyLabel': frequencyLabel,
      'colorValue': colorValue,
      'reminderTimeLabel': reminderTimeLabel,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _habitsRef.doc(id).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> deleteHabit(String habitId) async {
    // Logs first, habit last. The habit document is what makes this habit
    // visible and re-deletable; deleting it first meant that if the log
    // cleanup then failed (offline, rules, or the batch limit below), the
    // habit was already gone and its logs were orphaned with no way to
    // retry.
    final orphanedLogs = await _logsRef.where('habitId', isEqualTo: habitId).get();
    await deleteAllInBatches(_firestore, orphanedLogs.docs.map((doc) => doc.reference));

    await _habitsRef.doc(habitId).delete();
  }

  @override
  Future<void> setCompletionToday(String habitId, bool completed) async {
    final date = formatLogDate(DateTime.now());
    final logId = '${habitId}_$date';
    if (completed) {
      await _logsRef.doc(logId).set(
            HabitLog(id: logId, habitId: habitId, date: date, completed: true).toFirestore(),
          );
    } else {
      await _logsRef.doc(logId).delete();
    }
  }

  @override
  Future<void> setSyncEnabled(String habitId, bool enabled) async {
    await _habitsRef.doc(habitId).update({'syncEnabled': enabled});
  }
}
