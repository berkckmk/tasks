import 'goal.dart';
import 'milestone.dart';

abstract class GoalRepository {
  Stream<List<Goal>> watchGoals();

  /// `id == null` creates a new goal; otherwise updates the existing one.
  Future<void> saveGoal({
    required String? id,
    required String title,
    required String description,
    required GoalCategory category,
    required DateTime? targetDate,
    required GoalProgressType progressType,
    required double manualProgress,
    required List<Milestone> milestones,
  });

  Future<void> deleteGoal(String goalId);
}
