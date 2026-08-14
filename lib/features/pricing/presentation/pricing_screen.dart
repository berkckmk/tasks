import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/pricing_card.dart';
import '../../subscription/application/dev_billing_service.dart';
import '../../subscription/application/subscription_providers.dart';
import '../application/plan_providers.dart';

class PricingScreen extends ConsumerWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider);
    final subscriptionAsync = ref.watch(subscriptionStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade plan')),
      body: subscriptionAsync.when(
        data: (subscription) {
          final currentPlanId = subscription?.planId ?? 'starter';
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: plans.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final plan = plans[index];
              return PricingCard(
                planName: plan.name,
                priceLabel: plan.priceMonthlyLabel,
                features: plan.features,
                isCurrent: plan.id == currentPlanId,
                isHighlighted: plan.isPopular,
                onSelect: () async {
                  final result = await ref
                      .read(billingServiceProvider)
                      .purchasePlan(plan.id, yearly: false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result.message ?? 'Switched to the ${plan.name} plan')),
                    );
                  }
                },
              );
            },
          );
        },
        error: (error, stackTrace) => ErrorState(error: error),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
