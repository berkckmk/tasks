import 'plan_limits.dart';
import 'plan_module.dart';

class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.priceMonthly,
    required this.priceYearly,
    required this.features,
    required this.limits,
    required this.isPopular,
    required this.moduleAccess,
  });

  final String id;
  final String name;
  final double priceMonthly;
  final double priceYearly;
  final List<String> features;
  final PlanLimits limits;
  final bool isPopular;
  final Set<PlanModule> moduleAccess;

  bool hasModule(PlanModule module) => moduleAccess.contains(module);

  String get priceMonthlyLabel =>
      priceMonthly == 0 ? 'Free' : '\$${priceMonthly.toStringAsFixed(0)} / month';

  String get priceYearlyLabel =>
      priceYearly == 0 ? 'Free' : '\$${priceYearly.toStringAsFixed(0)} / year';
}
