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
    this.startDate,
    this.dueDate,
    this.allDay = true,
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

  /// The first day the task is on. A task can span days — "prepare the
  /// workshop, Mon to Thu" is one task, not four — so the schedule is a range
  /// and [dueDate] is its last day. Null on a task saved before ranges
  /// existed, which reads as a single-day task on [dueDate].
  final DateTime? startDate;

  /// The last day of the range, and the deadline. Kept as the single
  /// authoritative "when is this due" because everything downstream — the
  /// Today rail, the widget, the Calendar sync function — already reads it.
  final DateTime? dueDate;

  /// No clock time was chosen, so the task is on the day rather than at a
  /// moment. Shown as "All day". Defaults true: every task written before
  /// this field existed had no time, which is exactly what all-day means.
  final bool allDay;
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

  /// The range's first day, falling back to the deadline for single-day
  /// tasks and for documents written before ranges existed.
  DateTime? get effectiveStart => startDate ?? dueDate;

  /// True when the task covers more than one day, which is the only case
  /// where a row has to print two dates instead of one.
  bool get spansDays {
    final start = startDate;
    final end = dueDate;
    if (start == null || end == null) return false;
    return !(start.year == end.year &&
        start.month == end.month &&
        start.day == end.day);
  }

  factory TaskItem.fromFirestore(String id, Map<String, dynamic> data) {
    return TaskItem(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      // Absent means all-day: every task written before the field existed
      // carried a date and no clock time.
      allDay: data['allDay'] as bool? ?? true,
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
      'startDate': startDate == null ? null : Timestamp.fromDate(startDate!),
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
      'allDay': allDay,
      'priority': priority.name,
      'status': status.name,
      'relatedGoalId': relatedGoalId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  TaskItem copyWith({
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? dueDate,
    bool? allDay,
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
      startDate: clearDueDate ? null : (startDate ?? this.startDate),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      allDay: allDay ?? this.allDay,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      relatedGoalId: clearRelatedGoal ? null : (relatedGoalId ?? this.relatedGoalId),
      syncEnabled: syncEnabled ?? this.syncEnabled,
      googleCalendarEventId: googleCalendarEventId ?? this.googleCalendarEventId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
