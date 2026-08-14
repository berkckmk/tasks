import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/module_lock_view.dart';
import '../../../pricing/domain/plan_module.dart';
import '../../application/subscription_providers.dart';

/// Wrap a screen's body with this to gate it behind a plan module. Shows
/// [builder]'s content if the current plan includes [module], otherwise a
/// [ModuleLockView] explaining what's missing — used the same way for every
/// gated screen (Goals, Finance, Workout, Learning, Content, Analytics).
class RequiresModule extends ConsumerWidget {
  const RequiresModule({
    super.key,
    required this.module,
    required this.featureName,
    required this.benefit,
    required this.requiredPlanName,
    required this.builder,
  });

  final PlanModule module;
  final String featureName;
  final String benefit;
  final String requiredPlanName;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enforcement = ref.watch(planEnforcementProvider);
    if (enforcement.canAccessModule(module)) return builder(context);
    return ModuleLockView(
      featureName: featureName,
      benefit: benefit,
      requiredPlanName: requiredPlanName,
    );
  }
}
