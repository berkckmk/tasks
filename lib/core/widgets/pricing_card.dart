import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../constants/app_spacing.dart';
import 'app_badge.dart';
import 'app_button.dart';

class PricingCard extends StatelessWidget {
  const PricingCard({
    super.key,
    required this.planName,
    required this.priceLabel,
    required this.features,
    this.isCurrent = false,
    this.isHighlighted = false,
    this.onSelect,
  });

  final String planName;
  final String priceLabel;
  final List<String> features;
  final bool isCurrent;
  final bool isHighlighted;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isHighlighted ? AppColors.deepGreen : AppColors.divider,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                planName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                ),
              ),
              if (isCurrent) const AppBadge(label: 'Current plan', color: AppColors.deepGreen),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            priceLabel,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.subtleText,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, size: 18, color: AppColors.deepGreen),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(fontSize: 13.5, color: AppColors.charcoal),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: isCurrent ? 'Current plan' : 'Choose $planName',
            variant: isHighlighted ? AppButtonVariant.primary : AppButtonVariant.secondary,
            expand: true,
            onPressed: isCurrent ? null : onSelect,
          ),
        ],
      ),
    );
  }
}
