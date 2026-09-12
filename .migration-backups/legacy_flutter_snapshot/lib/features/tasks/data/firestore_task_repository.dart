import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/callable_service.dart';
import '../../../core/firebase/query_limits.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';

class FirestoreTaskRepository implements TaskRepository {
  FirestoreTaskRepository(this._firestore, this._callables, this._uid);

  final FirebaseFirestore _firestore;
  final CallableService _callables;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _tasksRef =>
      _firestore.collection('users').doc(_uid).collection('tasks');

  @override
  Stream<List<TaskItem>> watchTasks() {
    return _tasksRef.orderBy('createdAt', descending: true).limit(kListPageLimit).snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => TaskItem.fromFirestore(doc.id, doc.data())).toList(),
        );
  }

  @override
  Future<void> saveTask({
    required String? id,
    required String title,
    required String description,
    required DateTime? startDate,
    required DateTime? dueDate,
    required bool allDay,
    required TaskPriority priority,
    required TaskStatus status,
    required String? relatedGoalId,
  }) async {
    if (id == null) {
      // Creation goes through the createTask Cloud Function, not a direct
      // Firestore write — firestore.rules denies `create` on this
      // collection outright. This is the only way the Starter plan's
      // 20-active-task limit can be enforced server-side (rules can't
      // count a collection's size). See functions/src/tasks/createTask.ts.
      final created = await _callables.call('createTask', {
        'title': title,
        'description': description,
        'startDate': startDate?.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'allDay': allDay,
        'priority': priority.name,
        'relatedGoalId': relatedGoalId,
      });
      // The schedule fields are patched in rather than trusted to the
      // callable's response, because the deployed function can be older than
      // this repo — see docs/DEPLOYMENT_STATE.md. `update` on an existing
      // task is allowed by firestore.rules (the merged document still has a
      // title, a priority and a status), so this costs one write and works
      // against both the old function and the new one.
      final newId = (created?['id'] ?? created?['taskId']) as String?;
      if (newId != null) {
        await _tasksRef.doc(newId).set({
          'startDate': startDate == null ? null : Timestamp.fromDate(startDate),
          'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
          'allDay': allDay,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return;
    }

    final data = TaskItem(
      id: id,
      title: title,
      description: description,
      startDate: startDate,
      dueDate: dueDate,
      allDay: allDay,
      priority: priority,
      status: status,
      relatedGoalId: relatedGoalId,
    ).toFirestore();
    await _tasksRef.doc(id).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await _tasksRef.doc(taskId).delete();
  }

  @override
  Future<void> setDone(String taskId, bool done) async {
    await _tasksRef.doc(taskId).update({
      'status': (done ? TaskStatus.done : TaskStatus.todo).name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setSyncEnabled(String taskId, bool enabled) async {
    await _tasksRef.doc(taskId).update({'syncEnabled': enabled});
  }
}
