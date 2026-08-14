import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/module_lock_view.dart';
import '../../../pricing/domain/plan_module.dart';
import '../../application/subscription_providers.dart';

/// Gates a whole screen behind a plan module: shows [builder]'s screen if
/// the current plan includes [module], otherwise a [ModuleLockView]
/// explaining what's missing.
///
/// Every gated screen (Goals, Finance, Workout, Learning, Content,
/// Analytics, Reports) had hand-rolled the identical
/// `if (!canAccess) return Scaffold(... ModuleLockView ...)` block instead of
/// using this — which is how the Goals gate ended up on GoalsScreen but not
/// on AddEditGoalScreen. Building the locked Scaffold here (rather than just
/// the body) is what lets a screen delegate the whole decision.
class RequiresModule extends ConsumerWidget {
  const RequiresModule({
    super.key,
    required this.title,
    required this.module,
    required this.featureName,
    required this.benefit,
    required this.requiredPlanName,
    required this.icon,
    required this.builder,
  });

  /// AppBar title, used for the locked state so the screen still looks like
  /// itself rather than like an error.
  final String title;
  final PlanModule module;
  final String featureName;
  final String benefit;
  final String requiredPlanName;
  final IconData icon;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enforcement = ref.watch(planEnforcementProvider);
    if (enforcement.canAccessModule(module)) return builder(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ModuleLockView(
        featureName: featureName,
        benefit: benefit,
        requiredPlanName: requiredPlanName,
        icon: icon,
      ),
    );
  }
}
