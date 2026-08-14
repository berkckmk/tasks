import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/task_item.dart';
import '../domain/task_repository.dart';

class FirestoreTaskRepository implements TaskRepository {
  FirestoreTaskRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _tasksRef =>
      _firestore.collection('users').doc(_uid).collection('tasks');

  @override
  Stream<List<TaskItem>> watchTasks() {
    return _tasksRef.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => TaskItem.fromFirestore(doc.id, doc.data())).toList(),
        );
  }

  @override
  Future<void> saveTask({
    required String? id,
    required String title,
    required String description,
    required DateTime? dueDate,
    required TaskPriority priority,
    required TaskStatus status,
    required String? relatedGoalId,
  }) async {
    final data = TaskItem(
      id: id ?? '',
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      status: status,
      relatedGoalId: relatedGoalId,
    ).toFirestore();

    if (id == null) {
      await _tasksRef.add({...data, 'createdAt': Timestamp.now()});
    } else {
      await _tasksRef.doc(id).set(data, SetOptions(merge: true));
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await _tasksRef.doc(taskId).delete();
  }

  @override
  Future<void> setDone(String taskId, bool done) async {
    await _tasksRef.doc(taskId).update({
      'status': (done ? TaskStatus.done : TaskStatus.todo).name,
      'updatedAt': Timestamp.now(),
    });
  }

  @override
  Future<void> setSyncEnabled(String taskId, bool enabled) async {
    await _tasksRef.doc(taskId).update({'syncEnabled': enabled});
  }
}
