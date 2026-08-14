import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/utils/combine_latest.dart';
import '../../auth/application/auth_providers.dart';
import '../data/firestore_habit_repository.dart';
import '../domain/habit.dart';
import '../domain/habit_repository.dart';
import '../domain/habit_status.dart';

/// Null when signed out — every provider below treats that as "nothing to
/// show" rather than crashing, since the router keeps signed-out users off
/// these screens anyway.
final habitRepositoryProvider = Provider<HabitRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return FirestoreHabitRepository(ref.watch(firestoreProvider), ref.watch(firebaseFunctionsProvider), uid);
});

/// Habits merged with their recent completion logs — streak and
/// isCompletedToday are already computed by the time the UI sees this.
final habitsProvider = StreamProvider<List<Habit>>((ref) {
  final repository = ref.watch(habitRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return combineLatest2(repository.watchHabits(), repository.watchRecentLogs())
      .map((pair) => mergeHabitsWithLogs(pair.$1, pair.$2));
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
