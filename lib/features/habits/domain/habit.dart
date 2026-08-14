import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum HabitCategory { morning, evening, health, work }

extension HabitCategoryLabel on HabitCategory {
  String get label => switch (this) {
        HabitCategory.morning => 'Morning',
        HabitCategory.evening => 'Evening',
        HabitCategory.health => 'Health',
        HabitCategory.work => 'Work',
      };
}

/// `streak` and `isCompletedToday` are NOT stored on the Firestore document —
/// they're derived at read time from `users/{uid}/habit_logs` (see
/// `mergeHabitsWithLogs` in habit_status.dart). Everything else here is the
/// literal shape of `users/{uid}/habits/{habitId}`.
class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.category,
    required this.frequencyLabel,
    required this.streak,
    required this.isCompletedToday,
    required this.colorValue,
    this.reminderTimeLabel,
    this.syncEnabled = false,
    this.googleCalendarReminderEventId,
    this.lastSyncedAt,
  });

  final String id;
  final String name;
  final HabitCategory category;
  final String frequencyLabel;
  final int streak;
  final bool isCompletedToday;
  final int colorValue;
  final String? reminderTimeLabel;

  /// User opt-in to sync this habit's reminder as a recurring Google
  /// Calendar event. Created/updated server-side (see
  /// functions/src/google/calendar.ts), which fills in
  /// [googleCalendarReminderEventId] and [lastSyncedAt].
  final bool syncEnabled;
  final String? googleCalendarReminderEventId;
  final DateTime? lastSyncedAt;

  Color get color => Color(colorValue);

  factory Habit.fromFirestore(String id, Map<String, dynamic> data) {
    return Habit(
      id: id,
      name: data['name'] as String? ?? '',
      category: HabitCategory.values.firstWhere(
        (c) => c.name == data['category'],
        orElse: () => HabitCategory.morning,
      ),
      frequencyLabel: data['frequencyLabel'] as String? ?? 'Daily',
      streak: 0,
      isCompletedToday: false,
      colorValue: data['colorValue'] as int? ?? 0xFF2F5233,
      reminderTimeLabel: data['reminderTimeLabel'] as String?,
      syncEnabled: data['syncEnabled'] as bool? ?? false,
      googleCalendarReminderEventId: data['googleCalendarReminderEventId'] as String?,
      lastSyncedAt: (data['lastSyncedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Only the static fields are persisted here — streak/isCompletedToday are
  /// derived, and syncEnabled/googleCalendarReminderEventId/lastSyncedAt are
  /// updated through their own targeted repository methods so an ordinary
  /// edit can never accidentally clobber sync state.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category.name,
      'frequencyLabel': frequencyLabel,
      'colorValue': colorValue,
      'reminderTimeLabel': reminderTimeLabel,
      'updatedAt': Timestamp.now(),
    };
  }

  Habit copyWith({
    String? name,
    HabitCategory? category,
    String? frequencyLabel,
    int? streak,
    bool? isCompletedToday,
    int? colorValue,
    String? reminderTimeLabel,
    bool? syncEnabled,
    String? googleCalendarReminderEventId,
    DateTime? lastSyncedAt,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      frequencyLabel: frequencyLabel ?? this.frequencyLabel,
      streak: streak ?? this.streak,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
      colorValue: colorValue ?? this.colorValue,
      reminderTimeLabel: reminderTimeLabel ?? this.reminderTimeLabel,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      googleCalendarReminderEventId:
          googleCalendarReminderEventId ?? this.googleCalendarReminderEventId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
