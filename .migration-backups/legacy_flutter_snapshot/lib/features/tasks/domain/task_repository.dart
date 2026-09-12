import 'task_item.dart';

abstract class TaskRepository {
  Stream<List<TaskItem>> watchTasks();

  /// `id == null` creates a new task; otherwise updates the existing one.
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
  });

  Future<void> deleteTask(String taskId);

  Future<void> setDone(String taskId, bool done);

  /// User opt-in/out of Google Calendar sync for this task. Does not touch
  /// googleCalendarEventId/lastSyncedAt — those are written by the Cloud
  /// Function that actually creates/updates the calendar event.
  Future<void> setSyncEnabled(String taskId, bool enabled);
}
