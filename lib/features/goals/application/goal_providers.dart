import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/firestore_goal_repository.dart';
import '../domain/goal.dart';
import '../domain/goal_repository.dart';
import '../domain/milestone.dart';

final goalRepositoryProvider = Provider<GoalRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return FirestoreGoalRepository(ref.watch(firestoreProvider), uid);
});

final goalsProvider = StreamProvider<List<Goal>>((ref) {
  final repository = ref.watch(goalRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchGoals();
});

class GoalActions {
  GoalActions(this._ref);

  final Ref _ref;

  Future<void> saveGoal({
    required String? id,
    required String title,
    required String description,
    required GoalCategory category,
    required DateTime? targetDate,
    required GoalProgressType progressType,
    required double manualProgress,
    required List<Milestone> milestones,
  }) async {
    final repository = _ref.read(goalRepositoryProvider);
    if (repository == null) return;
    await repository.saveGoal(
      id: id,
      title: title,
      description: description,
      category: category,
      targetDate: targetDate,
      progressType: progressType,
      manualProgress: manualProgress,
      milestones: milestones,
    );
    if (id == null) {
      await _ref.read(analyticsServiceProvider).logGoalCreated();
    }
  }

  Future<void> deleteGoal(String goalId) async {
    final repository = _ref.read(goalRepositoryProvider);
    if (repository == null) return;
    await repository.deleteGoal(goalId);
  }
}

final goalActionsProvider = Provider<GoalActions>((ref) => GoalActions(ref));
