import 'habit.dart';
import 'habit_log.dart';

abstract class HabitRepository {
  Stream<List<Habit>> watchHabits();

  /// Only the last [days] days — enough for streak calculation without
  /// pulling a user's entire history on every load.
  Stream<List<HabitLog>> watchRecentLogs({int days = 60});

  /// `id == null` creates a new habit; otherwise updates the existing one.
  Future<void> saveHabit({
    required String? id,
    required String name,
    required HabitCategory category,
    required String frequencyLabel,
    required int colorValue,
    String? reminderTimeLabel,
  });

  Future<void> deleteHabit(String habitId);

  Future<void> setCompletionToday(String habitId, bool completed);

  /// User opt-in/out of a recurring Google Calendar reminder for this
  /// habit. Does not touch googleCalendarReminderEventId/lastSyncedAt —
  /// those are written by the Cloud Function that manages the event.
  Future<void> setSyncEnabled(String habitId, bool enabled);
}
