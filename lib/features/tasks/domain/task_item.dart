import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

enum TaskPriority { low, medium, high }

extension TaskPriorityLabel on TaskPriority {
  String get label => switch (this) {
        TaskPriority.low => 'Low',
        TaskPriority.medium => 'Medium',
        TaskPriority.high => 'High',
      };

  Color get color => switch (this) {
        TaskPriority.low => AppColors.mutedBlue,
        TaskPriority.medium => AppColors.amber,
        TaskPriority.high => AppColors.error,
      };
}

enum TaskStatus { todo, inProgress, done }

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    this.description = '',
    this.dueDate,
    required this.priority,
    required this.status,
    this.relatedGoalId,
    this.syncEnabled = false,
    this.googleCalendarEventId,
    this.lastSyncedAt,
  });

  final String id;
  final String title;
  final String description;
  final DateTime? dueDate;
  final TaskPriority priority;
  final TaskStatus status;
  final String? relatedGoalId;

  /// User opt-in to sync this task's due date to Google Calendar. The
  /// actual event is created/updated by a Cloud Function (see
  /// functions/src/google/calendar.ts), which then fills in
  /// [googleCalendarEventId] and [lastSyncedAt] — the client only ever
  /// requests sync, it doesn't call the Calendar API itself.
  final bool syncEnabled;
  final String? googleCalendarEventId;
  final DateTime? lastSyncedAt;

  bool get isDone => status == TaskStatus.done;

  factory TaskItem.fromFirestore(String id, Map<String, dynamic> data) {
    return TaskItem(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      priority: TaskPriority.values.firstWhere(
        (p) => p.name == data['priority'],
        orElse: () => TaskPriority.medium,
      ),
      status: TaskStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => TaskStatus.todo,
      ),
      relatedGoalId: data['relatedGoalId'] as String?,
      syncEnabled: data['syncEnabled'] as bool? ?? false,
      googleCalendarEventId: data['googleCalendarEventId'] as String?,
      lastSyncedAt: (data['lastSyncedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Deliberately omits syncEnabled/googleCalendarEventId/lastSyncedAt —
  /// those are updated through their own targeted repository methods
  /// (TaskRepository.setSyncEnabled; the event id/synced-at are Cloud
  /// Function-owned), so that saving an ordinary field edit here can never
  /// accidentally clobber sync state.
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
      'priority': priority.name,
      'status': status.name,
      'relatedGoalId': relatedGoalId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  TaskItem copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    bool clearDueDate = false,
    TaskPriority? priority,
    TaskStatus? status,
    String? relatedGoalId,
    bool clearRelatedGoal = false,
    bool? syncEnabled,
    String? googleCalendarEventId,
    DateTime? lastSyncedAt,
  }) {
    return TaskItem(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      priority: priority ?? this.priority,
      status: status ?? this.status,
      relatedGoalId: clearRelatedGoal ? null : (relatedGoalId ?? this.relatedGoalId),
      syncEnabled: syncEnabled ?? this.syncEnabled,
      googleCalendarEventId: googleCalendarEventId ?? this.googleCalendarEventId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
