/// `null` means unlimited.
class PlanLimits {
  const PlanLimits({this.maxActiveHabits, this.maxActiveTasks});

  final int? maxActiveHabits;
  final int? maxActiveTasks;
}
