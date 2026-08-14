import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/firebase/callable_service.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/firestore_habit_repository.dart';
import '../domain/habit.dart';
import '../domain/habit_log.dart';
import '../domain/habit_repository.dart';
import '../domain/habit_status.dart';

/// Null when signed out — every provider below treats that as "nothing to
/// show" rather than crashing, since the router keeps signed-out users off
/// these screens anyway.
final habitRepositoryProvider = Provider<HabitRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return FirestoreHabitRepository(ref.watch(firestoreProvider), ref.watch(callableServiceProvider), uid);
});

/// Raw habit documents, without streak/completion derived onto them.
final rawHabitsProvider = StreamProvider<List<Habit>>((ref) {
  final repository = ref.watch(habitRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchHabits();
});

/// The last 60 days of completion logs.
///
/// Exposed as its own provider so the Analytics screen can reuse it. It used
/// to call `watchRecentLogs(days: 60)` again in its own StreamProvider,
/// which opened a second Firestore listener on the identical query — the
/// same documents streamed, and billed, twice.
final habitLogsProvider = StreamProvider<List<HabitLog>>((ref) {
  final repository = ref.watch(habitRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchRecentLogs();
});

/// Habits merged with their recent completion logs — streak and
/// isCompletedToday are already computed by the time the UI sees this.
///
/// Combining two providers here rather than two raw streams means Riverpod
/// handles the subscription lifecycle, and each underlying stream has exactly
/// one listener no matter how many things read this.
final habitsProvider = Provider<AsyncValue<List<Habit>>>((ref) {
  final habits = ref.watch(rawHabitsProvider);
  final logs = ref.watch(habitLogsProvider);
  return habits.whenData((items) => mergeHabitsWithLogs(items, logs.valueOrNull ?? const []));
});

/// Null means "All categories".
final habitFilterProvider = StateProvider<HabitCategory?>((ref) => null);

class HabitActions {
  HabitActions(this._ref);

  final Ref _ref;

  Future<void> toggleCompletionToday(String habitId, bool currentlyCompleted) async {
    final repository = _ref.read(habitRepositoryProvider);
    if (repository == null) return;
    final nowCompleted = !currentlyCompleted;
    await repository.setCompletionToday(habitId, nowCompleted);
    if (nowCompleted) {
      await _ref.read(analyticsServiceProvider).logHabitCompleted();
    }
  }

  Future<void> saveHabit({
    required String? id,
    required String name,
    required HabitCategory category,
    required String frequencyLabel,
    required int colorValue,
    String? reminderTimeLabel,
  }) async {
    final repository = _ref.read(habitRepositoryProvider);
    if (repository == null) return;
    await repository.saveHabit(
      id: id,
      name: name,
      category: category,
      frequencyLabel: frequencyLabel,
      colorValue: colorValue,
      reminderTimeLabel: reminderTimeLabel,
    );
  }

  Future<void> deleteHabit(String habitId) async {
    final repository = _ref.read(habitRepositoryProvider);
    if (repository == null) return;
    await repository.deleteHabit(habitId);
  }

  Future<void> setSyncEnabled(String habitId, bool enabled) async {
    final repository = _ref.read(habitRepositoryProvider);
    if (repository == null) return;
    await repository.setSyncEnabled(habitId, enabled);
  }
}

final habitActionsProvider = Provider<HabitActions>((ref) => HabitActions(ref));
