import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/firebase/callable_service.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/firestore_task_repository.dart';
import '../domain/task_item.dart';
import '../domain/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return FirestoreTaskRepository(ref.watch(firestoreProvider), ref.watch(callableServiceProvider), uid);
});

final tasksProvider = StreamProvider<List<TaskItem>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchTasks();
});

class TaskActions {
  TaskActions(this._ref);

  final Ref _ref;

  Future<void> setDone(String taskId, bool done) async {
    final repository = _ref.read(taskRepositoryProvider);
    if (repository == null) return;
    await repository.setDone(taskId, done);
    if (done) {
      await _ref.read(analyticsServiceProvider).logTaskCompleted();
    }
  }

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
    final repository = _ref.read(taskRepositoryProvider);
    if (repository == null) return;
    await repository.saveTask(
      id: id,
      title: title,
      description: description,
      startDate: startDate,
      dueDate: dueDate,
      allDay: allDay,
      priority: priority,
      status: status,
      relatedGoalId: relatedGoalId,
    );
  }

  Future<void> deleteTask(String taskId) async {
    final repository = _ref.read(taskRepositoryProvider);
    if (repository == null) return;
    await repository.deleteTask(taskId);
  }

  Future<void> setSyncEnabled(String taskId, bool enabled) async {
    final repository = _ref.read(taskRepositoryProvider);
    if (repository == null) return;
    await repository.setSyncEnabled(taskId, enabled);
  }
}

final taskActionsProvider = Provider<TaskActions>((ref) => TaskActions(ref));
